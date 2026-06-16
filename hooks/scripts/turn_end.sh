#!/bin/bash
# turn_end.sh — Handles post_cascade_response hook for Devin/Cascade
# Records changes with full AI provenance at end of each turn.
set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)

# Only run inside an Atomic repository
[ -d .atomic ] || exit 0

SESSION_FILE=".atomic/devin_session"
[ -f "$SESSION_FILE" ] || exit 0

SESSION_ID=$(cat "$SESSION_FILE")
TRAJECTORY_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('trajectory_id',''))" 2>/dev/null || echo "")
MODEL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model_name','unknown'))" 2>/dev/null || echo "unknown")

# Delegate turn-end recording to the atomic agent orchestrator
# This triggers: status → add (track new files) → record --all with AI provenance
printf '{"session_id":"%s","cwd":"%s","model":"%s","trajectory_id":"%s"}' \
  "$SESSION_ID" "$(pwd)" "$MODEL_NAME" "$TRAJECTORY_ID" \
  | atomic agent hooks devin stop 2>/dev/null || true

exit 0
