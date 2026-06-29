#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
YOCTO_DIR="$SDK_DIR/yocto"
MACHINE="${MACHINE:-rock5b}"

cd "$YOCTO_DIR"
source poky/oe-init-build-env build

bitbake core-image-minimal
