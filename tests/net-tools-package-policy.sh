#!/usr/bin/env bash
# net-tools is a private command-only candidate; protect its network side-effect
# boundary before GitHub Actions capacity is used.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/net-tools"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='net-tools'" "$package_dir/package.env"
grep -Fqx "VERSION='2.10-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$package_dir/package.env"
grep -Fqx 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' "$package_dir/package.env"
grep -Fqx "PACKAGE_BASE_OVERLAY='deny'" "$package_dir/package.env"
grep -Fqx "SOURCE_TYPE='buildroot-derived'" "$package_dir/source.lock"
grep -Fqx "UPSTREAM_VERSION='2.10'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_FILE='net-tools-2.10.tar.xz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='b262435a5241e89bfa51c3cabd5133753952f7a7b7b93f32e08cb9d96f580d69'" "$package_dir/source.lock"
grep -Fq "BR2_PACKAGE_NET_TOOLS net-tools 'NET_TOOLS_VERSION = 2.10'" "$package_dir/build.sh"
grep -Fq 'arp=tdvp-arp ifconfig=tdvp-ifconfig' "$package_dir/build.sh"
grep -Fq "'arp ifconfig ipmaddr iptunnel mii-tool nameif netstat plipconfig rarp route slattach'" "$package_dir/build.sh"
if sed '/^[[:space:]]*#/d' "$package_dir/build.sh" | grep -Eq '/(usr/)?s?bin/(arp|ifconfig|ipmaddr|iptunnel|mii-tool|nameif|netstat|plipconfig|rarp|route|slattach)|apt|dpkg|debian'; then
  echo 'net-tools recipe must keep only private approved commands and no Debian binary input' >&2
  exit 1
fi

grep -Fq 'legacy-network-tools)' "$workflow"
grep -Fq 'package_args=(--package net-tools)' "$workflow"
grep -Fq 'expected_packages=(net-tools)' "$workflow"
grep -Fq 'bash ./tests/net-tools-package-policy.sh' "$workflow"

echo 'locked private net-tools policy: PASS'
