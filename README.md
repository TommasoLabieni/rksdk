# Rockchip Linux SDK

Simplified build system for Rockchip arm64 SoCs. Produces a bootable image
from open-source components: Rockchip Linux 6.1 kernel, U-Boot v2017.09, and
a Yocto 5.0 (Scarthgap) root filesystem, with optional AMP co-processing via
HAL + RT-Thread.

**Supported chips:** rk3399 · rk3562 · rk3566 · rk3568 · rk3576 · rk3588 / rk3588s

---

## Prerequisites

**Host packages** (Ubuntu/Debian):

```bash
sudo apt install repo git make gcc g++ bison flex libncurses-dev \
    python3 python3-pip scons libssl-dev bc lz4 cpio rsync \
    device-tree-compiler u-boot-tools
```

**Toolchain** (cross-compiler for aarch64):

Download the Arm GNU Toolchain from
`developer.arm.com/downloads/-/arm-gnu-toolchain-downloads` and unpack it to:

```
prebuilts/gcc/linux-x86/aarch64/
```

The build system searches that directory for a GCC binary matching
`aarch64-*-linux-*-gcc`. Any recent AArch64 bare-metal or Linux toolchain works.

---

## Getting started

```bash
mkdir rksdk && cd rksdk
repo init -u https://github.com/TommasoLabieni/rksdk -b master -m manifests/default.xml
repo sync -j8
```

`repo sync` fetches the kernel, U-Boot, rkbin blobs, Yocto layers, RT-Thread,
HAL, and tools into their respective subdirectories. The SDK build system
itself (this repo) is checked out to the workspace root at `path="."`.

---

## Workflow at a glance

```
1. Select chip family     ./build.sh chip
2. Select defconfig       ./build.sh defconfig
3. (Optional) Tune        make menuconfig  →  make savedefconfig
4. Build                  ./build.sh all
5. Flash                  ./rkflash.sh
```

Each step is described in detail below.

---

## Directory layout

```
rksdk/
├── build.sh                → device/rockchip/common/scripts/build.sh
├── Makefile                → device/rockchip/common/Makefile
├── manifests/default.xml   # repo manifest
├── kernel  → kernel-6.1/  # populated by repo sync
├── kernel-6.1/             # Rockchip Linux 6.1
├── u-boot/                 # Rockchip U-Boot v2017.09
├── rkbin/                  # Proprietary blobs: BL31 ATF, DDR init, miniloader
├── prebuilts/              # Cross-compilation toolchains (manual download)
├── yocto/                  # poky + meta-openembedded + meta-rockchip
├── rtos/                   # RT-Thread (for AMP)
├── hal/                    # Rockchip HAL bare-metal library (for AMP)
├── uefi/                   # Rockchip EDK2 UEFI
├── tools/                  # Host tools: upgrade_tool, etc.
├── device/rockchip/
│   ├── common/
│   │   ├── build-hooks/    # Ordered hook scripts (00-config … 99-all)
│   │   ├── configs/        # KConfig: Config.in and Config.in.*
│   │   ├── kconfig/        # KConfig tooling (mconf, conf, …)
│   │   └── scripts/        # mk-*.sh, check-*.sh, helpers
│   ├── .chips/             # Symlinks: chip-family → chip configs dir
│   ├── .chip               # Symlink to currently selected chip (runtime)
│   ├── rk3399/configs/
│   ├── rk3562/configs/
│   ├── rk3566_rk3568/configs/
│   ├── rk3576/configs/
│   └── rk3588/configs/
├── output/                 # All build artifacts (generated)
│   └── firmware/           # Final images ready to flash
└── rockdev  → output/firmware/
```

---

## Step 1 — Select chip and defconfig

### Interactive selection

```bash
./build.sh chip        # prompts: pick a chip family
./build.sh defconfig   # prompts: pick a defconfig for that chip
```

### Direct selection (combined)

```bash
./build.sh rk3588:rockchip_defconfig
./build.sh rk3568:rockchip_rk3568_evb_amp_defconfig
```

This sets `device/rockchip/.chip` (a symlink to the selected chip's `configs/`
dir) and writes `output/.config` from the chosen defconfig.

Available defconfigs per chip:

| Chip family | Defconfigs |
|---|---|
| rk3399 | `rockchip_defconfig` |
| rk3562 | `rockchip_defconfig` |
| rk3566_rk3568 | `rockchip_defconfig`, `rockchip_rk3568_evb_amp_defconfig` |
| rk3576 | `rockchip_defconfig` |
| rk3588 | `rockchip_defconfig`, `rockchip_rk3588_evb1_amp_defconfig` |

---

## Step 2 — Tune the configuration (optional)

```bash
make menuconfig       # curses TUI — browse and change any option
make savedefconfig    # write minimal defconfig back to the chip's configs/ dir
```

`savedefconfig` only writes the values that differ from the defaults, so the
stored defconfig stays small. It overwrites the file that was loaded in step 1.

Targeted config shortcuts:

```bash
./build.sh menuconfig          # same as make menuconfig
./build.sh config              # menuconfig + savedefconfig in one step
./build.sh config-rootfs-type  # jump straight to rootfs type setting
./build.sh config-extra-parts  # jump straight to extra partition settings
```

Key options to know:

| KConfig symbol | What it controls |
|---|---|
| `RK_UBOOT_CFG` | U-Boot defconfig name (e.g. `rk3588`) |
| `RK_KERNEL_CFG` | Kernel defconfig (e.g. `rockchip_linux_defconfig`) |
| `RK_KERNEL_DTS_NAME` | DTS file name without `.dts` extension |
| `RK_YOCTO_MACHINE` | Yocto `MACHINE` variable |
| `RK_PARAMETER` | Partition table file under `device/rockchip/<chip>/configs/` |
| `RK_AMP` | Enable AMP co-processing |
| `RK_USE_FIT_IMG` | Pack boot image as FIT (Flattened Image Tree) |

---

## Step 3 — Build

### Full build

```bash
./build.sh all
```

Runs all hooks in order: loader → kernel → rootfs → amp (if enabled) →
firmware. Final images land in `output/firmware/` (also `rockdev/`).

### Individual targets

```bash
./build.sh loader     # U-Boot + trust image only
./build.sh kernel     # kernel + DTB only
./build.sh rootfs     # Yocto rootfs only
./build.sh amp        # AMP images only (requires RK_AMP=y)
./build.sh firmware   # re-pack firmware from existing build artifacts
```

These can be combined: `./build.sh kernel firmware` rebuilds the kernel then
re-packs without rebuilding the rootfs.

### Cleaning

```bash
./build.sh cleanall        # remove all of output/ and rockdev/
./build.sh clean-kernel    # clean kernel build only
./build.sh clean-loader    # clean U-Boot build only
./build.sh clean-rootfs    # clean rootfs build only
```

### Build shell

```bash
./build.sh shell
```

Drops into a bash shell with all SDK environment variables (`RK_*`) exported.
Useful for running individual build commands manually.

### Verbose mode

```bash
make V=1 kernel    # pass V=1 to see full compiler invocations
```

---

## Step 4 — Flash

```bash
./rkflash.sh
```

Flashes over USB using Rockchip's MaskROM or loader protocol. The board must
be in MaskROM mode (hold RECOVERY button while powering on, or short the
MaskROM pads).

Images in `output/firmware/`:

| File | Content |
|---|---|
| `MiniLoaderAll.bin` | SPL / miniloader |
| `uboot.img` | U-Boot proper |
| `trust.img` | BL31 ATF trust image |
| `boot.img` | FIT image: kernel + DTB + (optional) ramdisk |
| `rootfs.img` | Yocto ext4 root filesystem |
| `update.img` | Single-file RKDevTool flash package (if `RK_UPDATE=y`) |

---

## Supporting a new board

All per-board settings live in a defconfig file. The process:

### 1. Copy the nearest defconfig

```bash
# Example: new board based on RK3588
cp device/rockchip/rk3588/configs/rockchip_defconfig \
   device/rockchip/rk3588/configs/rockchip_rk3588_myboard_defconfig
```

### 2. Set the DTS name

Edit the new defconfig and change `RK_KERNEL_DTS_NAME` to the DTS file
(without the `.dts` extension) that matches your board's hardware:

```
RK_KERNEL_DTS_NAME="rk3588-myboard"
```

The corresponding file must exist in the kernel tree at
`arch/arm64/boot/dts/rockchip/rk3588-myboard.dts`.
If your board does not have a DTS yet, start from the nearest EVB DTS and
adjust pinmux, regulators, and peripheral nodes.

### 3. Set the Yocto machine (if needed)

If your board needs a different Yocto `MACHINE` (BSP layer features, kernel
recipe overrides):

```
RK_YOCTO_MACHINE="rockchip-rk3588-myboard"
```

### 4. Adjust the partition layout (if needed)

`RK_PARAMETER` points to a `parameter.txt` file under your chip's `configs/`
dir. Copy and edit the existing one if your flash size or layout differs:

```bash
cp device/rockchip/rk3588/configs/parameter.txt \
   device/rockchip/rk3588/configs/parameter-myboard.txt
# edit CMDLINE partition sizes, then in the defconfig:
# RK_PARAMETER="parameter-myboard.txt"
```

The `CMDLINE` line in `parameter.txt` uses the format:
`<size>@<start>(<name>)` with all values in 512-byte sectors (hexadecimal).
The last partition gets a `-` size meaning "fill remaining space".

### 5. Load and build

```bash
./build.sh rk3588:rockchip_rk3588_myboard_defconfig
make menuconfig        # review / adjust
make savedefconfig
./build.sh all
```

---

## AMP (Asymmetric Multi-Processing)

AMP runs RT-Thread (and/or bare-metal HAL code) on reserved CPU cores
alongside the Linux kernel. Supported on **rk3566**, **rk3568**, and **rk3588**.

### Enabling AMP

Use an `*_amp_defconfig`, or start from a regular defconfig and set:

```
RK_AMP=y
RK_AMP_FIT_ITS="amp_linux.its"
RK_UBOOT_CFG_FRAGMENTS="rk-amp"
```

`RK_AMP_FIT_ITS` points to an ITS file under the chip's `configs/` dir that
defines which cores run AMP, their load addresses, and whether to use HAL or
RT-Thread per core.

### Building

```bash
./build.sh rk3588:rockchip_rk3588_evb1_amp_defconfig
./build.sh all    # builds amp.img in addition to the regular images
```

Or build AMP images alone after the rest is already built:

```bash
./build.sh amp
./build.sh firmware   # re-pack to include the new amp.img
```

### AMP output

`output/firmware/amp.img` — packed by `mkimage -f <its> -E`.

---

## Logs

Every build session creates a timestamped directory under `output/sessions/`:

```
output/sessions/2024-01-15_10-30-00/
├── initial.env      # environment at the start of the session
├── final.env        # all RK_* variables after config was loaded
├── loader.log
├── kernel.log
├── rootfs.log
└── firmware.log
```

`output/sessions/latest/` is a symlink to the most recent session.

---

## Updating sources

```bash
repo sync -j8                              # pull latest on all branches
repo forall -c git log --oneline -5        # recent commits per repo
repo forall -c git status                  # working-tree status per repo
```

To pin a component to a specific commit, edit `manifests/default.xml` and
change the `revision` attribute for that project from a branch name to a
full commit SHA, then commit and push the manifest update.

---

## Source repositories

| Component | GitHub | Branch |
|---|---|---|
| Kernel 6.1 | `rockchip-linux/kernel` | `develop-6.1` |
| U-Boot | `rockchip-linux/u-boot` | `next-dev-v2017.09` |
| rkbin (blobs) | `rockchip-linux/rkbin` | `master` |
| RT-Thread | `RT-Thread/rt-thread` | `master` |
| HAL | `rockchip-linux/hal` | `master` |
| Yocto poky | `yoctoproject/poky` | `scarthgap` |
| meta-openembedded | `openembedded/meta-openembedded` | `scarthgap` |
| meta-rockchip | `rockchip-linux/meta-rockchip` | `master` |
| UEFI | `rockchip-linux/edk2` | `master` |
| tools | `rockchip-linux/tools` | `master` |

`rkbin` contains proprietary Rockchip binaries (BL31 ATF, DDR initialisation,
miniloader). There is no open-source replacement for these blobs; they are
fetched from Rockchip's own public GitHub repository.

---

## Initial GitHub setup

```bash
# From the workspace root — do this once after creating the private repo:
git init .
git remote add origin https://github.com/TommasoLabieni/rksdk.git
git add .
git commit -m "Initial SDK"
git push -u origin master
```

After pushing, replace `TommasoLabieni/rksdk` on line 26 of
`manifests/default.xml` with your actual `<org>/<repo>`, commit and push.
From then on any new machine only needs:

```bash
mkdir rksdk && cd rksdk
repo init -u https://github.com/TommasoLabieni/rksdk -b master -m manifests/default.xml
repo sync -j8
```
