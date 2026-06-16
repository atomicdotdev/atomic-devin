#!/usr/bin/env node

/**
 * atomic-devin install
 *
 * Installs Atomic hooks into ~/.codeium/windsurf/hooks.json
 * and symlinks skills into ~/.codeium/windsurf/skills/.
 *
 * Usage:
 *   npx atomic-devin          # install from npm
 *   node install.js            # install from local checkout
 *   node install.js --silent   # postinstall (no output on success)
 *   node install.js --uninstall  # remove hooks and skill symlinks
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const silent = process.argv.includes("--silent");
const uninstall = process.argv.includes("--uninstall");

const PKG_DIR = __dirname;
const DEVIN_CONFIG_DIR = path.join(os.homedir(), ".codeium", "windsurf");
const SKILLS_TARGET = path.join(DEVIN_CONFIG_DIR, "skills");
const HOOKS_TARGET = path.join(DEVIN_CONFIG_DIR, "hooks.json");
const MANIFEST = path.join(PKG_DIR, "hooks", "devin.atomic-hooks.json");
const SCRIPTS_DIR = path.join(PKG_DIR, "hooks", "scripts");

const SKILL_LINKS = [
  {
    src: "skills/atomic-vault/SKILL.md",
    dst: "atomic-vault/SKILL.md",
  },
  {
    src: "skills/atomic-vcs/SKILL.md",
    dst: "atomic-vcs/SKILL.md",
  },
  {
    src: "skills/code-intelligence/SKILL.md",
    dst: "code-intelligence/SKILL.md",
  },
  {
    src: "skills/codebase-context/SKILL.md",
    dst: "codebase-context/SKILL.md",
  },
  {
    src: "skills/intent-builder/SKILL.md",
    dst: "intent-builder/SKILL.md",
  },
];

function ensureDir(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function isOurSymlink(dstPath) {
  try {
    if (!fs.lstatSync(dstPath).isSymbolicLink()) return false;
    const target = fs.readlinkSync(dstPath);
    return target.startsWith(PKG_DIR);
  } catch {
    return false;
  }
}

function tryExec(cmd) {
  try {
    execSync(cmd, { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

function generateHooksJson() {
  return JSON.stringify(
    {
      hooks: {
        pre_user_prompt: [
          {
            command: `test -d .atomic && bash ${SCRIPTS_DIR}/prompt_submit.sh || true`,
            show_output: false,
          },
        ],
        post_cascade_response: [
          {
            command: `test -d .atomic && bash ${SCRIPTS_DIR}/turn_end.sh || true`,
          },
        ],
        post_write_code: [
          {
            command: `test -d .atomic && bash ${SCRIPTS_DIR}/post_tool.sh || true`,
            show_output: false,
          },
        ],
        post_run_command: [
          {
            command: `test -d .atomic && bash ${SCRIPTS_DIR}/post_tool.sh || true`,
            show_output: false,
          },
        ],
      },
    },
    null,
    2,
  );
}

function mergeHooksJson(existingContent) {
  let existing;
  try {
    existing = JSON.parse(existingContent);
  } catch {
    existing = { hooks: {} };
  }

  if (!existing.hooks) existing.hooks = {};

  const atomicHooks = JSON.parse(generateHooksJson()).hooks;

  // Merge: add atomic hooks to each event, avoiding duplicates
  for (const [event, hooks] of Object.entries(atomicHooks)) {
    if (!existing.hooks[event]) {
      existing.hooks[event] = [];
    }

    for (const hook of hooks) {
      const isDuplicate = existing.hooks[event].some(
        (h) => h.command && h.command.includes("atomic") && h.command.includes(SCRIPTS_DIR),
      );
      if (!isDuplicate) {
        existing.hooks[event].push(hook);
      }
    }
  }

  return JSON.stringify(existing, null, 2);
}

function doInstall() {
  // Make hook scripts executable
  try {
    const scripts = fs.readdirSync(SCRIPTS_DIR).filter((f) => f.endsWith(".sh"));
    for (const script of scripts) {
      fs.chmodSync(path.join(SCRIPTS_DIR, script), 0o755);
    }
  } catch {
    // Ignore chmod errors on Windows
  }

  // 1. Register hooks — try atomic CLI first, fall back to direct config
  const hasAtomic = tryExec("atomic --version");
  let hooksInstalled = false;

  if (hasAtomic) {
    hooksInstalled = tryExec(`atomic agent enable --hooks "${MANIFEST}"`);
    if (!silent && hooksInstalled) {
      console.log("  hooks: registered via atomic agent enable --hooks → ~/.codeium/windsurf/hooks.json");
    }
  }

  if (!hooksInstalled) {
    // Direct install: write or merge hooks.json
    ensureDir(HOOKS_TARGET);

    let content;
    if (fs.existsSync(HOOKS_TARGET)) {
      const existing = fs.readFileSync(HOOKS_TARGET, "utf-8");
      content = mergeHooksJson(existing);
    } else {
      content = generateHooksJson();
    }

    fs.writeFileSync(HOOKS_TARGET, content);
    if (!silent) {
      console.log("  hooks: installed → ~/.codeium/windsurf/hooks.json");
    }
  }

  // 2. Symlink skills
  let linked = 0;
  let skipped = 0;

  for (const { src, dst } of SKILL_LINKS) {
    const srcPath = path.join(PKG_DIR, src);
    const dstPath = path.join(SKILLS_TARGET, dst);

    if (!fs.existsSync(srcPath)) {
      if (!silent) console.warn(`  skip: ${src} (not found in package)`);
      continue;
    }

    if (fs.existsSync(dstPath) && !isOurSymlink(dstPath)) {
      skipped++;
      if (!silent) console.log(`  keep: ${dst} (user file, not overwriting)`);
      continue;
    }

    if (fs.existsSync(dstPath) || isOurSymlink(dstPath)) {
      fs.unlinkSync(dstPath);
    }

    ensureDir(dstPath);
    fs.symlinkSync(srcPath, dstPath);
    linked++;
    if (!silent) console.log(`  link: skills/${dst}`);
  }

  if (!silent) {
    console.log();
    console.log(
      `✓ atomic-devin installed (${linked} skills linked, ${skipped} skipped)`,
    );
    console.log();
    console.log(
      "Copy AGENTS.md into your project root to enable the agent prompt:",
    );
    console.log(
      `  cp ${path.join(PKG_DIR, "AGENTS.md")} /path/to/your/project/`,
    );
    console.log();
  }
}

function doUninstall() {
  // 1. Remove hooks
  if (fs.existsSync(HOOKS_TARGET)) {
    try {
      const existing = JSON.parse(fs.readFileSync(HOOKS_TARGET, "utf-8"));
      if (existing.hooks) {
        for (const [event, hooks] of Object.entries(existing.hooks)) {
          existing.hooks[event] = hooks.filter(
            (h) => !(h.command && h.command.includes(SCRIPTS_DIR)),
          );
          if (existing.hooks[event].length === 0) {
            delete existing.hooks[event];
          }
        }
        if (Object.keys(existing.hooks).length === 0) {
          fs.unlinkSync(HOOKS_TARGET);
        } else {
          fs.writeFileSync(HOOKS_TARGET, JSON.stringify(existing, null, 2));
        }
      }
    } catch {
      // If we can't parse, leave it alone
    }
    if (!silent) console.log("  hooks: removed from ~/.codeium/windsurf/hooks.json");
  }

  // Also try atomic CLI
  const hasAtomic = tryExec("atomic --version");
  if (hasAtomic) {
    tryExec(`atomic agent disable --hooks "${MANIFEST}"`);
  }

  // 2. Remove skill symlinks
  let removed = 0;

  for (const { dst } of SKILL_LINKS) {
    const dstPath = path.join(SKILLS_TARGET, dst);

    if (isOurSymlink(dstPath)) {
      fs.unlinkSync(dstPath);
      removed++;
      if (!silent) console.log(`  unlink: skills/${dst}`);

      const dir = path.dirname(dstPath);
      try {
        fs.rmdirSync(dir);
      } catch {
        /* not empty */
      }
    }
  }

  if (!silent) {
    console.log();
    console.log(`✓ atomic-devin uninstalled (${removed} skills removed)`);
    console.log("  Note: AGENTS.md in project roots must be removed manually.");
  }
}

if (uninstall) {
  doUninstall();
} else {
  doInstall();
}
