#!/bin/bash -e

TARGET_DIR="$1"
[ "$TARGET_DIR" ] || exit 1

OVERLAY_DIR="$(dirname "$(realpath "$0")")"

message "Installing full-busybox..."
RK_ROOTFS_PREFER_PREBUILT_TOOLS=y ensure_tools "$TARGET_DIR/bin/busybox"

# Login root on serial console
if [ -r "$TARGET_DIR/etc/inittab" ]; then
	sed -i 's~\(respawn:.*\)/bin/start_getty.*~\1/bin/login -p root~' \
		"$TARGET_DIR/etc/inittab"
fi

# Drop Poky warnings in motd
if [ -r "$TARGET_DIR/etc/motd" ]; then
	sed -i '/^WARNING: Poky/,+2d' "$TARGET_DIR/etc/motd"
fi

# Use uid to detect root user
if [ -r "$TARGET_DIR/etc/profile" ]; then
	sed -i 's~"$HOME" != "/home/root"~$(id -u) -ne 0~' \
		"$TARGET_DIR/etc/profile"
fi

if [ -r "$TARGET_DIR/etc/ntp.conf" ] && \
	! grep -q "^server .*ntp" "$TARGET_DIR/etc/ntp.conf"; then
	message "Applying global NTP server..."
	echo >> "$TARGET_DIR/etc/ntp.conf"
	echo "server 0.pool.ntp.org iburst" >> "$TARGET_DIR/etc/ntp.conf"
	echo "server 1.pool.ntp.org iburst" >> "$TARGET_DIR/etc/ntp.conf"
	echo "server 2.pool.ntp.org iburst" >> "$TARGET_DIR/etc/ntp.conf"
	echo "server 3.pool.ntp.org iburst" >> "$TARGET_DIR/etc/ntp.conf"
fi

# Switch from the compat to the files module
# See: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=880846
if [ -r "$TARGET_DIR/etc/nsswitch.conf" ]; then
	sed -i 's/\<compat$/files/' "$TARGET_DIR/etc/nsswitch.conf"
fi

if [ -r "$TARGET_DIR/lib/systemd/system/dhcpcd.service" ]; then
	message "Enabling dhcpcd service..."

	WANTS_DIR="$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
	mkdir -p "$WANTS_DIR"
	ln -rsf "$TARGET_DIR/lib/systemd/system/dhcpcd.service" "$WANTS_DIR/"
fi

$RK_RSYNC "$OVERLAY_DIR/" "$TARGET_DIR/"
