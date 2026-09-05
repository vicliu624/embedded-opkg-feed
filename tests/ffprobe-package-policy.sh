#!/usr/bin/env bash
# Keep the FFmpeg-derived metadata probe as a source-locked, non-overwriting
# r10 leaf before it may be dispatched to the K230 GitHub Actions builder.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/ffprobe"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='ffprobe'" "$package_dir/package.env"
grep -Fqx "VERSION='4.4.4-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_RELEASES='r7 r10'" "$package_dir/package.env"
grep -Fqx "PACKAGE_BASE_OVERLAY='deny'" "$package_dir/package.env"
grep -Fqx "UPSTREAM_VERSION='4.4.4'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_FILE='ffmpeg-4.4.4.tar.xz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='e80b380d595c809060f66f96a5d849511ef4a76a26b76eacf5778b94c3570309'" "$package_dir/source.lock"
grep -Fq "BR2_PACKAGE_FFMPEG_FFPROBE" "$package_dir/build.sh"
grep -Fq "install_root/usr/bin/ffprobe" "$package_dir/build.sh"
grep -Fq 'mkdir -p -- "$output/images/deb"' "$package_dir/build.sh"
grep -Fq 'media-inspection-tools)' "$workflow"
grep -Fq 'package_args=(--package ffprobe)' "$workflow"
grep -Fq 'expected_packages=(ffprobe)' "$workflow"
grep -Fq 'bash ./tests/ffprobe-package-policy.sh' "$workflow"

echo 'source-locked ffprobe r10 candidate policy: PASS'
