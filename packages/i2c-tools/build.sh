#!/usr/bin/env bash
# Build static-only i2c-tools from locked source without exporting libi2c.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# i2c-tools normally builds libi2c.so and, when the platform selects Python,
# py-smbus. The candidate rejects both branches: five command ELF files link
# the private static archive, and the shared helper copies no archive/library
# from its temporary target root. CI never invokes any I2C command.
TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_PYTHON3' \
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='I2C_TOOLS_MAKE_OPTS=BUILD_DYNAMIC_LIB=0 BUILD_STATIC_LIB=1 USE_STATIC_LIB=1' \
TDVP_COMMAND_FRONTEND_NAMES='i2cdetect=tdvp-i2c-detect i2cdump=tdvp-i2c-dump i2cset=tdvp-i2c-set i2cget=tdvp-i2c-get i2ctransfer=tdvp-i2c-transfer' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_I2C_TOOLS_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_I2C_TOOLS i2c-tools 'I2C_TOOLS_VERSION = 4.4' \
    'i2cdetect i2cdump i2cset i2cget i2ctransfer'
