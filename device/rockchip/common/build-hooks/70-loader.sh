#!/bin/bash -e

build_uboot()
{
	check_config RK_LOADER RK_UBOOT_CFG || false

	if [ -z "$DRY_RUN" ]; then
		rm -f u-boot/*.bin u-boot/*.img
	fi

	UARGS_COMMON="$RK_UBOOT_OPTS \
		${RK_UBOOT_INI:+../rkbin/RKBOOT/$RK_UBOOT_INI} \
		${RK_UBOOT_TRUST_INI:+../rkbin/RKTRUST/$RK_UBOOT_TRUST_INI}"
	UARGS="$UARGS_COMMON ${RK_UBOOT_SPL:+--spl-new}"

	[ ! "$RK_SECURITY_BURN_KEY" ] || \
		UARGS="$UARGS ${RK_SECUREBOOT_FIT:+--burn-key-hash}"

	[ ! "$RK_SECURITY_REMOTE_SIGN" ] || \
		UARGS="$UARGS ${RK_SECUREBOOT_FIT:+--no-sign}"

	# Inject board u-boot defconfig from device/rockchip/<chip>/ if not upstream.
	_uboot_defconfig="${RK_UBOOT_CFG}_defconfig"
	if [ ! -f "u-boot/configs/$_uboot_defconfig" ] && \
	   [ -f "$RK_CHIP_DIR/$_uboot_defconfig" ]; then
		notice "Injecting $_uboot_defconfig into u-boot/configs/"
		cp "$RK_CHIP_DIR/$_uboot_defconfig" "u-boot/configs/$_uboot_defconfig"
	fi
	unset _uboot_defconfig

	# Inject board DTS/DTSI files from device/rockchip/<chip>/dts/ if not upstream.
	if [ -d "$RK_CHIP_DIR/dts" ]; then
		for _dts in "$RK_CHIP_DIR/dts/"*.dts "$RK_CHIP_DIR/dts/"*.dtsi; do
			[ -f "$_dts" ] || continue
			_dst="u-boot/arch/arm/dts/$(basename "$_dts")"
			if [ ! -f "$_dst" ]; then
				notice "Injecting $(basename "$_dts") into u-boot/arch/arm/dts/"
				cp "$_dts" "$_dst"
			fi
		done
		unset _dts _dst
	fi

	# Inject board-specific headers from device/rockchip/<chip>/uboot-headers/ if missing.
	if [ -d "$RK_CHIP_DIR/uboot-headers" ]; then
		while IFS= read -r -d '' _hdr; do
			_rel="${_hdr#$RK_CHIP_DIR/uboot-headers/}"
			_dst="u-boot/include/$_rel"
			if [ ! -f "$_dst" ]; then
				mkdir -p "$(dirname "$_dst")"
				notice "Injecting $_rel into u-boot/include/"
				cp "$_hdr" "$_dst"
			fi
		done < <(find "$RK_CHIP_DIR/uboot-headers" -type f -print0)
		unset _hdr _rel _dst
	fi

	run_command cd u-boot

	run_command $UMAKE $RK_UBOOT_CFG $RK_UBOOT_CFG_FRAGMENTS $UARGS
	[ ! -z "$DRY_RUN" ] || "$RK_SCRIPTS_DIR/check-security.sh" uboot

	if [ "$RK_SECURITY_OPTEE_STORAGE_SECURITY" ]; then
		if [ -z "$(rk_partition_size security)" ]; then
			error "\"security\" partition not found in parameter"
			return 1
		fi
	fi

	if [ "$RK_SECUREBOOT_AVB" ]; then
		if [ -z "$(rk_partition_size vbmeta)" ]; then
			error "\"vbmeta\" partition not found in parameter"
			return 1
		fi
	fi

	if [ "$RK_UBOOT_SPL" ]; then
		if [ "$DRY_RUN" ] || \
			! grep -q "ROCKCHIP_FIT_IMAGE_PACK=y" .config; then
			# Repack SPL for non-FIT u-boot
			run_command $UMAKE $UARGS_COMMON --spl
		fi
	fi

	if [ "$RK_UBOOT_RAW" ]; then
		run_command $UMAKE $UARGS_COMMON --idblock
	fi

	run_command cd ..

	if [ "$DRY_RUN" ]; then
		return 0
	fi

	LOADER="$(echo u-boot/*_loader_*.bin | head -1)"
	if [ "$RK_SECUREBOOT_AVB" ]; then
	       "$RK_SCRIPTS_DIR/mk-security.sh" sign loader $LOADER \
				"$RK_FIRMWARE_DIR"/MiniLoaderAll.bin
	       "$RK_SCRIPTS_DIR/mk-security.sh" sign uboot u-boot/uboot.img \
				"$RK_FIRMWARE_DIR"/uboot.img
	       "$RK_SCRIPTS_DIR/mk-security.sh" sign trust u-boot/trust.img \
				"$RK_FIRMWARE_DIR"/trust.img
	else
		ln -rsf "$LOADER" "$RK_FIRMWARE_DIR"/MiniLoaderAll.bin
		ln -rsf u-boot/uboot.img "$RK_FIRMWARE_DIR"
		[ ! -e u-boot/trust.img ] || \
			ln -rsf u-boot/trust.img "$RK_FIRMWARE_DIR"
	fi
}

# Hooks

usage_hook()
{
	usage_oneline "loader[:dry-run]" "build loader (u-boot)"
	usage_oneline "uboot[:dry-run]" "build u-boot"
	usage_oneline "u-boot[:dry-run]" "alias of uboot"
}

clean_hook()
{
	make -C u-boot distclean

	rm -rf "$RK_FIRMWARE_DIR/uboot.img"
	rm -rf "$RK_FIRMWARE_DIR/MiniLoaderAll.bin"
}

BUILD_CMDS="loader uboot u-boot"
build_hook()
{
	if echo $RK_UBOOT_CFG $RK_UBOOT_CFG_FRAGMENTS | grep -q aarch32 && \
		[ "$RK_UBOOT_ARCH" = arm64 ]; then
		error "Wrong u-boot arch ($RK_UBOOT_ARCH) for config:" \
			"$RK_UBOOT_CFG $RK_UBOOT_CFG_FRAGMENTS\n"
		export RK_UBOOT_ARCH=arm
	fi

	RK_UBOOT_TOOLCHAIN="$(get_toolchain U-Boot "$RK_UBOOT_ARCH")"
	[ "$RK_UBOOT_TOOLCHAIN" ] || exit 1

	message "Toolchain for loader (U-Boot):"
	message "${RK_UBOOT_TOOLCHAIN:-gcc}"
	echo

	export UMAKE="./make.sh CROSS_COMPILE=$RK_UBOOT_TOOLCHAIN"

	if [ "$DRY_RUN" ]; then
		notice "Commands of building U-Boot:"
	else
		message "=========================================="
		message "          Start building U-Boot"
		message "=========================================="
	fi

	build_uboot

	if [ -z "$DRY_RUN" ]; then
		finish_build build_uboot
	fi
}

build_hook_dry()
{
	DRY_RUN=1 build_hook $@
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"

build_hook $@
