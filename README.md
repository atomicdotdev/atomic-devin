# atomic-devin

[Atomic VCS](https://atomic.dev) integration for [Devin Desktop](https://devin.ai) (Cascade).

Automatic turn recording with AI provenance, intent tracking, and knowledge graph skills.

## What it does

- **1 session = 1 view** — a draft view is created automatically when Cascade starts
- **Every turn records with provenance** — model, vendor, session, turn number, timing
- **Tool executions tracked** — file reads, writes, command runs captured in a causal decision graph
- **Intent workflow** — AGENTS.md prompt guides problem-first development with vault intents
- **Skills on demand** — `@atomic-vault`, `@atomic-vcs`, and `@code-intelligence` loaded when needed

## Install

### Quick start

```bash
# Clone and install
git clone https://github.com/atomicdotdev/atomic-devin
cd atomic-devin
./install.sh

# Copy the agent prompt into your project
cp AGENTS.md /path/to/your/project/
```

### From npm (once published)

```bash
npx atomic-devin
```

### What install does

1. **Hooks** — writes Cascade hook configuration to `~/.codeium/windsurf/hooks.json` (or uses `atomic agent enable --hooks` if available). Hook scripts bridge Cascade's stdin-JSON hooks to `atomic agent hooks devin <verb>`.
2. **Skills** — symlinks `@atomic-vault`, `@atomic-vcs`, `@code-intelligence`, `@codebase-context`, `@intent-builder` into `~/.codeium/windsurf/skills/`
3. **AGENTS.md** — must be copied to each project root manually (Devin Desktop auto-discovers it)

## Prerequisites

- [Atomic VCS](https://atomic.dev) installed and on your PATH (`atomic --version`)
- A project with an `.atomic/` repository (`atomic init`)
- [Devin Desktop](https://devin.ai) installed

## Usage

```bash
cd my-project
atomic init              # if not already an atomic repo
cp /path/to/atomic-devin/AGENTS.md .  # copy agent prompt
# Open Devin Desktop — hooks activate automatically
```

The hooks automatically:

1. Create a draft view when the session starts
2. Track your prompt and model info
3. Record tool executions in a provenance graph
4. Record changes with full AI attestation when a turn ends

You never need to run `atomic add` or `atomic record` — the hooks handle it.

## Viewing provenance

```bash
# Show the causal decision graph (goals → tool calls → patch)
atomic change -p <hash>

# Show inline AI attestation (model, tokens, cost)
atomic change -a <hash>

# Show session-level attestations
atomic agent attest
```

## What's in the package

| File | Purpose |
|------|---------|
| `AGENTS.md` | Agent prompt — copy to project roots for intent-per-turn workflow |
| `skills/atomic-vault/SKILL.md` | Vault reference (`@atomic-vault` skill) |
| `skills/atomic-vcs/SKILL.md` | Inspect state & history: `status`, `log`, `change -p`/`-a`, `diff` (`@atomic-vcs` skill) |
| `skills/code-intelligence/SKILL.md` | Knowledge graph query patterns (`@code-intelligence` skill) |
| `skills/codebase-context/SKILL.md` | Codebase exploration with KG (`@codebase-context` skill) |
| `skills/intent-builder/SKILL.md` | Intent creation workflow (`@intent-builder` skill) |
| `hooks/scripts/*.sh` | Hook bridge scripts — translate Cascade JSON to `atomic agent hooks devin` |
| `install.js` | Installs hooks + symlinks skills into `~/.codeium/windsurf/` |
| `install.sh` | Development install |

## How hooks work

Devin Desktop (Cascade) has a hook system that executes shell commands at key workflow points, passing JSON context via stdin. This package ships bridge scripts that translate Cascade's hook events into `atomic agent hooks devin <verb>` calls:

```
Cascade session start
  │
  ├── User sends prompt
  │   ├── Hook fires pre_user_prompt → script creates draft view (first time)
  │   │                               → script tracks prompt + model on session
  │   ├── Agent works (edits, commands)
  │   │   ├── Hook fires post_write_code → script tracks file edit in provenance
  │   │   └── Hook fires post_run_command → script tracks command in provenance
  │   └── Turn ends
  │       └── Hook fires post_cascade_response → script adds files, records with provenance
  │
  ├── User sends another prompt → repeat
  │
  └── Session ends
      └── Session cleanup creates attestation
```

### Hook event mapping

| Cascade Hook | Atomic Verb | Purpose |
|-------------|-------------|---------|
| `pre_user_prompt` | `session-start` (first) / `prompt-submit` | Create view, track prompts |
| `post_cascade_response` | `stop` | Record changes with provenance |
| `post_write_code` | `post-tool` | Track file edits |
| `post_run_command` | `post-tool` | Track command executions |

## Uninstall

```bash
npx atomic-devin --uninstall
```

Or manually:

```bash
node install.js --uninstall
rm ~/.codeium/windsurf/skills/atomic-vault/SKILL.md
rm ~/.codeium/windsurf/skills/atomic-vcs/SKILL.md
rm ~/.codeium/windsurf/skills/code-intelligence/SKILL.md
rm ~/.codeium/windsurf/skills/codebase-context/SKILL.md
rm ~/.codeium/windsurf/skills/intent-builder/SKILL.md
```

AGENTS.md files in project roots must be removed manually.

## License

Apache-2.0 — same as [Atomic VCS](https://github.com/atomicdotdev/atomic).
