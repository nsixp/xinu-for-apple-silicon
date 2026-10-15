# Xinu for Apple Silicon (UTM / QEMU)

A bootable build of the **Xinu** teaching operating system that runs on an
Apple Silicon Mac under [UTM](https://getutm.app) (QEMU). The upstream
VirtualBox-targeted sources were made to boot and get a working network on
QEMU's `e1000` device, so you can boot straight to the Xinu shell
(`xsh $`) and `ping` the host — no VirtualBox, no x86 hardware.

> Xinu is the small operating system from
> *Operating System Design — The Xinu Approach* by Douglas E. Comer
> (CRC Press). It is a 32-bit x86 kernel, built here as a multiboot image
> and wrapped in a GRUB ISO so any PC-emulator can boot it.

---

## What's in this repo

- A **bootable ISO** — [`boot/xinu.iso`](boot/xinu.iso) — prebuilt, so you can
  run Xinu immediately without installing a compiler.
- The **full source tree** (`boot/ compile/ config/ device/ include/ lib/ net/
  shell/ system/`), which builds a fresh ISO from scratch.
- `boot/mkiso.sh` — packs `compile/xinu.elf` into the GRUB ISO.

### What was changed from upstream

The stock Xinu VirtualBox sources assume a fixed PCI layout that VirtualBox
happens to provide. QEMU (which UTM uses on Apple Silicon) lays out the Intel
**82545EM** NIC differently, so the driver never found the card. The Ethernet
driver in [`device/eth/`](device/eth/) was fixed to work on both:

| File | Fix |
|------|-----|
| `82545EMInit.c` | **Scan all PCI BARs** for the I/O-space base instead of assuming a fixed offset (QEMU uses BAR0 for MMIO, BAR1 for I/O). |
| `82545EMInit.c` | **Probe the PHY address.** Real 82545EM silicon answers on MDI address 1; QEMU's model answers only on 0. Init now tries both. |
| `82545EMInit.c` | **Set the PCI command register** (memory + I/O + bus-master) before touching the device. |
| `ethcontrol.c` | **Read back the interrupt mask** after writing it, so the posted MMIO write lands before the NIC evaluates `IMS` (otherwise QEMU keeps it cleared and never raises INTx). |
| `ethhandler.c`, `ethwrite.c`, `e1000e.h` | Matching interrupt-acknowledge and transmit-descriptor handling, plus the new `E1000_PCI_CMD_MASK` and IMS definitions. |

Two build fixes make the tree compile on a stock macOS toolchain:

- `config/config.l` uses `%option noyywrap` (drops the `libfl` dependency that
  macOS doesn't ship) and `config/Makefile` normalizes flex's `yyleng` type.
- `compile/Makefile` creates the gitignored `version` file automatically on a
  fresh clone.

Everything else is the unmodified Xinu source tree.

---

## Quick start — boot the prebuilt ISO

No compiler required. You only need UTM.

1. **Install UTM**

   ```sh
   brew install --cask utm
   ```

   Or download `UTM.dmg` from the
   [latest UTM release](https://github.com/utmapp/UTM/releases/latest)
   (see the [macOS install docs](https://docs.getutm.app/installation/macos/)).

2. **Create the VM.** UTM → **+** → **Virtualize** → **Emulate** → **Other**
   (not Linux, not Windows). Then configure in the VM's settings:

   | Setting | Value |
   |---------|-------|
   | Architecture | `x86_64` |
   | Boot | (none — we attach the ISO below) |
   | Memory | `512 MB` is plenty |
   | Drive | empty (Xinu has no filesystem to install to) |
   | Network | `e1000-82545em` (**must** be this device model) |
   | UEFI | **off** (plain BIOS boot via GRUB) |

3. **Attach the ISO.** Drive → change to CD/DVD → choose this repo's
   `boot/xinu.iso`.

4. **Boot.** Start the VM. GRUB loads and Xinu starts, dropping you at:

   ```
   xsh $
   ```

5. **Check the network.** In the `xsh $` prompt:

   ```
   xsh $ ping 10.0.2.2
   ```

   `10.0.2.2` is the QEMU host gateway. You should see `host is alive`.

> **Terminal tip:** the Xenia console is the serial port. In UTM the VM window
> itself is the console, so you can type at `xsh $` directly.

---

## Build from source

Requires the Xcode command-line tools (for `clang`/`flex`/`bison`) plus a few
Homebrew packages. Tested on macOS 15 (Sequoia) on Apple Silicon.

1. **Toolchain**

   ```sh
   xcode-select --install            # clang, flex, bison
   brew install gawk \
                i686-elf-gcc i686-elf-binutils i686-elf-grub \
                xorriso mtools
   ```

   `i686-elf-gcc`/`i686-elf-binutils` provide the cross-compiler;
   `i686-elf-grub` + `xorriso` + `mtools` make the bootable ISO; `gawk` is
   used by the build scripts.

2. **Compile the kernel**

   ```sh
   git clone https://github.com/nsixp/xinu-for-mac-arm.git
   cd xinu-for-mac-arm/compile
   make CROSS=i686-elf-
   ```

   This produces `compile/xinu.elf` (a 32-bit i386 multiboot ELF).

3. **Build the ISO**

   ```sh
   cd ..
   ./boot/mkiso.sh
   ```

   This packs `compile/xinu.elf` + `boot/grub/grub.cfg` into `boot/xinu.iso`
   with `grub-mkrescue`.

4. **Boot** it in UTM exactly as in Quick start (attach the new `boot/xinu.iso`).

> **Rebuilds:** if you get `undefined reference to ...` after adding or
> removing source files, run `make clean && make` in `compile/`. The build
> caches a dependency list, so stale entries can linger otherwise.

---

## Adding your own shell command

Xinu's shell is table-driven. To add a command named `mycmd`:

1. Write `shell/xsh_mycmd.c` implementing
   `shellcmd xsh_mycmd(int nargs, char *args[])` (copy `shell/xsh_help.c` as a
   template).
2. Declare it in [`include/shprototypes.h`](include/shprototypes.h):
   `extern shellcmd xsh_mycmd(int32, char *[]);`
3. Add an entry to the `cmdtab[]` table in
   [`shell/shell.c`](shell/shell.c): `{"mycmd", xsh_mycmd},`
4. Rebuild (`make clean && make CROSS=i686-elf-` in `compile/`), re-run
   `./boot/mkiso.sh`, reboot the VM. `help` will now list `mycmd`.

New `.c` files under `shell/` are picked up automatically by the build.

---

## Project layout

```
xinu-for-mac-arm/
├── boot/
│   ├── grub/grub.cfg      GRUB menu (boots the multiboot kernel)
│   ├── mkiso.sh           build boot/xinu.iso from compile/xinu.elf
│   └── xinu.iso           prebuilt bootable ISO
├── compile/               build rules + linker script (ld.script)
├── config/                device-table generator (Configuration → conf.c/conf.h)
├── device/                device drivers (tty, eth/e1000, pipe, ...)
├── include/               headers
├── lib/                   library routines
├── net/                   networking stack (ARP, UDP, DHCP, ...)
├── shell/                 the xsh shell and its commands
└── system/                core kernel (init, process, memory, clock, ...)
```

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| VM boots to GRUB but hangs | The network card isn't `e1000-82545em`. Fix it in the VM's network settings. |
| `xsh $` works but `ping` says host unreachable | Same as above — the driver only supports the 82545EM. |
| `ld: library 'fl' not found` while building | You're on an older checkout. `config.l` now uses `%option noyywrap`; pull the latest. |
| `undefined reference to ...` at link | Stale dependency cache — `make clean && make CROSS=i686-elf-`. |
| `make: i686-elf-gcc: No such file or directory` | Homebrew isn't on your PATH for that shell, or you forgot `brew install i686-elf-gcc`. |
| `gawk: command not found` | `brew install gawk`. |

---

## Credits & license

Xinu is by **Douglas E. Comer**; the sources are distributed under the terms in
[`COPYRIGHT`](COPYRIGHT) (portions © 2012, 2015 Douglas E. Comer and CRC Press).
Please read it before redistributing — notably, the software may not be
published in a textbook without permission from the copyright holders.

The QEMU/UTM network-driver and macOS build fixes in this repository are offered
under the same terms.
