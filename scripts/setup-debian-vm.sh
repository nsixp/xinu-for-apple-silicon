#!/bin/bash
# Set up this VM as a Xinu edit/build environment (the "VM-A" workflow).
# Run INSIDE a Debian VM, as a normal user with sudo.
#
# The ISO itself is NOT built here: arm64 Debian has no grub-pc-bin, so
# boot/mkiso.sh must run on the Mac. Copy compile/xinu.elf to the shared
# folder and let scripts/sync-iso.sh rebuild boot/xinu.iso there.
set -e

REPO=https://github.com/nsixp/xinu-for-apple-silicon.git
SHARE=/media/share

sudo apt update
sudo apt install -y build-essential gcc-i686-linux-gnu binutils-i686-linux-gnu \
  flex bison gawk git openssh-server
# qemu-user-* is optional; it only helps if you ever run host binaries here.
sudo apt install -y qemu-user-static 2>/dev/null || \
  sudo apt install -y qemu-user-binfmt 2>/dev/null || true

rm -rf "$HOME/xinu"
git clone "$REPO" "$HOME/xinu"

cd "$HOME/xinu/compile"
# .defs/.deps cache stale rules after files are added or removed; drop them.
rm -f .defs .deps xinu.elf xinu.map
make

echo "== BUILD OK: $HOME/xinu =="
echo
echo "Share the built kernel with the Mac, then rebuild the ISO there:"
echo "  mkdir -p $SHARE"
echo "  sudo mount -t 9p -o trans=virtio,version=9p2000.L share $SHARE   # if not mounted yet"
echo "  cp $HOME/xinu/compile/xinu.elf $SHARE/"
echo "Then on the Mac, run:  ./scripts/sync-iso.sh"
