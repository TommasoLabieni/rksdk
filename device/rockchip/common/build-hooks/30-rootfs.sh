#!/bin/bash -e

usage_hook()
{
	usage_oneline "rootfs" "build Yocto rootfs"
	usage_oneline "yocto" "build Yocto rootfs"
	usage_oneline "sdk" "build Yocto SDK (populate_sdk) for the active board"
}

clean_hook()
{
	"$RK_SCRIPTS_DIR/mk-rootfs.sh" clean
}

INIT_CMDS="default yocto rootfs"
init_hook()
{
	"$RK_SCRIPTS_DIR/mk-rootfs.sh" init $@
}

BUILD_CMDS="rootfs yocto sdk"
build_hook()
{
	"$RK_SCRIPTS_DIR/mk-rootfs.sh" $@
	finish_build $@
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"

build_hook $@
