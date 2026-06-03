#!/bin/bash -e

HEADER="$1"
APT_PACKAGE="${2:-$HEADER}"

if ! echo "#include <$HEADER>" | gcc -x c - -fsyntax-only 2>/dev/null; then
	echo -e "\e[35m"
	echo "Your $HEADER is missing"
	echo "Please install it:"
	echo "sudo apt-get install $APT_PACKAGE"
	echo -e "\e[0m"
	exit 1
fi
