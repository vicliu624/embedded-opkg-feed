#!/usr/bin/env bash
# Render the human-facing Pages catalogue from the signed feed indexes already
# staged under site/feed.  The catalogue never discovers recipe directories or
# build outputs: an entry appears only after its immutable Packages index has
# been staged for publication.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
site_dir=${TDVP_FEED_SITE_ROOT:-"$repo_root/site"}
site_dir=$(cd -- "$site_dir" && pwd)
feed_root="$site_dir/feed"
output="$site_dir/index.html"

[[ -d "$feed_root" ]] || {
  echo "missing staged feed directory: $feed_root" >&2
  exit 1
}

temporary=$(mktemp "$site_dir/.index.html.XXXXXX")
cleanup() { rm -f -- "$temporary"; }
trap cleanup EXIT

render_release_directory() {
  local index=$1
  local directory relative release_output release_temporary filename publication_note

  directory=$(dirname -- "$index")
  relative=${directory#"$site_dir/"}
  release_output="$directory/index.html"
  release_temporary=$(mktemp "$directory/.index.html.XXXXXX")
  case "/$relative/" in
    */stable/*)
      publication_note='This is the signed stable channel used by devices. It is replaced only as a complete, verified copy of one immutable rN snapshot.'
      ;;
    *)
      publication_note='This is an immutable rN HTTP directory. It is never replaced or re-signed after publication.'
      ;;
  esac

  {
    cat <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>TDVP opkg feed files: ${relative}</title>
    <style>
      :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
      body { margin: 2rem auto; max-width: 72rem; padding: 0 1rem; line-height: 1.5; }
      code { overflow-wrap: anywhere; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #8886; padding: .5rem; text-align: left; }
      th { background: #8882; }
    </style>
  </head>
  <body>
    <p><a href="/embedded-opkg-feed/">TDVP feed catalogue</a></p>
    <h1>Feed files</h1>
    <p><code>${relative}</code></p>
    <p>${publication_note} Index files must be verified with their detached
      signatures before installation.</p>
    <table>
      <thead><tr><th>File</th><th>Bytes</th><th>Purpose</th></tr></thead>
      <tbody>
EOF
    while IFS= read -r filename; do
      case "$filename" in
        Packages) purpose='uncompressed package index' ;;
        Packages.gz) purpose='compressed package index used by opkg' ;;
        Packages.asc) purpose='detached signature for Packages' ;;
        Packages.gz.asc) purpose='detached signature for Packages.gz' ;;
        release.json) purpose='immutable ABI and release metadata' ;;
        *.ipk) purpose='installable opkg package' ;;
        index.html) continue ;;
        *) continue ;;
      esac
      printf '        <tr><td><a href="%s"><code>%s</code></a></td><td>%s</td><td>%s</td></tr>\n' \
        "$filename" "$filename" "$(wc -c <"$directory/$filename")" "$purpose"
    done < <(find "$directory" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)
    cat <<'EOF'
      </tbody>
    </table>
  </body>
</html>
EOF
  } >"$release_temporary"
  mv -- "$release_temporary" "$release_output"
}

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
    <p>Each immutable <code>rN</code> snapshot has a signed
      <code>Packages</code> index and detached signatures. The
      <code>stable</code> endpoint is the device-facing channel: it is changed
      only by promoting a complete, already verified snapshot. A package is
      listed here only when it is present in that signed index; local recipes
      and unbuilt candidates are intentionally not shown.</p>
    <h2>Feed directories</h2>
    <p>Browse the raw, FTP-style HTTP directories below. Each directory
      contains the package index, detached signatures, release metadata, and
      every installable <code>.ipk</code> for that exact ABI and architecture.</p>
    <ul>
EOF

while IFS= read -r -d '' directory_index; do
  directory_relative=${directory_index#"$site_dir/"}
  directory_relative=${directory_relative%/Packages}
  printf '      <li><a href="%s/"><code>/%s/</code></a></li>\n' \
    "$directory_relative" "$directory_relative" >>"$temporary"
done < <(find "$feed_root" -type f -name Packages -print0 | LC_ALL=C sort -z)

cat >>"$temporary" <<'EOF'
    </ul>
    <h2>Package catalogue</h2>
EOF

found=0
while IFS= read -r -d '' index; do
  found=1
  arch=$(basename "$(dirname -- "$index")")
  relative=${index#"$site_dir/"}
  relative=${relative%/Packages}

  render_release_directory "$index"

  printf '    <section>\n      <h2><code>%s</code> / <code>%s</code></h2>\n' \
    "$relative" "$arch" >>"$temporary"
  printf '      <p><a href="%s/">Browse release files</a> · <a href="%s/Packages">Packages</a> · <a href="%s/Packages.gz">Packages.gz</a> · <a href="%s/Packages.asc">Packages signature</a> · <a href="%s/Packages.gz.asc">Packages.gz signature</a> · <a href="%s/release.json">release metadata</a></p>\n' \
    "$relative" "$relative" "$relative" "$relative" "$relative" "$relative" >>"$temporary"
  cat >>"$temporary" <<'EOF'
      <table>
        <thead><tr><th>Package</th><th>Type</th><th>Version</th><th>Description</th><th>Runtime dependencies</th><th>Download</th></tr></thead>
        <tbody>
EOF
  awk -v relative="$relative" '
    function value(prefix, i, result) {
      for (i = 1; i <= NF; ++i) {
        if (index($i, prefix) == 1) {
          result = substr($i, length(prefix) + 1)
          # Historical r1 indexes were committed with CRLF line endings.
          # Strip only the record terminator so the filename whitelist remains
          # strict while the published catalogue can enumerate both releases.
          sub(/\r$/, "", result)
          return result
        }
      }
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
      <code>sudo tdvp-opkg update</code>. The firmware adds
      <code>/usr/local/sbin</code> to interactive <code>PATH</code>, so there
      is no need to spell the wrapper's absolute path. Do not disable
      signature verification. The device accepts only the release key embedded
      in its firmware and only packages that depend on its exact ABI package.</p>
  </body>
</html>
EOF

mv -- "$temporary" "$output"
trap - EXIT
printf 'rendered public feed catalogue: %s\n' "$output"
