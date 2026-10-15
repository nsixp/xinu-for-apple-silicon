#!/bin/sh
# Build a BIOS-bootable GRUB ISO containing the Xinu kernel.
# Usage: boot/mkiso.sh   (after 'make' in compile/)
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ISO="$ROOT/boot/xinu.iso"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/boot/grub"
cp "$ROOT/compile/xinu.elf" "$STAGE/boot/xinu.elf"
cp "$ROOT/boot/grub/grub.cfg" "$STAGE/boot/grub/grub.cfg"

# grub-mkrescue on Linux; i686-elf-grub-mkrescue from Homebrew on macOS.
if command -v grub-mkrescue >/dev/null 2>&1; then
    GRUB_MKRESCUE=grub-mkrescue
else
    GRUB_MKRESCUE=i686-elf-grub-mkrescue
fi

"$GRUB_MKRESCUE" -o "$ISO" "$STAGE"

echo "Built $ISO"
