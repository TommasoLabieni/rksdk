#!/bin/bash -e

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"

# No extra partitions configured — nothing to do.
check_config RK_EXTRA_PARTITION_NUM || exit 0

notice "Extra partitions: $RK_EXTRA_PARTITION_NUM"

# Placeholder: add per-extra-partition packing logic here if needed.
# Each extra partition is defined by RK_EXTRA_PARTITION_<N>_* variables.
