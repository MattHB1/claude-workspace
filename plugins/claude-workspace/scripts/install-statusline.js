#!/usr/bin/env node
'use strict';

// install-statusline.js — Opt-in installer for the claude-workspace statusline.
//
// Usage:  node plugins/claude-workspace/scripts/install-statusline.js
//
// What it does:
//   1. Preflights node availability (required by the statusLine command).
//   2. Locates ~/.claude/settings.json; if missing, treats settings as {}.
//   3. Never-clobber: if statusLine already exists, never modifies settings.json.
//      - If it references our script → already installed (no-op).
//      - If it references something else → prints the --segment snippet + docs pointer.
//   4. Fresh-wire: if no statusLine key exists:
//      - Copies statusline.js to ~/.claude/claude-workspace-statusline.js.
//      - Backs up existing settings.json (if any) to settings.json.bak.
//      - Adds statusLine key with forward-slash command.
//      - Writes atomically (temp file + rename).
//      - Prints what it did and how to undo.
//
// Node stdlib only. No npm dependencies. child_process is used solely for the
// node preflight check (to mirror the runtime environment of the statusLine command).

const fs   = require('fs');
const path = require('path');
const os   = require('os');
const cp   = require('child_process');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Build the stable home path using forward slashes on all OSes (C7).
function forwardSlashHome() {
  return os.homedir().replace(/\\/g, '/');
}

function stableScriptPath() {
  return path.join(os.homedir(), '.claude', 'claude-workspace-statusline.js');
}

function settingsPath() {
  return path.join(os.homedir(), '.claude', 'settings.json');
}

function settingsDir() {
  return path.join(os.homedir(), '.claude');
}

// The command string written into settings.json — forward slashes everywhere.
function statusLineCommand() {
  const homeFs = forwardSlashHome();
  return `node "${homeFs}/.claude/claude-workspace-statusline.js"`;
}

// The --segment snippet shown when a foreign statusLine exists.
function segmentSnippet() {
  const homeFs = forwardSlashHome();
  return `node "${homeFs}/.claude/claude-workspace-statusline.js" --segment`;
}

// ---------------------------------------------------------------------------
// C5a — Node preflight
// ---------------------------------------------------------------------------

// Synchronously verify that `node` is resolvable/runnable in the current
// PATH environment (the same PATH the statusLine command will use).
// Returns true if node is available, false otherwise.
function nodeIsAvailable() {
  try {
    const result = cp.spawnSync('node', ['--version'], {
      encoding: 'utf8',
      timeout: 5000,
      // Do not inherit env — use process.env so we honour the actual PATH.
    });
    // spawnSync returns status=null on spawn failure (ENOENT etc.)
    return result.status === 0;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Settings read
// ---------------------------------------------------------------------------

function readSettings() {
  const p = settingsPath();
  try {
    const raw = fs.readFileSync(p, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    if (e.code === 'ENOENT') return null; // file missing
    if (e instanceof SyntaxError) {
      // Unreadable JSON — treat as empty to avoid corrupting, but warn.
      process.stderr.write(
        `[install-statusline] Warning: ${p} exists but is not valid JSON; treating as empty.\n`
      );
      return {};
    }
    throw e; // unexpected I/O error
  }
}

// ---------------------------------------------------------------------------
// Atomic write
// ---------------------------------------------------------------------------

function writeSettingsAtomic(settings) {
  const target = settingsPath();
  const dir    = settingsDir();
  const tmp    = target + '.tmp.' + process.pid;

  // Ensure ~/.claude/ exists.
  fs.mkdirSync(dir, { recursive: true });

  const json = JSON.stringify(settings, null, 2) + '\n';

  try {
    fs.writeFileSync(tmp, json, 'utf8');
    fs.renameSync(tmp, target);
  } catch (err) {
    // Clean up temp if it exists, then rethrow — do NOT leave a partial file
    // at the target path.
    try { fs.unlinkSync(tmp); } catch (_) {}
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Backup
// ---------------------------------------------------------------------------

function backupSettings() {
  const src = settingsPath();
  const bak = src + '.bak';
  try {
    fs.copyFileSync(src, bak);
    return bak;
  } catch (e) {
    if (e.code === 'ENOENT') return null; // nothing to back up
    throw e;
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  // 1. Node preflight (C5a).
  if (!nodeIsAvailable()) {
    process.stdout.write(
      'Node not found on PATH; statusline not installed; install Node or wire it manually — see docs/statusline.md\n' +
      '\n' +
      'Manual --segment snippet (paste into your own statusLine command):\n' +
      '  ' + segmentSnippet() + '\n' +
      '\n' +
      'See: plugins/claude-workspace/docs/statusline.md\n'
    );
    process.exit(0);
    return;
  }

  // 2. Read settings.
  const existing = readSettings(); // null → file missing; {} → empty/invalid

  // 3. Never-clobber check (C3 / I2 / AC6 / AC9).
  if (existing !== null && Object.prototype.hasOwnProperty.call(existing, 'statusLine')) {
    const sl = existing.statusLine;
    const cmd = (sl && typeof sl.command === 'string') ? sl.command : '';

    if (cmd.includes('claude-workspace-statusline')) {
      // OUR statusline is already wired — idempotent no-op.
      process.stdout.write(
        '[claude-workspace] statusline already installed — nothing to do.\n' +
        '\n' +
        'To uninstall:\n' +
        '  1. Remove the "statusLine" key from ' + settingsPath() + '\n' +
        '     (restore from ' + settingsPath() + '.bak if you have one)\n' +
        '  2. Delete ' + stableScriptPath() + '\n'
      );
      process.exit(0);
      return;
    }

    // FOREIGN statusLine — do NOT touch settings.json (C3).
    process.stdout.write(
      '[claude-workspace] A statusLine is already configured in settings.json.\n' +
      'The installer will NOT overwrite it.\n' +
      '\n' +
      'To add the claude-workspace active-initiative segment to your existing statusline,\n' +
      'pipe the session JSON through our script in --segment mode:\n' +
      '\n' +
      '  ' + segmentSnippet() + '\n' +
      '\n' +
      'Example — append our segment to your own line:\n' +
      '  <your-command> | node "' + forwardSlashHome() + '/.claude/claude-workspace-statusline.js" --segment\n' +
      '\n' +
      'You will need to copy the script to the stable path first:\n' +
      '  cp "' + path.join(__dirname, 'statusline.js') + '" "' + stableScriptPath() + '"\n' +
      '\n' +
      'See docs/statusline.md for full details:\n' +
      '  plugins/claude-workspace/docs/statusline.md\n'
    );
    process.exit(0);
    return;
  }

  // 4. Fresh-wire (AC8 / AC10 / AC11 / AC12 / C4 / C5 / C7).

  // 4a. Copy statusline.js to the stable path.
  const srcScript  = path.join(__dirname, 'statusline.js');
  const destScript = stableScriptPath();

  try {
    fs.mkdirSync(settingsDir(), { recursive: true });
    fs.copyFileSync(srcScript, destScript);
  } catch (err) {
    process.stdout.write(
      '[claude-workspace] ERROR: could not copy statusline.js to stable path:\n' +
      '  ' + destScript + '\n' +
      '  ' + err.message + '\n' +
      'settings.json was NOT modified.\n'
    );
    process.exit(1);
    return;
  }

  // 4b. Back up existing settings.json (if any).
  let backedUpTo = null;
  if (existing !== null) {
    try {
      backedUpTo = backupSettings();
    } catch (err) {
      process.stdout.write(
        '[claude-workspace] ERROR: could not create backup of settings.json:\n' +
        '  ' + err.message + '\n' +
        'settings.json was NOT modified.\n'
      );
      process.exit(1);
      return;
    }
  }

  // 4c. Merge settings — additive: only add/replace statusLine key.
  const updated = Object.assign({}, existing || {}, {
    statusLine: {
      type: 'command',
      command: statusLineCommand(),
    },
  });

  // 4d. Atomic write.
  try {
    writeSettingsAtomic(updated);
  } catch (err) {
    process.stdout.write(
      '[claude-workspace] ERROR: could not write settings.json:\n' +
      '  ' + err.message + '\n' +
      'The original settings.json is intact' +
      (backedUpTo ? ' (backup at ' + backedUpTo + ')' : '') + '.\n'
    );
    process.exit(1);
    return;
  }

  // 4e. Success output.
  process.stdout.write(
    '[claude-workspace] statusline installed successfully.\n' +
    '\n' +
    'Script copied to:\n' +
    '  ' + destScript + '\n' +
    '\n' +
    'settings.json updated:\n' +
    '  ' + settingsPath() + '\n' +
    (backedUpTo ? '  (backup: ' + backedUpTo + ')\n' : '') +
    '\n' +
    'The statusLine command is:\n' +
    '  ' + statusLineCommand() + '\n' +
    '\n' +
    'To uninstall:\n' +
    '  1. Remove the "statusLine" key from ' + settingsPath() + '\n' +
    (backedUpTo ? '     (restore from ' + backedUpTo + ' if needed)\n' : '') +
    '  2. Delete ' + destScript + '\n' +
    '\n' +
    'See docs/statusline.md for more:\n' +
    '  plugins/claude-workspace/docs/statusline.md\n'
  );
  process.exit(0);
}

main();
