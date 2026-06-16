#!/bin/bash
# session_end.sh — Handles session end for Devin/Cascade
# Creates attestation and cleans up session state.
set -euo pipefail

# Read JSON from stdin (may be empty if called directly)
INPUT=$(cat 2>/dev/null || echo "{}")

# Only run inside an Atomic repository
[ -d .atomic ] || exit 0

SESSION_FILE=".atomic/devin_session"
[ -f "$SESSION_FILE" ] || exit 0

SESSION_ID=$(cat "$SESSION_FILE")
TRAJECTORY_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('trajectory_id',''))" 2>/dev/null || echo "")

# Delegate session end to the atomic agent orchestrator
# This triggers: final record (if needed) → attestation → view restore
printf '{"session_id":"%s","cwd":"%s","trajectory_id":"%s"}' \
  "$SESSION_ID" "$(pwd)" "$TRAJECTORY_ID" \
  | atomic agent hooks devin session-end 2>/dev/null || true

# Clean up session file
rm -f "$SESSION_FILE"

exit 0
