#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/hooks/devin.atomic-hooks.json"
SCRIPTS_DIR="$SCRIPT_DIR/hooks/scripts"

HOOKS_STATUS="not installed"

# Make hook scripts executable
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

# 1. Register hooks — either via `atomic agent enable` (if it supports Devin)
#    or by writing the hooks.json directly to the Devin config directory.
if command -v atomic &>/dev/null; then
  echo "Installing hooks..."
  if atomic agent enable --hooks "$MANIFEST" 2>/dev/null; then
    HOOKS_STATUS="registered via atomic agent enable"
  else
    # Fallback: write hooks.json directly for Devin Desktop
    HOOKS_STATUS="installed via direct config"
    DEVIN_HOOKS_DIR="$HOME/.codeium/windsurf"
    mkdir -p "$DEVIN_HOOKS_DIR"
    DEVIN_HOOKS="$DEVIN_HOOKS_DIR/hooks.json"

    # Generate hooks.json with resolved script paths
    cat > "$DEVIN_HOOKS" <<HOOKEOF
{
  "hooks": {
    "pre_user_prompt": [
      {
        "command": "test -d .atomic && bash $SCRIPTS_DIR/prompt_submit.sh || true",
        "show_output": false
      }
    ],
    "post_cascade_response": [
      {
        "command": "test -d .atomic && bash $SCRIPTS_DIR/turn_end.sh || true"
      }
    ],
    "post_write_code": [
      {
        "command": "test -d .atomic && bash $SCRIPTS_DIR/post_tool.sh || true",
        "show_output": false
      }
    ],
    "post_run_command": [
      {
        "command": "test -d .atomic && bash $SCRIPTS_DIR/post_tool.sh || true",
        "show_output": false
      }
    ]
  }
}
HOOKEOF
  fi
else
  HOOKS_STATUS="SKIPPED — 'atomic' not on PATH"
  echo "Warning: 'atomic' not found on PATH. Install Atomic VCS first."
  echo "  Hooks will not be active until you run:"
  echo "    atomic agent enable --hooks \"$MANIFEST\""
fi

# 1b. Devin CLI lifecycle hooks → ~/.config/devin/config.json
#     The hooks above target Devin Desktop (Windsurf, ~/.codeium/windsurf).
#     The Devin *CLI* (`devin`, `devin -p`) reads hooks from the user config's
#     "hooks" key (or a project `.devin/hooks.v1.json`). Install them at the
#     user level so every project records turns via `atomic agent hooks devin`.
#     Events are Claude-style PascalCase; the CLI fires `Stop` per turn and
#     `SessionEnd` at the end (both drive a recorded change with provenance).
DEVIN_CLI_CONFIG="$HOME/.config/devin/config.json"
if command -v python3 &>/dev/null; then
  mkdir -p "$(dirname "$DEVIN_CLI_CONFIG")"
  if python3 - "$DEVIN_CLI_CONFIG" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        cfg = json.load(f)
except Exception:
    cfg = {}
def hook(verb):
    return {"matcher": "", "hooks": [{"type": "command",
            "command": f"test -d .atomic && atomic agent hooks devin {verb} || true"}]}
cfg["hooks"] = {
    "SessionStart":     [hook("session-start")],
    "UserPromptSubmit": [hook("prompt-submit")],
    "PostToolUse":      [hook("post-tool")],
    "Stop":             [hook("stop")],
    "SessionEnd":       [hook("session-end")],
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
  then
    echo "  cli hooks: installed → $DEVIN_CLI_CONFIG"
  else
    echo "  cli hooks: FAILED to update $DEVIN_CLI_CONFIG"
  fi
else
  echo "  cli hooks: SKIPPED (python3 not found)"
fi

# 2. Symlink skills into ~/.codeium/windsurf/skills/
SKILLS_TARGET="$HOME/.codeium/windsurf/skills"
mkdir -p "$SKILLS_TARGET"

skills_linked=0
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  mkdir -p "$SKILLS_TARGET/$name"
  if [ -f "$skill_dir/SKILL.md" ]; then
    ln -sf "$skill_dir/SKILL.md" "$SKILLS_TARGET/$name/SKILL.md"
    skills_linked=$((skills_linked + 1))
  fi
done

cat <<EOF

────────────────────────────────────────────────────────────
✓ Installed atomic-devin
────────────────────────────────────────────────────────────

What was installed:
  • Hooks      ${HOOKS_STATUS}
               → ~/.codeium/windsurf/hooks.json
               (hook scripts in ${SCRIPTS_DIR})
  • Skills     ${skills_linked} symlinked (always re-linked)
               → ~/.codeium/windsurf/skills/
               (@atomic-vault, @atomic-vcs, @code-intelligence, ...)

Symlinks point back into this checkout:
  ${SCRIPT_DIR}
Keep this directory in place; moving or deleting it breaks the links.

Manual steps to finish:
  1. Per project, copy the agent prompt to the repo root:
       cp "${SCRIPT_DIR}/AGENTS.md" /path/to/your/project/
  2. Ensure the project is an Atomic repo (one-time):
       cd /path/to/your/project && atomic init
  3. Open Devin Desktop in that project — hooks activate automatically.

Verify:
  • Hooks:  cat ~/.codeium/windsurf/hooks.json
  • Skills: ls ~/.codeium/windsurf/skills/

Uninstall:
  node install.js --uninstall
────────────────────────────────────────────────────────────
EOF
