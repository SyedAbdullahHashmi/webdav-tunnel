#!/usr/bin/env bash
# Cross-compile webdavd for your target device.
#
# IMPORTANT: build with Go 1.23.x if your target runs an OLD Linux kernel
# (roughly < 4.6). Go 1.24+ uses a futex operation that some old kernels
# (common on cheap MIPS/ARM routers) do not implement, which makes the
# binary crash on start. On a Pi/NAS/VPS with a modern kernel, any recent Go
# is fine.
#
# Usage:
#   ./build-webdavd.sh linux amd64            # x86-64 VPS / PC
#   ./build-webdavd.sh linux arm64            # Raspberry Pi 3/4/5, ARM NAS
#   ./build-webdavd.sh linux arm 7            # 32-bit ARM (Pi 2, older)
#   ./build-webdavd.sh linux mips softfloat   # big-endian MIPS router
#   ./build-webdavd.sh linux mipsle softfloat # little-endian MIPS router
set -euo pipefail
cd "$(dirname "$0")/../webdavd"

OS="${1:-linux}"
ARCH="${2:-amd64}"
EXTRA="${3:-}"

export GOOS="$OS" GOARCH="$ARCH" CGO_ENABLED=0
case "$ARCH" in
  arm)  export GOARM="${EXTRA:-7}" ;;
  mips|mipsle) export GOMIPS="${EXTRA:-softfloat}" ;;
esac

OUT="webdavd-${OS}-${ARCH}${EXTRA:+-$EXTRA}"
echo "Building $OUT (GOOS=$GOOS GOARCH=$GOARCH ${GOARM:+GOARM=$GOARM}${GOMIPS:+GOMIPS=$GOMIPS})"
go build -trimpath -ldflags "-s -w" -o "$OUT" .
ls -lh "$OUT"
file "$OUT" 2>/dev/null || true
echo "Done. Copy $OUT to your device and run it (see README)."
