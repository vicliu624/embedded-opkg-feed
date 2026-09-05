#!/usr/bin/env bash
# Build locked GNU mtools with Buildroot, retaining its multi-call argv[0]
# dispatch privately and exposing only explicit TDVP-prefixed frontends.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# mtools installs one `mtools` ELF and named relative symlinks.  The shared
# helper preserves those symlinks below /usr/libexec/tdvp-mtools, so the real
# program observes the right argv[0], while wrappers keep all public paths in
# the TDVP namespace.
TDVP_COMMAND_FRONTEND_NAMES='mtools=tdvp-mtools mkmanifest=tdvp-mtools-mkmanifest mattrib=tdvp-mtools-mattrib mcat=tdvp-mtools-mcat mcd=tdvp-mtools-mcd mclasserase=tdvp-mtools-mclasserase mcopy=tdvp-mtools-mcopy mdel=tdvp-mtools-mdel mdeltree=tdvp-mtools-mdeltree mdir=tdvp-mtools-mdir mdu=tdvp-mtools-mdu mformat=tdvp-mtools-mformat minfo=tdvp-mtools-minfo mlabel=tdvp-mtools-mlabel mmd=tdvp-mtools-mmd mmount=tdvp-mtools-mmount mmove=tdvp-mtools-mmove mpartition=tdvp-mtools-mpartition mrd=tdvp-mtools-mrd mren=tdvp-mtools-mren mtype=tdvp-mtools-mtype mtoolstest=tdvp-mtools-mtoolstest mshortname=tdvp-mtools-mshortname mshowfat=tdvp-mtools-mshowfat mbadblocks=tdvp-mtools-mbadblocks mzip=tdvp-mtools-mzip' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_MTOOLS_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_MTOOLS mtools 'MTOOLS_VERSION = 4.0.47' \
    'mtools mkmanifest mattrib mcat mcd mclasserase mcopy mdel mdeltree mdir mdu mformat minfo mlabel mmd mmount mmove mpartition mrd mren mtype mtoolstest mshortname mshowfat mbadblocks mzip'
