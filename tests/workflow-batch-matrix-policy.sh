#!/usr/bin/env bash
# One central assertion owns the dispatch matrix. Adding a new incremental
# batch must update this file and its own package policy, not every historical
# package test that happens to inspect the same workflow.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
expected_options='options: [archive, audacious, network-tools, http-transfer-tools, secure-transfer-tools, file-sync-tools, terminal-session-tools, process-monitoring-tools, diagnostics-profile, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, exfat-filesystem-tools, memory-diagnostic-tools, directory-tree-tools, terminal-pager-tools, media-inspection-tools, system-tools, nodejs, debug-network-tools, i2c-inspection-tools, filesystem-event-tools, log-maintenance-tools, json-construction-tools, line-editor-tools]'

grep -Fq "$expected_options" "$workflow"
for batch in archive audacious network-tools http-transfer-tools secure-transfer-tools file-sync-tools terminal-session-tools process-monitoring-tools diagnostics-profile desktop-tools retro-gba development-tools database-tools calculator-tools coreutils-tools fat-media-tools fat-filesystem-tools exfat-filesystem-tools memory-diagnostic-tools directory-tree-tools terminal-pager-tools media-inspection-tools system-tools nodejs debug-network-tools i2c-inspection-tools filesystem-event-tools log-maintenance-tools json-construction-tools line-editor-tools; do
  grep -Fq "${batch})" "$workflow"
done

echo 'incremental workflow batch matrix policy: PASS'
