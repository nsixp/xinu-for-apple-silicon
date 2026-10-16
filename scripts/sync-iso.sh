#!/bin/bash
# Watch for a fresh compile/xinu.elf dropped in the shared folder and rebuild
# boot/xinu.iso from it.
#
# This is the bridge for the two-VM workflow: the Debian VM compiles the
# kernel but cannot make the ISO (no grub-pc-bin on arm64), so it copies
# xinu.elf to the share and this script rebuilds the ISO on the Mac.
#
# macOS only (uses BSD `stat -f`). Usage:
#   ./scripts/sync-iso.sh
# Stop with Ctrl-C.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# Where the VM drops the kernel. Default: the shared folder that lives next
# to this checkout. Override with XINU_DROP=/path/to/share.
DROP=${XINU_DROP:-$(dirname "$ROOT")}
ELF="$DROP/xinu.elf"
LOG=${XINU_LOG:-$ROOT/sync.log}

built=""
stable=""
echo "$(date '+%F %T') watching for $ELF (pid $$)" >>"$LOG"

while true; do
	sleep 3
	[ -f "$ELF" ] || continue
	sig=$(stat -f '%m:%z' "$ELF")
	# Rebuild only once the file has stopped growing (a copy in progress).
	if [ "$sig" = "$stable" ] && [ "$sig" != "$built" ]; then
		if cp "$ELF" "$ROOT/compile/xinu.elf" &&
			(cd "$ROOT" && ./boot/mkiso.sh) >>"$LOG" 2>&1; then
			built="$sig"
			echo "$(date '+%F %T') ISO rebuilt (elf sig $sig)" >>"$LOG"
		else
			echo "$(date '+%F %T') FAILED to rebuild ISO (elf sig $sig)" >>"$LOG"
		fi
	fi
	stable="$sig"
done
