#!/bin/bash
# Download the ARM GNU Toolchain (aarch64-none-linux-gnu) into TC_DIR.
# Called automatically by get_toolchain() when the toolchain is missing.
#
# Usage: download-toolchain.sh <TC_DIR>

set -eE

TC_DIR="$1"
if [ -z "$TC_DIR" ]; then
	echo "Usage: $0 <toolchain-dir>" >&2
	exit 1
fi

TC_VERSION="13.3.rel1"
TC_NAME="arm-gnu-toolchain-${TC_VERSION}-x86_64-aarch64-none-linux-gnu"
TC_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${TC_VERSION}/binrel/${TC_NAME}.tar.xz"
TC_SIZE="~830 MB"

echo ""
echo "  ARM GNU Toolchain not found."
echo "  Version : ${TC_VERSION}"
echo "  Target  : aarch64-none-linux-gnu"
echo "  Dest    : ${TC_DIR}"
echo "  Size    : ${TC_SIZE}"
echo ""
read -r -p "  Download now? [y/N] " REPLY
echo ""

case "$REPLY" in
	[yY][eE][sS]|[yY]) ;;
	*)
		echo "  Skipping toolchain download." >&2
		exit 1
		;;
esac

# Pick downloader
if command -v wget &>/dev/null; then
	DOWNLOADER="wget"
elif command -v curl &>/dev/null; then
	DOWNLOADER="curl"
else
	echo "ERROR: neither wget nor curl found — cannot download toolchain." >&2
	exit 1
fi

TMPFILE="$(mktemp --suffix=.tar.xz)"
trap 'rm -f "$TMPFILE"' EXIT

echo "  Downloading ${TC_NAME}.tar.xz ..."
if [ "$DOWNLOADER" = "wget" ]; then
	wget -O "$TMPFILE" --progress=bar:force:noscroll "$TC_URL"
else
	curl -L -o "$TMPFILE" --progress-bar "$TC_URL"
fi

echo ""
echo "  Extracting to ${TC_DIR} ..."
mkdir -p "$TC_DIR"
tar -xf "$TMPFILE" -C "$TC_DIR" --strip-components=1

echo "  Toolchain ready at ${TC_DIR}/bin/"
