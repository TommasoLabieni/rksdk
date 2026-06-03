#!/bin/bash -e

for cmd in mke2fs resize2fs e2fsck mkfs.ext4; do
	if ! which "$cmd" >/dev/null 2>&1; then
		echo -e "\e[35m"
		echo "$cmd is missing"
		echo "Please install it:"
		echo "sudo apt-get install e2fsprogs"
		echo -e "\e[0m"
		exit 1
	fi
done
