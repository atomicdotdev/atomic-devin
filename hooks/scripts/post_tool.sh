#!/bin/bash
# post_tool.sh — Handles post_write_code and post_run_command hooks for Devin/Cascade
# Tracks tool executions in the provenance decision graph.
set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)

# Only run inside an Atomic repository
[ -d .atomic ] || exit 0

SESSION_FILE=".atomic/devin_session"
[ -f "$SESSION_FILE" ] || exit 0

SESSION_ID=$(cat "$SESSION_FILE")
ACTION=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_action_name',''))" 2>/dev/null || echo "")
TRAJECTORY_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('trajectory_id',''))" 2>/dev/null || echo "")

# Extract tool-specific info
case "$ACTION" in
  post_write_code)
    FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_info',{}).get('file_path',''))" 2>/dev/null || echo "")
    printf '{"session_id":"%s","cwd":"%s","action":"write","file":"%s","trajectory_id":"%s"}' \
      "$SESSION_ID" "$(pwd)" "$FILE_PATH" "$TRAJECTORY_ID" \
      | atomic agent hooks devin post-tool 2>/dev/null || true
    ;;
  post_run_command)
    COMMAND_LINE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_info',{}).get('command_line',''))" 2>/dev/null || echo "")
    printf '{"session_id":"%s","cwd":"%s","action":"command","command":"%s","trajectory_id":"%s"}' \
      "$SESSION_ID" "$(pwd)" "$(echo "$COMMAND_LINE" | head -c 200)" "$TRAJECTORY_ID" \
      | atomic agent hooks devin post-tool 2>/dev/null || true
    ;;
  *)
    # Generic tool tracking
    printf '{"session_id":"%s","cwd":"%s","action":"%s","trajectory_id":"%s"}' \
      "$SESSION_ID" "$(pwd)" "$ACTION" "$TRAJECTORY_ID" \
      | atomic agent hooks devin post-tool 2>/dev/null || true
    ;;
esac

exit 0
