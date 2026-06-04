#!/bin/bash -e

gen_yocto_conf()
{
	echo "include include/common.conf"
	echo "include include/debug.conf"
	echo "include include/audio.conf"

	if [ "$RK_YOCTO_MULTIMEDIA" ]; then
		echo "include include/multimedia.conf"
	fi

	echo
	echo "MACHINE = \"$RK_YOCTO_MACHINE\""

	if [ "$RK_YOCTO_DISPLAY_PLATFORM_NONE" ]; then
		return 0
	fi

	echo
	echo "include include/display.conf"

	if [ "$RK_CHIP_HAS_GPU" ]; then
		echo "include include/glmark2.conf"

		if [ "$RK_YOCTO_CHROMIUM" ]; then
			echo "include include/browser.conf"
		fi
	elif [ "$RK_YOCTO_DISPLAY_PLATFORM_WAYLAND" ]; then
		echo "PACKAGECONFIG:append:pn-weston-init = \" use-pixman\""
	fi

	echo
	echo "DISPLAY_PLATFORM := \"$RK_YOCTO_DISPLAY_PLATFORM\""
}

gen_bblayers_conf()
{
	YOCTO_DIR="$RK_SDK_DIR/yocto"

	cat <<-EOF
	POKY_BBLAYERS_CONF_VERSION = "2"
	BBPATH = "\${TOPDIR}"
	BBFILES ?= ""
	BBLAYERS ?= " \\
	  $YOCTO_DIR/poky/meta \\
	  $YOCTO_DIR/poky/meta-poky \\
	  $YOCTO_DIR/poky/meta-yocto-bsp \\
	  $YOCTO_DIR/meta-openembedded/meta-oe \\
	  $YOCTO_DIR/meta-openembedded/meta-python \\
	  $YOCTO_DIR/meta-openembedded/meta-networking \\
	  $YOCTO_DIR/meta-openembedded/meta-multimedia \\
	  $YOCTO_DIR/meta-rockchip \\
	  "
	EOF
}

build_yocto_conf()
{
	check_config RK_YOCTO || false

	"$RK_SCRIPTS_DIR/check-yocto.sh"

	cd yocto
	mkdir -p build/conf

	gen_bblayers_conf > build/conf/bblayers.conf

	# Overrides for Rockchip SDK
	{
		echo "include include/rksdk.conf"

		echo "include include/rksdk/kernel.conf"
		echo "include include/rksdk/rkbin.conf"
		echo "include include/rksdk/u-boot.conf"

		[ ! -d "$RK_SDK_DIR/external/gstreamer-rockchip" ] || \
			echo "include include/rksdk/gstreamer-rockchip.conf"
		[ ! -d "$RK_SDK_DIR/external/libmali" ] || \
			echo "include include/rksdk/libmali.conf"
		[ ! -d "$RK_SDK_DIR/external/linux-rga" ] || \
			echo "include include/rksdk/librga.conf"
		[ ! -d "$RK_SDK_DIR/external/mpp" ] || \
			echo "include include/rksdk/mpp.conf"

		echo
		echo "PREFERRED_PROVIDER_virtual/bootloader = \"u-boot-dummy\""
		echo "PREFERRED_PROVIDER_u-boot = \"u-boot-dummy\""
		echo "PREFERRED_PROVIDER_virtual/kernel := \"linux-dummy\""
		echo "LINUXLIBCVERSION := \"$RK_KERNEL_VERSION_RAW-custom%\""
		echo "OLDEST_KERNEL := \"$RK_KERNEL_VERSION_RAW\""
		echo "USE_DEPMOD := \"0\""
		case "$RK_CHIP_FAMILY" in
			rk3562|rk3566_rk3568|rk3576|rk3588)
				echo "MALI_VERSION := \"g24p0\"" ;;
		esac
		echo
		# Required for the SDK: generates ext4 rootfs, rootfs.img, and the
		# 'latest' symlink that build scripts rely on.
		echo "IMAGE_CLASSES += \"rockchip-image\""
	} > build/conf/rksdk_override.conf

	rm -f build/conf/local.conf

	if [ "$RK_YOCTO_CFG_CUSTOM" ]; then
		if [ ! -r "$RK_CHIP_DIR/$RK_YOCTO_CFG" ]; then
			error "$RK_CHIP_DIR/$RK_YOCTO_CFG not found!"
			return 1
		fi

		ln -rsf "$RK_CHIP_DIR/$RK_YOCTO_CFG" build/conf/custom.conf
		echo "include custom.conf" > build/conf/local.conf

		message "=========================================="
		message "          Using yocto custom $RK_YOCTO_CFG"
		message "=========================================="
	else
		gen_yocto_conf > build/conf/local.conf

		message "=========================================="
		message "          Using yocto machine($RK_YOCTO_MACHINE)"
		message "=========================================="
	fi

	{
		echo
		echo "include rksdk_override.conf"
	} >> build/conf/local.conf

	if [ "$RK_YOCTO_EXTRA_CFG" ]; then
		if [ ! -r "$RK_CHIP_DIR/$RK_YOCTO_EXTRA_CFG" ]; then
			error "$RK_CHIP_DIR/$RK_YOCTO_EXTRA_CFG not found!"
			return 1
		fi

		ln -rsf "$RK_CHIP_DIR/$RK_YOCTO_EXTRA_CFG" build/conf/extra.conf
		echo "include extra.conf" >> build/conf/local.conf

		message "=========================================="
		message "          With extra config: $RK_YOCTO_EXTRA_CFG"
		message "=========================================="
	fi
}

build_yocto()
{
	check_config RK_YOCTO || false

	IMAGE_DIR="${1:-$RK_OUTDIR/yocto}"

	build_yocto_conf

	source poky/oe-init-build-env build

	LANG=en_US.UTF-8 LANGUAGE=en_US.en LC_ALL=en_US.UTF-8 \
		bitbake "${RK_YOCTO_IMAGE:-core-image-minimal}" -C rootfs

	ln -rsf "$PWD/latest/rootfs.img" "$IMAGE_DIR/rootfs.ext4"

	if [ -r "$RK_LOG_DIR/post-rootfs.log" ]; then
		cat "$RK_LOG_DIR/post-rootfs.log"
	else
		warning "Building without post-rootfs stage!"
	fi

	finish_build build_yocto $@
}

# Hooks

usage_hook()
{
	usage_oneline "rootfs" "build Yocto rootfs"
	usage_oneline "yocto" "build Yocto rootfs"
}

clean_hook()
{
	rm -rf yocto/build/tmp yocto/build/*cache
	rm -rf "$RK_OUTDIR/yocto"
	rm -rf "$RK_OUTDIR/rootfs"
	rm -rf "$RK_FIRMWARE_DIR/rootfs.img"
}

INIT_CMDS="default yocto"
init_hook()
{
	load_config RK_ROOTFS
	check_config RK_ROOTFS &>/dev/null || return 0
}

BUILD_CMDS="rootfs yocto"
build_hook()
{
	check_config RK_ROOTFS || false

	ROOTFS_IMG="$RK_ROOTFS_IMG"
	ROOTFS_DIR="$RK_OUTDIR/yocto"
	IMAGE_DIR="$ROOTFS_DIR/images"

	message "=========================================="
	message "          Start building rootfs (Yocto)"
	message "=========================================="

	rm -rf "$ROOTFS_DIR" "$RK_OUTDIR/rootfs"
	mkdir -p "$IMAGE_DIR"
	ln -rsf "$ROOTFS_DIR" "$RK_OUTDIR/rootfs"

	build_yocto "$IMAGE_DIR"

	if [ ! -f "$IMAGE_DIR/$ROOTFS_IMG" ]; then
		error "No $ROOTFS_IMG generated!"
		exit 1
	fi

	ln -rsf "$IMAGE_DIR/$ROOTFS_IMG" "$RK_FIRMWARE_DIR/rootfs.img"

	finish_build build_rootfs $@
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"

case "${1:-rootfs}" in
	yocto-config) build_yocto_conf ;;
	rootfs | yocto) init_hook $@; build_hook $@ ;;
	*) usage ;;
esac
