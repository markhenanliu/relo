#!/usr/bin/env bash
# ADR-0004 sync spike: runs exit criteria 2 and 3 end to end against local Supabase + PowerSync.
# Prerequisites: `supabase start` (repo root) and `docker compose up -d` (this folder).
# Every run starts from a fresh test user and fresh device databases.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(git rev-parse --show-toplevel)

SUPABASE_KEY=$(cd "$ROOT" && supabase status -o env 2>/dev/null | sed -n 's/^PUBLISHABLE_KEY="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p')
export SUPABASE_KEY
export SPIKE_STATE_DIR=$PWD
BIN=harness/.build/debug/SyncSpike

swift build --package-path harness -q
rm -rf .state
mkdir -p .state

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "Setup: fresh local test user"
$BIN user

step "Criterion 2: offline writes, then force-quit (SIGKILL) with no network"
(RELO_OFFLINE=1 $BIN write-offline --device A --expenses 50 | tee .state/write.log) || echo "(process killed as intended, exit $?)"
step "Reopen after the kill, still offline: is everything still queued?"
$BIN status --device A
step "Back online: upload the queue and download the server state"
$BIN sync --device A
$BIN verify --device A

step "A second device (e.g. a fresh install) downloads the same data"
$BIN sync --device B
$BIN verify --device B

EXPENSE_ID=$(grep "first expense id" .state/write.log | awk '{print $NF}')

step "Criterion 3: conflicting edits on an offline phone and on the web"
echo "1) Phone (offline) sets merchant='Phone edit', amount=9999"
RELO_OFFLINE=1 $BIN edit-offline --device A --id "$EXPENSE_ID" --merchant "Phone edit" --amount 9999
echo "2) Later, web sets merchant='Web edit' and notes='added on web'"
$BIN server-edit --id "$EXPENSE_ID" --merchant "Web edit" --notes "added on web"
echo "3) Phone comes back online and syncs"
$BIN sync --device A
$BIN show --device A --id "$EXPENSE_ID"
$BIN verify --device A
echo "4) Other device syncs"
$BIN sync --device B
$BIN show --device B --id "$EXPENSE_ID"
$BIN verify --device B

step "Web insert reaches the phone"
$BIN server-insert --merchant "Added on web"
$BIN sync --device A
$BIN verify --device A

step "A write the server rejects (invalid category) does not block the queue"
$BIN insert-invalid --device A
$BIN verify --device A

step "Rejected uploads log (expect exactly the invalid insert)"
cat .state/rejected-uploads.log 2>/dev/null || echo "none"
