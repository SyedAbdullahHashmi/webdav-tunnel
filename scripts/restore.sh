#!/usr/bin/env bash
# restore.sh — manually (re)start the storage services on your device.
#
# Use this ONLY if your device can't persist an auto-start across reboots
# (if it can, prefer the systemd units in ../device/ or a cron @reboot entry —
# then you never need this). It connects to the device over SSH and starts
# webdavd + frpc if they aren't already running.
#
# Configure via environment variables or a config file next to this script
# named "restore.env" (see restore.env.example). NO secrets are stored in
# this script.
#
#   DEVICE_SSH   user@host of the device you administer (e.g. pi@192.168.1.50)
#   REMOTE_DIR   where the binaries + frpc.toml live on the device
#   WEBDAV_ROOT  directory to serve
#   WEBDAV_USER  / WEBDAV_PASS   WebDAV credentials
#
# This talks to a device over SSH — i.e. hardware you own and have logged into
# normally. It does not bypass authentication on anything.
set -euo pipefail
cd "$(dirname "$0")"
[ -f restore.env ] && . ./restore.env

: "${DEVICE_SSH:?set DEVICE_SSH, e.g. pi@192.168.1.50}"
: "${REMOTE_DIR:=/opt/webdav-tunnel}"
: "${WEBDAV_ROOT:=/srv/storage}"
: "${WEBDAV_USER:?set WEBDAV_USER}"
: "${WEBDAV_PASS:?set WEBDAV_PASS}"

echo "[*] Connecting to $DEVICE_SSH ..."
ssh "$DEVICE_SSH" REMOTE_DIR="$REMOTE_DIR" WEBDAV_ROOT="$WEBDAV_ROOT" \
    WEBDAV_USER="$WEBDAV_USER" WEBDAV_PASS="$WEBDAV_PASS" 'sh -s' <<'REMOTE'
set -e
if ! pidof webdavd >/dev/null 2>&1; then
  "$REMOTE_DIR/webdavd" -addr 0.0.0.0:8080 -root "$WEBDAV_ROOT" \
    -user "$WEBDAV_USER" -pass "$WEBDAV_PASS" > "$REMOTE_DIR/webdavd.log" 2>&1 &
  echo "  started webdavd"
else
  echo "  webdavd already running"
fi
if ! pidof frpc >/dev/null 2>&1; then
  "$REMOTE_DIR/frpc" -c "$REMOTE_DIR/frpc.toml" > "$REMOTE_DIR/frpc.log" 2>&1 &
  echo "  started frpc"
else
  echo "  frpc already running"
fi
sleep 2
echo "  webdavd pid: $(pidof webdavd || echo none)   frpc pid: $(pidof frpc || echo none)"
REMOTE
echo "[*] Done."
