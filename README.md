# webdav-tunnel

Access your home storage (a USB drive, a NAS folder, any directory) from
**anywhere on the internet** — securely over HTTPS — without a public IP, without
port-forwarding, and without paying for anything.

It works behind CGNAT and typical home routers because the device **dials out**
to a small cloud relay instead of accepting inbound connections.

```
                             ┌─────────────────────────────┐
  Your phone / laptop        │   Free cloud VM (public IP)  │
  on 5G or any network       │                             │
        │  HTTPS (443)        │   Caddy ──► frps (relay)    │
        └────────────────────►   auto TLS      ▲           │
                             └──────────────────┼───────────┘
                                                │ outbound tunnel (frp)
                                 ┌──────────────┴───────────────┐
                                 │  Your device at home          │
                                 │  (Pi / NAS / server / router) │
                                 │   frpc ──► webdavd ──► /storage│
                                 └───────────────────────────────┘
```

**Components**

- **`webdavd`** — a ~single-file Go WebDAV server (in this repo) that serves one
  directory with HTTP Basic Auth. Cross-compiles to x86, ARM, MIPS, etc.
- **[frp](https://github.com/fatedier/frp)** — `frpc` on your device opens an
  outbound tunnel to `frps` on the cloud VM, exposing the local WebDAV port.
- **[Caddy](https://caddyserver.com/)** — on the VM, terminates HTTPS with an
  auto-renewing Let's Encrypt certificate.
- A **free cloud VM** — e.g. Oracle Cloud Always Free, Google Cloud `e2-micro`,
  AWS free tier, or any cheap VPS.

> ### ⚠️ Scope / ethics
> This is for storage on **hardware you own and administer** — a Raspberry Pi,
> a NAS, a home server, or a router you have legitimate admin access to. Every
> step below uses normal, authenticated admin access (SSH / the device's admin
> UI). **Do not** use this to gain access to devices you don't control, and
> change any default passwords on your gear before exposing anything.

---

## What you need

- A device at home that stays on and holds the storage, which you can reach over
  **SSH** (or whose admin UI lets you run a startup command).
- A free cloud VM with a public IP.
- [Go](https://go.dev/dl/) on your workstation to build `webdavd` (or grab a
  release binary you've built).

---

## Part A — Build `webdavd`

```bash
git clone https://github.com/SyedAbdullahHashmi/webdav-tunnel
cd webdav-tunnel

# pick the target that matches your device:
./scripts/build-webdavd.sh linux arm64            # Raspberry Pi 3/4/5, ARM NAS
./scripts/build-webdavd.sh linux amd64            # x86-64 box
./scripts/build-webdavd.sh linux mips softfloat   # big-endian MIPS router
```

> **Old-kernel gotcha:** if your device runs a very old Linux kernel (common on
> cheap routers, roughly < 4.6), build with **Go 1.23.x**. Go 1.24+ uses a futex
> operation some old kernels don't implement, and the binary will crash on
> start. Modern devices (Pi/NAS/VPS) are unaffected.

Copy the binary to the device, e.g. `/opt/webdav-tunnel/webdavd`.

Quick local test on the device:

```bash
/opt/webdav-tunnel/webdavd -addr 0.0.0.0:8080 -root /srv/storage -user alice -pass 's3cret'
# from another machine on the LAN: open http://<device-ip>:8080 in a WebDAV client
```

---

## Part B — Create the free cloud VM

Any provider works. Oracle Cloud **Always Free** is a good pick (generous ARM
shape). After creating the instance:

1. Give it a **public IP** (ephemeral is fine).
2. Open inbound ports in the provider's firewall / security group:
   - **7000/tcp** — frp control channel
   - **80/tcp** and **443/tcp** — HTTPS (Caddy + Let's Encrypt validation)
   - *(8080/tcp only if you also want plain-HTTP access; not needed once HTTPS works)*
3. Most Linux images also have a host firewall — open the same ports, e.g. on
   RHEL/Oracle Linux:
   ```bash
   sudo firewall-cmd --permanent --add-port=7000/tcp
   sudo firewall-cmd --permanent --add-port=80/tcp
   sudo firewall-cmd --permanent --add-port=443/tcp
   sudo firewall-cmd --reload
   ```

> **SELinux note (RHEL/Oracle/Fedora):** if you place a binary under
> `/usr/local/bin` by moving it from `/tmp`, systemd may refuse to run it
> (`203/EXEC Permission denied`). Fix the label:
> `sudo restorecon -v /usr/local/bin/caddy`.

---

## Part C — The frp tunnel

Download frp for each side from the
[frp releases](https://github.com/fatedier/frp/releases) (server arch for the VM,
device arch for the device).

**On the VM:**

```bash
sudo mkdir -p /opt/frp
# copy the frps binary to /opt/frp/frps
cp frp/frps.toml.example /opt/frp/frps.toml   # then edit: set a strong token
sudo cp vm/frps.service /etc/systemd/system/frps.service
sudo systemctl daemon-reload
sudo systemctl enable --now frps
```

**On the device:**

```bash
cp frp/frpc.toml.example /opt/webdav-tunnel/frpc.toml
# edit: set serverAddr = your VM IP, and the SAME token as frps
```

Generate the shared token once with `openssl rand -hex 16` and put it in both
files.

---

## Part D — HTTPS with Caddy (on the VM)

```bash
curl -sL -o caddy "https://caddyserver.com/api/download?os=linux&arch=amd64"
chmod +x caddy && sudo mv caddy /usr/local/bin/caddy
sudo restorecon -v /usr/local/bin/caddy 2>/dev/null || true   # SELinux distros

sudo mkdir -p /etc/caddy
cp vm/Caddyfile.example /etc/caddy/Caddyfile   # then edit: put your VM IP in the hostname
sudo cp vm/caddy.service /etc/systemd/system/caddy.service
sudo systemctl daemon-reload
sudo systemctl enable --now caddy
```

**No domain?** The example Caddyfile uses [`sslip.io`](https://sslip.io):
`<your-ip>.sslip.io` resolves to your IP with zero DNS setup, so Let's Encrypt
can issue a real, browser-trusted cert for a bare-IP VM. If you own a domain,
point an A record at the VM and use it instead.

Watch the cert get issued:

```bash
sudo journalctl -u caddy -f    # look for "certificate obtained successfully"
```

---

## Part E — Start the services on the device (and survive reboots)

Start `webdavd` and `frpc` on the device. Pick whichever your device supports:

**systemd (Pi / NAS / most Linux):** — survives reboots automatically.

```bash
sudo cp device/webdavd.service /etc/systemd/system/
sudo cp device/frpc.service    /etc/systemd/system/
# edit both files: paths, storage dir, and WebDAV credentials
sudo systemctl daemon-reload
sudo systemctl enable --now webdavd frpc
```

**cron (no systemd):**

```cron
@reboot /opt/webdav-tunnel/webdavd -addr 0.0.0.0:8080 -root /srv/storage -user alice -pass 's3cret' >/var/log/webdavd.log 2>&1 &
@reboot /opt/webdav-tunnel/frpc -c /opt/webdav-tunnel/frpc.toml >/var/log/frpc.log 2>&1 &
```

**Manual one-shot restore:** if a device really can't persist startup, use
[`scripts/restore.sh`](scripts/restore.sh): copy `restore.env.example` to
`restore.env`, fill it in, and run `./scripts/restore.sh` from your laptop to
SSH in and start both services.

---

## Using it

- **At home (fast):** point a WebDAV client straight at the device on your LAN —
  `http://<device-ip>:8080`. No internet round-trip.
- **Away (anywhere):** `https://<your-ip>.sslip.io` with your WebDAV username and
  password.

WebDAV clients: **Cyberduck** / **Transmit** (macOS), **rclone** (CLI, any OS),
**RaiDrive** (Windows), **Mountain Duck** (mount as a drive). macOS Finder's
built-in WebDAV works too but is read-only for some servers — a dedicated client
is more reliable for read-write.

---

## Security notes

- **Change every default credential** on your device and VM before exposing it.
- Use a **strong, random** frp token and WebDAV password.
- Keep inbound ports minimal (7000/80/443). Close 8080 on the VM once HTTPS works.
- `webdavd` auth is HTTP Basic — only ever expose it to the public **through
  HTTPS** (Caddy), never as plain HTTP over the internet, or the password and
  files travel in the clear.
- Consider IP-allowlisting or a VPN if you want a smaller attack surface.

## License

MIT — see [LICENSE](LICENSE).
