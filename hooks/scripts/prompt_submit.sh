#!/bin/bash
# prompt_submit.sh — Handles pre_user_prompt hook for Devin/Cascade
# Creates session on first prompt, tracks all prompts.
set -euo pipefail

# Read JSON from stdin (Devin passes hook context as JSON)
INPUT=$(cat)

# Only run inside an Atomic repository
[ -d .atomic ] || exit 0

# Extract fields from Devin's JSON payload
TRAJECTORY_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('trajectory_id',''))" 2>/dev/null || echo "")
MODEL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model_name','unknown'))" 2>/dev/null || echo "unknown")
USER_PROMPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_info',{}).get('user_prompt',''))" 2>/dev/null || echo "")

# Build session ID from trajectory ID
SESSION_ID="${TRAJECTORY_ID:-devin-$(date +%s)}"

# Session start: create draft view on first prompt
SESSION_FILE=".atomic/devin_session"
if [ ! -f "$SESSION_FILE" ]; then
  echo "$SESSION_ID" > "$SESSION_FILE"
  # Delegate session creation to the atomic agent orchestrator
  printf '{"session_id":"%s","cwd":"%s","model":"%s","prompt":"%s"}' \
    "$SESSION_ID" "$(pwd)" "$MODEL_NAME" "$(echo "$USER_PROMPT" | head -c 200)" \
    | atomic agent hooks devin session-start 2>/dev/null || true
fi

# Track every prompt
printf '{"session_id":"%s","cwd":"%s","model":"%s","prompt":"%s"}' \
  "$(cat "$SESSION_FILE")" "$(pwd)" "$MODEL_NAME" "$(echo "$USER_PROMPT" | head -c 500)" \
  | atomic agent hooks devin prompt-submit 2>/dev/null || true

exit 0
