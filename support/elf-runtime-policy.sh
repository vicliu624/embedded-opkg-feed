#!/usr/bin/env bash
# Narrow target-ELF policy helpers. Feed payloads may rely on the platform
# loader search path and explicitly-owned SONAME IPKs, but must never retain a
# non-empty build-directory RPATH/RUNPATH that makes an IPK depend on a
# developer's SDK.  Some reviewed Buildroot target objects carry an empty
# DT_RUNPATH (`[]`); it supplies no search location and is safe only because a
# target-derived IPK copies that object byte-for-byte.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_assert_elf_without_runtime_search_path() {
  local readelf_tool=$1 elf=$2 runtime_path_records
  [[ -x "$readelf_tool" ]] || { echo "target readelf is not executable: $readelf_tool" >&2; return 64; }
  [[ -f "$elf" && ! -L "$elf" ]] || { echo "ELF is not a regular file: $elf" >&2; return 65; }
  runtime_path_records=$("$readelf_tool" -dW "$elf" 2>/dev/null | grep -E '\((RPATH|RUNPATH)\)' || true)
  [[ -z "$runtime_path_records" ]] && return 0
  # An empty dynamic-string value is represented by readelf as [] (or, on
  # some versions, [   ]). It cannot affect loader lookup and retains the
  # target object without modifying its bytes. Any non-empty record remains a
  # hard release failure, including $ORIGIN and relative paths.
  if ! grep -Ev '\[[[:space:]]*\]' <<<"$runtime_path_records" | grep -q .; then
    return 0
  fi
  {
    echo "target ELF retains RPATH/RUNPATH and cannot be published: $elf" >&2
    printf '%s\n' "$runtime_path_records" >&2
  }
  return 66
}

# Libtool can leave an in-tree RPATH in a target executable when a Buildroot
# package builds both a CLI and its library in the same source directory.
# The path is neither valid nor acceptable on a TDVP device. Remove only
# DT_RPATH/DT_RUNPATH entries from a 64-bit little-endian ELF .dynamic table;
# do not edit strings opportunistically, because the dynamic tag itself would
# remain observable and could regress unnoticed.
tdvp_remove_elf_runtime_search_paths() {
  local readelf_tool=$1 elf=$2
  [[ -x "$readelf_tool" ]] || { echo "target readelf is not executable: $readelf_tool" >&2; return 64; }
  [[ -f "$elf" && ! -L "$elf" ]] || { echo "ELF is not a regular file: $elf" >&2; return 65; }
  if ! "$readelf_tool" -dW "$elf" 2>/dev/null | grep -Eq '\((RPATH|RUNPATH)\)'; then
    return 0
  fi
  command -v perl >/dev/null || { echo 'removing target ELF RPATH/RUNPATH requires host perl' >&2; return 67; }
  perl - "$elf" <<'PERL'
use strict;
use warnings;
use bytes;

my ($path) = @ARGV;
open my $in, '<:raw', $path or die "open $path: $!\n";
local $/;
my $image = <$in>;
close $in or die "close $path: $!\n";

die "not an ELF file: $path\n" unless substr($image, 0, 4) eq "\x7fELF";
die "only ELF64 is supported while removing RPATH: $path\n" unless ord(substr($image, 4, 1)) == 2;
die "only little-endian ELF is supported while removing RPATH: $path\n" unless ord(substr($image, 5, 1)) == 1;

sub u16le { return unpack('v', substr($_[0], $_[1], 2)); }
sub u32le { return unpack('V', substr($_[0], $_[1], 4)); }
sub u64le { return unpack('Q<', substr($_[0], $_[1], 8)); }

my $section_table = u64le($image, 0x28);
my $section_size = u16le($image, 0x3a);
my $section_count = u16le($image, 0x3c);
die "invalid ELF64 section table: $path\n"
    unless $section_size >= 64 && $section_count > 0 &&
           $section_table + $section_size * $section_count <= length($image);

my ($dynamic_offset, $dynamic_size, $dynamic_entry_size);
for my $index (0 .. $section_count - 1) {
    my $section = $section_table + $index * $section_size;
    next unless u32le($image, $section + 4) == 6; # SHT_DYNAMIC
    die "multiple dynamic sections in $path\n" if defined $dynamic_offset;
    $dynamic_offset = u64le($image, $section + 24);
    $dynamic_size = u64le($image, $section + 32);
    $dynamic_entry_size = u64le($image, $section + 56);
}
die "ELF has no usable .dynamic section: $path\n"
    unless defined $dynamic_offset && $dynamic_entry_size == 16 &&
           $dynamic_size >= 16 && $dynamic_size % 16 == 0 &&
           $dynamic_offset + $dynamic_size <= length($image);

my @remove;
my $entry_count = $dynamic_size / 16;
for my $index (0 .. $entry_count - 1) {
    my $entry = $dynamic_offset + $index * 16;
    my $tag = u64le($image, $entry);
    push @remove, $index if $tag == 15 || $tag == 29; # DT_RPATH, DT_RUNPATH
}
die "ELF has no RPATH/RUNPATH despite preflight: $path\n" unless @remove;
die "ELF dynamic table has no terminating DT_NULL: $path\n"
    unless u64le($image, $dynamic_offset + ($entry_count - 1) * 16) == 0;

# Remove from the end so each splice preserves all later dynamic entries and
# leaves the sole terminating DT_NULL at the end of the table.
for my $index (sort { $b <=> $a } @remove) {
    my $entry = $dynamic_offset + $index * 16;
    my $tail = $dynamic_offset + $dynamic_size - ($entry + 16);
    substr($image, $entry, $tail) = substr($image, $entry + 16, $tail);
    substr($image, $dynamic_offset + $dynamic_size - 16, 16) = "\0" x 16;
}

my @stat = stat($path) or die "stat $path: $!\n";
my $temporary = "$path.tdvp-rpath-$$";
unlink $temporary;
open my $out, '>:raw', $temporary or die "open $temporary: $!\n";
print {$out} $image or die "write $temporary: $!\n";
close $out or die "close $temporary: $!\n";
chmod($stat[2] & 07777, $temporary) or die "chmod $temporary: $!\n";
rename $temporary, $path or die "rename $temporary to $path: $!\n";
PERL
  tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$elf"
}
