#!/usr/bin/env bash
# Canonical source-admitted r10 candidate order.  Keep this list free of
# profiles: it names only recipes that own an upstream source.lock and whose
# archives must be present before the cohort can enter offline build gating.
set -Eeuo pipefail
IFS=$'\n\t'

TDVP_R10_CANDIDATE_COHORT=(
  libpopt libevent libcurl-4 curl wget rsync iperf3 lsof netcat
  htop nano dialog ncdu pv tmux
  sqlite3 bc coreutils mtools dosfstools util-linux exfatprogs memtester libyaml-0
)
