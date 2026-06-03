#!/bin/bash -e

RK_SCRIPTS_DIR="${RK_SCRIPTS_DIR:-$(dirname "$(realpath "$0")")}"
RK_SDK_DIR="${RK_SDK_DIR:-$RK_SCRIPTS_DIR/../../../..}"

cd "$RK_SDK_DIR"

HEADERS_DIR="kernel/include/generated"

if [ ! -f "$HEADERS_DIR/uapi/linux/version.h" ] && \
   [ ! -f "$HEADERS_DIR/utsrelease.h" ]; then
	echo -e "\e[35m"
	echo "Kernel headers appear incomplete — expected files under $HEADERS_DIR"
	echo "Try: ./build.sh clean-kernel && ./build.sh kernel"
	echo -e "\e[0m"
	exit 1
fi
