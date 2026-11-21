# Finish the setup with an AI assistant

The README covers the general path, but a few steps depend on *your* specific
hardware, OS, and cloud provider — the exact cross-compile target, how services
auto-start on your device, which firewall/security-group to open, and whatever
breaks along the way. An AI coding assistant (Claude Code, or similar) is good at
filling those gaps **for a device you own and administer**.

Copy the prompt below, fill in the `<...>` blanks, and paste it into your
assistant. Run it from a machine that can reach your device over SSH (or from the
device itself).

> **Scope:** this is for hardware you own and have legitimate admin access to.
> If your device has no SSH/admin access yet, enable it through the vendor's
> supported settings first — don't ask an assistant to bypass authentication,
> use default/guessed credentials, or exploit a device to get in.

---

## The prompt

```
I'm setting up the "webdav-tunnel" project
(https://github.com/SyedAbdullahHashmi/webdav-tunnel) to reach my own home
storage from the internet over HTTPS. Help me adapt its generic steps to my
specific setup. This is all hardware I own and administer.

MY DEVICE (holds the storage):
- Model / board: <e.g. Raspberry Pi 4, Synology DS220+, mini-PC, OpenWrt router>
- OS + version:  <e.g. Raspberry Pi OS 12, DSM 7.2, Debian 12, OpenWrt 23.05>
- CPU arch:      <e.g. arm64 / amd64 / armv7 / mipsel — run `uname -m` if unsure>
- Kernel:        <run `uname -r`>  (matters: old kernels need Go 1.23 to build webdavd)
- Admin access I have: <SSH as a user with sudo / web admin UI / console>
- Init system:   <systemd / OpenWrt procd / busybox init / cron only>
- Storage path to serve: <e.g. /srv/storage, /volume1/share, /mnt/usb>

MY CLOUD VM:
- Provider:      <Oracle Always Free / GCP e2-micro / a VPS / ...>
- OS:            <Oracle Linux 9 / Ubuntu 22.04 / ...>
- Public IP:     <or "help me assign one">
- Domain:        <none — use sslip.io / or my domain: example.com>

Please help me, step by step, and wait for me to confirm each step works:
1. Cross-compile `webdavd` for my device's arch (and tell me if my kernel needs
   Go 1.23 instead of the latest Go).
2. Install and run webdavd + frpc on my device, and make them auto-start on boot
   using whatever my init system supports (systemd unit, procd, cron @reboot).
3. Set up frps + Caddy on my VM, including the exact firewall/security-group
   rules for my provider, and the SELinux fix if my VM uses it.
4. Verify HTTPS end to end and help me debug any failures (cert issuance,
   tunnel not connecting, etc.).
5. Suggest how to lock it down (strong token + WebDAV password, minimal open
   ports, optional IP allowlist).

Ask me for any `uname`/log output you need instead of guessing.
```

---

## If your device genuinely can't persist a boot-time startup

Some devices wipe their filesystem or reset services on every reboot. If yours
does **and you still administer it**, the project ships
[`scripts/restore.sh`](scripts/restore.sh): a one-command, SSH-based way to
restart the services after a reboot. Add this to your prompt:

```
My device does not keep my services running across reboots. Help me use
scripts/restore.sh (or a small wrapper I can double-click) to restart webdavd
and frpc over SSH after it reboots. I log into this device normally over SSH.
```

The assistant should only ever use your own SSH login for this — if it proposes
default credentials or any way around the device's authentication, stop: that's
out of scope for this project.
