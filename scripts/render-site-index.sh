#!/usr/bin/env bash
# Render the human-facing Pages catalogue from the signed feed indexes already
# staged under site/feed.  The catalogue never discovers recipe directories or
# build outputs: an entry appears only after its immutable Packages index has
# been staged for publication.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
site_dir="$repo_root/site"
feed_root="$site_dir/feed"
output="$site_dir/index.html"

[[ -d "$feed_root" ]] || {
  echo "missing staged feed directory: $feed_root" >&2
  exit 1
}

temporary=$(mktemp "$site_dir/.index.html.XXXXXX")
cleanup() { rm -f -- "$temporary"; }
trap cleanup EXIT

cat >"$temporary" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>TDVP K230 public opkg feed</title>
    <style>
      :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
      body { margin: 2rem auto; max-width: 72rem; padding: 0 1rem; line-height: 1.5; }
      code { overflow-wrap: anywhere; }
      table { border-collapse: collapse; width: 100%; margin: 1rem 0 2rem; }
      th, td { border: 1px solid #8886; padding: .5rem; text-align: left; vertical-align: top; }
      th { background: #8882; }
      .muted { color: #666; }
    </style>
  </head>
  <body>
    <h1>TDVP K230 public opkg feed</h1>
    <p>This is the ABI-matched, distribution-style userland catalogue for
      TDVP K230: shared libraries, command-line tools, desktop programs, and
      device applications are published here as independent packages. It is
      not an arbitrary cross-device RISC-V binary repository.</p>
    <p>Each feed has an immutable <code>Packages</code> index and detached
      signatures. A package is listed here only when it is present in that
      signed index; local recipes and unbuilt candidates are intentionally not
      shown.</p>
EOF

found=0
while IFS= read -r -d '' index; do
  found=1
  arch=$(basename "$(dirname -- "$index")")
  relative=${index#"$site_dir/"}
  relative=${relative%/Packages}

  printf '    <section>\n      <h2><code>%s</code> / <code>%s</code></h2>\n' \
    "$relative" "$arch" >>"$temporary"
  printf '      <p><a href="%s/Packages">Packages</a> · <a href="%s/Packages.gz">Packages.gz</a> · <a href="%s/Packages.asc">Packages signature</a> · <a href="%s/Packages.gz.asc">Packages.gz signature</a> · <a href="%s/release.json">release metadata</a></p>\n' \
    "$relative" "$relative" "$relative" "$relative" "$relative" >>"$temporary"
  cat >>"$temporary" <<'EOF'
      <table>
        <thead><tr><th>Package</th><th>Type</th><th>Version</th><th>Description</th><th>Runtime dependencies</th><th>Download</th></tr></thead>
        <tbody>
EOF
  awk -v relative="$relative" '
    function value(prefix, i) {
      for (i = 1; i <= NF; ++i)
        if (index($i, prefix) == 1) return substr($i, length(prefix) + 1)
      return ""
    }
    function escape_html(text) {
      gsub(/&/, "\\&amp;", text)
      gsub(/</, "\\&lt;", text)
      gsub(/>/, "\\&gt;", text)
      gsub(/\"/, "\\&quot;", text)
      return text
    }
    BEGIN { RS = ""; FS = "\n" }
    {
      package = value("Package: ")
      version = value("Version: ")
      section = value("Section: ")
      description = value("Description: ")
      dependency = value("Depends: ")
      filename = value("Filename: ")
      if (package == "" || version == "" || filename == "") {
        printf "invalid package record in %s\n", FILENAME > "/dev/stderr"
        exit 1
      }
      if (filename ~ /\// || filename ~ /\.\./ || filename !~ /^[A-Za-z0-9][A-Za-z0-9+._-]*\.ipk$/) {
        printf "unsafe package filename in %s: %s\n", FILENAME, filename > "/dev/stderr"
        exit 1
      }
      printf "          <tr><td><code>%s</code></td><td><code>%s</code></td><td><code>%s</code></td><td>%s</td><td><code>%s</code></td><td><a href=\"%s/%s\">%s</a></td></tr>\n", escape_html(package), escape_html(section), escape_html(version), escape_html(description), escape_html(dependency), relative, filename, escape_html(filename)
    }
  ' "$index" >>"$temporary"
  cat >>"$temporary" <<'EOF'
        </tbody>
      </table>
    </section>
EOF
done < <(find "$feed_root" -type f -name Packages -print0 | LC_ALL=C sort -z)

if [[ "$found" -eq 0 ]]; then
  printf '    <p class="muted">No signed feed has been staged yet.</p>\n' >>"$temporary"
fi

cat >>"$temporary" <<'EOF'
    <h2>Device use</h2>
    <p>On an ABI-matched TDVP K230 image, refresh the configured source with
      <code>sudo tdvp-opkg update</code>. Do not disable
      signature verification. The device accepts only the release key embedded
      in its firmware and only packages that depend on its exact ABI package.</p>
  </body>
</html>
EOF

mv -- "$temporary" "$output"
trap - EXIT
printf 'rendered public feed catalogue: %s\n' "$output"
