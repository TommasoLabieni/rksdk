# Rockchip Linux SDK (Simplified)

Simplified Rockchip Linux SDK supporting RK3399, RK3562, RK3566/RK3568, RK3576, RK3588.
Components: Rockchip Linux kernel 6.1 · U-Boot · Yocto 5.0 rootfs · AMP (HAL + RT-Thread).

## Quick start

```bash
# 1. Fetch all sources
mkdir rksdk && cd rksdk
repo init -u https://github.com/your-org/rksdk -b main -m manifests/default.xml
repo sync -j8

# 2. Select chip + defconfig
./build.sh chip               # interactive: pick chip family
./build.sh defconfig          # interactive: pick defconfig for that chip

# Or select directly:
./build.sh rk3588:rockchip_defconfig
./build.sh rk3568:rockchip_rk3568_evb_amp_defconfig

# 3. (Optional) customize
make menuconfig               # KConfig TUI
make savedefconfig            # write minimal defconfig back to chip dir

# 4. Build
./build.sh all                # full build: loader + kernel + rootfs + firmware
./build.sh loader             # U-Boot only
./build.sh kernel             # kernel only
./build.sh rootfs             # Yocto only
./build.sh amp                # AMP images only (requires RK_AMP=y)
./build.sh firmware           # pack firmware only (re-run after partial builds)

# 5. Flash
./rkflash.sh                  # flash over USB (Rockchip MaskROM / loader protocol)
```

## Directory layout

| Path | Description |
|---|---|
| `build.sh` | Top-level build entry (symlink) |
| `Makefile` | KConfig integration (symlink) |
| `device/rockchip/common/` | Build system: scripts, hooks, KConfig |
| `device/rockchip/<chip>/` | Per-chip configs, ITS files, parameter.txt |
| `device/rockchip/.chips/` | Symlinks used by build.sh chip selection |
| `kernel` → `kernel-6.1/` | Rockchip Linux 6.1 kernel |
| `u-boot/` | Rockchip U-Boot v2017.09 |
| `rkbin/` | Rockchip proprietary blobs (BL31, DDR init, etc.) |
| `prebuilts/` | Cross-compilation toolchains |
| `yocto/` | Yocto 5.0 (Scarthgap): poky + meta-openembedded + meta-rockchip |
| `rtos/` | RT-Thread BSP |
| `hal/` | Rockchip HAL bare-metal library |
| `uefi/` | EDK2-based UEFI |
| `tools/` | Host tools (upgrade_tool, etc.) |
| `output/` | Build artifacts (generated, gitignored) |
| `rockdev/` → `output/firmware/` | Final firmware images |

## Supported chips

| Family | Chips | U-Boot config | AMP |
|---|---|---|---|
| `rk3399` | RK3399, RK3399Pro | `rk3399` | — |
| `rk3562` | RK3562 | `rk3562` | — |
| `rk3566_rk3568` | RK3566, RK3568 | `rk3568` | ✓ |
| `rk3576` | RK3576 | `rk3576` | — |
| `rk3588` | RK3588, RK3588S | `rk3588` | ✓ |

## Source repositories

All sources are fetched via `repo` from official public repositories.
See `.repo/manifests/default.xml` for the full list.

| Component | Repository | Branch |
|---|---|---|
| Kernel 6.1 | `github.com/rockchip-linux/kernel` | `develop-6.1` |
| U-Boot | `github.com/rockchip-linux/u-boot` | `next-dev-v2017.09` |
| rkbin (blobs) | `github.com/rockchip-linux/rkbin` | `master` |
| RT-Thread | `github.com/RT-Thread/rt-thread` | `master` |
| HAL | `github.com/rockchip-linux/hal` | `master` |
| Yocto / poky | `github.com/yoctoproject/poky` | `scarthgap` |
| meta-openembedded | `github.com/openembedded/meta-openembedded` | `scarthgap` |
| meta-rockchip | `github.com/rockchip-linux/meta-rockchip` | `master` |
| tools | `github.com/rockchip-linux/tools` | `master` |

> **Note on rkbin**: The Rockchip binary blobs (BL31 ATF, DDR initialisation, miniloader)
> have no open-source equivalent. They are fetched from the official
> `rockchip-linux/rkbin` repository on GitHub, which is the authoritative public source.

> **Toolchains**: `prebuilts/` is not managed by `repo`.
> Download the Arm GNU Toolchain for AArch64 directly from
> `developer.arm.com/downloads/-/arm-gnu-toolchain-downloads`
> and unpack to `prebuilts/gcc/linux-x86/aarch64/`.

## AMP co-run setup

AMP (Asymmetric Multi-Processing) reserves one or more cores for RT-Thread
alongside the Linux kernel. Supported on **RK3568** and **RK3588**.

- **ITS file** (`device/rockchip/<chip>/configs/amp_linux.its`): defines which
  cores run AMP, their load addresses, shared memory layout, and whether to use
  HAL or RT-Thread per core.
- **HAL** (`hal/`): built for AMP AP cores via `build_hal()` in `25-amp.sh`.
- **RT-Thread** (`rtos/bsp/rockchip/`): built via `scons` per core.
- **Output**: `output/firmware/amp.img` — packed by `mkimage -f amp.its -E`.

To enable AMP, use a `*_amp_defconfig` or set `RK_AMP=y` + `RK_AMP_FIT_ITS` in
`menuconfig`, then set `RK_UBOOT_CFG_FRAGMENTS="rk-amp"`.

## Adding a new board

1. Copy the nearest chip's `rockchip_defconfig` to a new name
   (e.g. `rockchip_rk3588_myboard_defconfig`)
2. Set `RK_KERNEL_DTS_NAME` to your DTS name
3. Adjust `RK_PARAMETER` if the partition layout differs
4. Run `./build.sh rockchip_rk3588_myboard_defconfig`

## Updating sources

```bash
repo sync -j8           # pull latest from all remote branches
repo forall -c git log --oneline -5   # see recent commits per repo
```

## Initial GitHub setup (first push)

```bash
# Inside your local rksdk workspace root:
git init .
git remote add origin https://github.com/your-org/rksdk.git
git add .
git commit -m "Initial SDK"
git push -u origin main
```

After pushing, update `manifests/default.xml` — replace `your-org/rksdk` with
your actual GitHub repo path (`<org>/<repo>`), commit, and push again. Future
users then just need:

```bash
mkdir rksdk && cd rksdk
repo init -u https://github.com/your-org/rksdk -b main -m manifests/default.xml
repo sync -j8
```
