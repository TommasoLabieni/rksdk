#!/bin/bash -e

TARGET_DIR="$1"
[ "$TARGET_DIR" ] || exit 1

[ "$RK_YOCTO_USBMOUNT" ] || exit 0

OVERLAY_DIR="$(dirname "$(realpath "$0")")"

message "Installing usbmount..."

tar xvf "$OVERLAY_DIR/usbmount.tar" -C "$TARGET_DIR"

for type in storage udisk sdcard; do
	mkdir -p "$TARGET_DIR/media/$type"{1,2,3}
	mkdir -p "$TARGET_DIR/mnt/$type"
	rm -rf "$TARGET_DIR/media/${type}0"
	ln -sf "/mnt/$type" "$TARGET_DIR/media/${type}0"
done
