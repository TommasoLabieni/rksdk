#!/bin/bash -e

RK_SCRIPTS_DIR="${RK_SCRIPTS_DIR:-$(dirname "$(realpath "$0")")}"
RK_SDK_DIR="${RK_SDK_DIR:-$RK_SCRIPTS_DIR/../../../..}"

[ "$RK_KERNEL_DTB" -a -r "$RK_KERNEL_DTB" ] || exit 0

cd "$RK_SDK_DIR"

# Verify that at least one power-domain node is present in the DTB.
# Missing power domains typically cause hang-on-boot for Rockchip SoCs.
if ! strings "$RK_KERNEL_DTB" | grep -q "power-domain"; then
	echo -e "\e[35m"
	echo "WARNING: No power-domain nodes found in $RK_KERNEL_DTB"
	echo "This may cause boot issues on Rockchip SoCs."
	echo -e "\e[0m"
fi
