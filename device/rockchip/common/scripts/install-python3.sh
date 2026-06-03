#!/bin/bash -e

if ! which python3 >/dev/null 2>&1; then
	echo -e "\e[35m"
	echo "python3 is missing"
	echo "Please install it:"
	echo "sudo apt-get install python3 python-is-python3"
	echo -e "\e[0m"
	exit 1
fi

if ! which python >/dev/null 2>&1; then
	echo -e "\e[35m"
	echo "python (python3 alias) is missing"
	echo "Please install it:"
	echo "sudo apt-get install python-is-python3"
	echo -e "\e[0m"
	exit 1
fi
