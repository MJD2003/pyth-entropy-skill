#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const readline = require("readline");

const HOME = os.homedir();
const SKILL_ROOT = path.resolve(__dirname, "..");

// ─── IDE paths (global skill directories) ───────────────

const IDE_PATHS = {
  windsurf: path.join(HOME, ".codeium", "windsurf", "skills", "pyth-entropy"),
  cursor_global: path.join(HOME, ".cursor", "rules"),
  claude: path.join(HOME, ".claude", "skills", "pyth-entropy"),
};

// ─── Helpers ────────────────────────────────────────────

function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return;
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const child of fs.readdirSync(src)) {
      copyRecursive(path.join(src, child), path.join(dest, child));
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

function fileCount(dir) {
  if (!fs.existsSync(dir)) return 0;
  let count = 0;
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    count += item.isDirectory()
      ? fileCount(path.join(dir, item.name))
      : 1;
  }
  return count;
}

function green(s) { return `\x1b[32m${s}\x1b[0m`; }
function cyan(s) { return `\x1b[36m${s}\x1b[0m`; }
function yellow(s) { return `\x1b[33m${s}\x1b[0m`; }
function bold(s) { return `\x1b[1m${s}\x1b[0m`; }
function dim(s) { return `\x1b[2m${s}\x1b[0m`; }

// ─── Install functions ──────────────────────────────────

function installWindsurf() {
  const dest = IDE_PATHS.windsurf;
  console.log(`  Installing to ${dim(dest)}`);

  if (fs.existsSync(dest)) {
    fs.rmSync(dest, { recursive: true, force: true });
  }

  // Copy full skill: SKILL.md, references/, assets/, scripts/
  copyRecursive(path.join(SKILL_ROOT, "references"), path.join(dest, "references"));
  copyRecursive(path.join(SKILL_ROOT, "assets"), path.join(dest, "assets"));
  copyRecursive(path.join(SKILL_ROOT, "scripts"), path.join(dest, "scripts"));
  fs.copyFileSync(path.join(SKILL_ROOT, "SKILL.md"), path.join(dest, "SKILL.md"));

  // Also copy .windsurfrules for workspace-level use
  fs.copyFileSync(
    path.join(SKILL_ROOT, ".windsurfrules"),
    path.join(dest, ".windsurfrules")
  );

  const count = fileCount(dest);
  console.log(green(`  Done — ${count} files installed`));
  console.log(`  Windsurf auto-discovers it from SKILL.md. No per-project setup needed.`);
  console.log(`  ${dim('Trigger: just say "add Pyth Entropy" in any project')}`);
}

function installCursor() {
  const globalRules = IDE_PATHS.cursor_global;
  console.log(`  Installing global rule to ${dim(globalRules)}`);

  fs.mkdirSync(globalRules, { recursive: true });
  fs.copyFileSync(
    path.join(SKILL_ROOT, ".cursor", "rules", "pyth-entropy.md"),
    path.join(globalRules, "pyth-entropy.md")
  );

  console.log(green(`  Done — rule installed globally`));
  console.log(`  Cursor loads it automatically when you work on .sol, .ts, or .py files.`);
  console.log(`  ${dim('Trigger: mention "Entropy" or "on-chain randomness" in any project')}`);
}

function installClaude() {
  const dest = IDE_PATHS.claude;
  console.log(`  Installing to ${dim(dest)}`);

  if (fs.existsSync(dest)) {
    fs.rmSync(dest, { recursive: true, force: true });
  }

  // Copy full skill
  copyRecursive(path.join(SKILL_ROOT, "references"), path.join(dest, "references"));
  copyRecursive(path.join(SKILL_ROOT, "assets"), path.join(dest, "assets"));
  copyRecursive(path.join(SKILL_ROOT, "scripts"), path.join(dest, "scripts"));
  fs.copyFileSync(path.join(SKILL_ROOT, "SKILL.md"), path.join(dest, "SKILL.md"));

  // Copy CLAUDE.md and commands to the global .claude directory
  const claudeRoot = path.join(HOME, ".claude");
  const claudeMd = path.join(claudeRoot, "CLAUDE.md");

  // Append to existing CLAUDE.md or create new
  const entropyBlock = fs.readFileSync(
    path.join(SKILL_ROOT, ".claude", "CLAUDE.md"),
    "utf-8"
  );

  if (fs.existsSync(claudeMd)) {
    const existing = fs.readFileSync(claudeMd, "utf-8");
    if (!existing.includes("Pyth Entropy")) {
      fs.appendFileSync(claudeMd, "\n\n" + entropyBlock);
      console.log(`  Appended Entropy section to existing ${dim(claudeMd)}`);
    }
  }

  // Copy slash command
  const cmdDir = path.join(claudeRoot, "commands");
  fs.mkdirSync(cmdDir, { recursive: true });
  fs.copyFileSync(
    path.join(SKILL_ROOT, ".claude", "commands", "entropy.md"),
    path.join(cmdDir, "entropy.md")
  );

  const count = fileCount(dest);
  console.log(green(`  Done — ${count} files + /entropy command installed`));
  console.log(`  Use ${bold("/entropy")} in Claude Code to trigger the full integration flow.`);
  console.log(`  ${dim('Or just say "add Pyth Entropy" in any conversation')}`);
}

function installCopilot(projectDir) {
  const dest = path.join(projectDir, ".github");
  fs.mkdirSync(dest, { recursive: true });
  fs.copyFileSync(
    path.join(SKILL_ROOT, ".github", "copilot-instructions.md"),
    path.join(dest, "copilot-instructions.md")
  );
  console.log(green(`  Done — copied to ${dest}/copilot-instructions.md`));
}

function installCline(projectDir) {
  fs.copyFileSync(
    path.join(SKILL_ROOT, ".clinerules"),
    path.join(projectDir, ".clinerules")
  );
  console.log(green(`  Done — copied .clinerules to project root`));
}

// ─── Status check ───────────────────────────────────────

function showStatus() {
  console.log("");
  console.log(bold("  Installed skill locations:"));
  console.log("");

  for (const [ide, p] of Object.entries(IDE_PATHS)) {
    const exists = fs.existsSync(p);
    const label = ide.replace("_", " ").replace(/^\w/, (c) => c.toUpperCase());
    if (exists) {
      const count = fileCount(p);
      console.log(`  ${green("●")} ${label.padEnd(16)} ${dim(p)} ${dim(`(${count} files)`)}`);
    } else {
      console.log(`  ${dim("○")} ${label.padEnd(16)} ${dim("not installed")}`);
    }
  }
  console.log("");
}

// ─── Uninstall ──────────────────────────────────────────

function uninstall(ide) {
  const p = IDE_PATHS[ide];
  if (!p) {
    console.log(yellow(`  Unknown IDE: ${ide}`));
    return;
  }
  if (fs.existsSync(p)) {
    fs.rmSync(p, { recursive: true, force: true });
    console.log(green(`  Removed ${p}`));
  } else {
    console.log(dim(`  Nothing to remove for ${ide}`));
  }
}

// ─── Interactive prompt ─────────────────────────────────

function ask(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// ─── Main ───────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || "";

  console.log("");
  console.log(bold("  Pyth Entropy Skill"));
  console.log(dim("  On-chain randomness for AI-powered IDEs"));
  console.log("");

  if (command === "install" || command === "i") {
    const target = args[1] || "";

    if (target === "windsurf" || target === "all") {
      console.log(cyan("  Windsurf / Cascade"));
      installWindsurf();
      console.log("");
    }
    if (target === "cursor" || target === "all") {
      console.log(cyan("  Cursor"));
      installCursor();
      console.log("");
    }
    if (target === "claude" || target === "all") {
      console.log(cyan("  Claude Code"));
      installClaude();
      console.log("");
    }
    if (target === "copilot") {
      const dir = args[2] || process.cwd();
      console.log(cyan("  GitHub Copilot"));
      installCopilot(dir);
      console.log("");
    }
    if (target === "cline") {
      const dir = args[2] || process.cwd();
      console.log(cyan("  Cline / Roo"));
      installCline(dir);
      console.log("");
    }

    if (!target) {
      // Interactive mode
      console.log("  Which IDEs? (comma-separated, or 'all')");
      console.log("");
      console.log("    windsurf  — global skill, always available");
      console.log("    cursor    — global rule, activates on .sol/.ts/.py files");
      console.log("    claude    — global skill + /entropy command");
      console.log("    all       — install everywhere");
      console.log("");
      const answer = await ask("  > ");
      const choices = answer.toLowerCase().split(",").map((s) => s.trim());

      if (choices.includes("all")) {
        choices.length = 0;
        choices.push("windsurf", "cursor", "claude");
      }

      console.log("");
      for (const c of choices) {
        if (c === "windsurf") { console.log(cyan("  Windsurf")); installWindsurf(); console.log(""); }
        if (c === "cursor") { console.log(cyan("  Cursor")); installCursor(); console.log(""); }
        if (c === "claude") { console.log(cyan("  Claude Code")); installClaude(); console.log(""); }
      }
    }

    showStatus();
    console.log("  You're set. Open any project and ask your AI to add Entropy.");
    console.log("");

  } else if (command === "status" || command === "s") {
    showStatus();

  } else if (command === "uninstall" || command === "remove") {
    const target = args[1] || "all";
    if (target === "all") {
      for (const ide of Object.keys(IDE_PATHS)) uninstall(ide);
    } else {
      uninstall(target);
    }

  } else {
    // Help
    console.log("  Usage:");
    console.log("");
    console.log(`    ${bold("npx pyth-entropy-skill install")} [target]`);
    console.log("");
    console.log("    Targets:");
    console.log("      all        Install for Windsurf + Cursor + Claude Code");
    console.log("      windsurf   Global skill (always available in all projects)");
    console.log("      cursor     Global rule (activates on Solidity/TS/Python files)");
    console.log("      claude     Global skill + /entropy slash command");
    console.log("      copilot    Per-project .github/copilot-instructions.md");
    console.log("      cline      Per-project .clinerules");
    console.log("      (none)     Interactive picker");
    console.log("");
    console.log(`    ${bold("npx pyth-entropy-skill status")}`);
    console.log("      Show what's installed where");
    console.log("");
    console.log(`    ${bold("npx pyth-entropy-skill uninstall")} [target]`);
    console.log("      Remove installed skill files");
    console.log("");
    console.log("  After installing, the skill is permanent. No per-project setup.");
    console.log('  Just open any project and say "add Pyth Entropy to my project".');
    console.log("");
  }
}

main().catch(console.error);
