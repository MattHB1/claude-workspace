#!/usr/bin/env node
'use strict';

// install-statusline.js — Takeover + delegate installer for the
// claude-workspace statusline.
//
// Usage:
//   node plugins/claude-workspace/scripts/install-statusline.js
//   node plugins/claude-workspace/scripts/install-statusline.js --uninstall
//
// What it does (install):
//   1. Preflights node availability (required by the statusLine command).
//   2. Locates ~/.claude/settings.json; if missing, treats settings as {}.
//   3. Idempotent no-op: if our own statusLine is already wired, does nothing.
//   4. Takeover + delegate: if a FOREIGN statusLine command exists (one this
//      installer did not author), CAPTURES it verbatim into a sidecar file
//      (~/.claude/.claude-workspace-statusline-prior.json) BEFORE rewiring —
//      never destroying it. The sole-slot script (statusline.js) reads that
//      sidecar at render time and, when no session marker is present,
//      re-invokes the captured command with the same stdin and emits its
//      output verbatim — restoring the user's prior/default statusline
//      automatically.
//   5. Wires the workspace script as the SOLE statusLine (stable-path copy),
//      backing up settings.json first and writing atomically (temp+rename).
//
// What it does (--uninstall):
//   Restores the captured prior statusLine command byte-for-byte (or removes
//   the statusLine key entirely if none was captured), leaving all other
//   settings.json keys intact. Backs up settings.json first; writes
//   atomically. Removes the prior-capture sidecar once restored.
//
// Node stdlib only. No npm dependencies. child_process is used solely for the
// node preflight check (to mirror the runtime environment of the statusLine
// command).

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

// Sidecar carrying the captured prior statusLine value (verbatim), read at
// render time by the installed statusline.js to delegate when inactive
// (C3/INV3/AC3/AC10). Deterministic path, PII-safe (only ever contains
// whatever the user's own pre-existing statusLine.command string already
// was).
function priorCapturePath() {
  return path.join(os.homedir(), '.claude', '.claude-workspace-statusline-prior.json');
}

// The command string written into settings.json — forward slashes everywhere.
function statusLineCommand() {
  const homeFs = forwardSlashHome();
  return `node "${homeFs}/.claude/claude-workspace-statusline.js"`;
}

// The --segment snippet shown as a developer/compose affordance in output.
function segmentSnippet() {
  const homeFs = forwardSlashHome();
  return `node "${homeFs}/.claude/claude-workspace-statusline.js" --segment`;
}

// Is the given statusLine command string one this installer authored?
function isOurCommand(cmd) {
  return typeof cmd === 'string' && cmd.includes('claude-workspace-statusline');
}

// ---------------------------------------------------------------------------
// Node preflight
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
// Prior-capture sidecar read/write
// ---------------------------------------------------------------------------

// Read the captured prior statusLine value, if any. Returns the parsed
// object or null on any absence/parse error.
function readPriorCapture() {
  try {
    const raw = fs.readFileSync(priorCapturePath(), 'utf8');
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

// Write the captured prior statusLine value verbatim to the sidecar. Uses the
// same temp+rename atomic pattern as settings.json writes.
function writePriorCaptureAtomic(statusLineValue) {
  const target = priorCapturePath();
  const dir    = settingsDir();
  const tmp    = target + '.tmp.' + process.pid;

  fs.mkdirSync(dir, { recursive: true });
  const json = JSON.stringify(statusLineValue, null, 2) + '\n';

  try {
    fs.writeFileSync(tmp, json, 'utf8');
    fs.renameSync(tmp, target);
  } catch (err) {
    try { fs.unlinkSync(tmp); } catch (_) {}
    throw err;
  }
}

function removePriorCapture() {
  try {
    fs.unlinkSync(priorCapturePath());
  } catch (_) {
    // absent or unremovable — non-fatal for the caller's purposes.
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
// Install
// ---------------------------------------------------------------------------

function runInstall() {
  // 1. Node preflight.
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
  const existingHasStatusLine = existing !== null &&
    Object.prototype.hasOwnProperty.call(existing, 'statusLine');
  const existingCmd = existingHasStatusLine &&
    existing.statusLine && typeof existing.statusLine.command === 'string'
    ? existing.statusLine.command
    : '';

  // 3. Idempotent no-op: our own statusLine is already the sole slot AND a
  //    prior-capture decision has already been made (either a sidecar exists
  //    from an earlier takeover, or there is nothing to capture). Re-running
  //    must not duplicate or re-wrap anything (AC13).
  if (existingHasStatusLine && isOurCommand(existingCmd)) {
    const prior = readPriorCapture();
    process.stdout.write(
      '[claude-workspace] statusline already installed — nothing to do.\n' +
      (prior
        ? '  A prior statusline is captured and will be restored automatically\n' +
          '  outside workspace sessions, and on uninstall.\n'
        : '  No prior statusline was captured (none existed at install time).\n') +
      '\n' +
      'To uninstall:\n' +
      '  node ' + __filename + ' --uninstall\n'
    );
    process.exit(0);
    return;
  }

  // 4. Takeover + delegate (C3/INV3/AC10): if a FOREIGN statusLine exists
  //    (one we did not author), capture it verbatim into the sidecar BEFORE
  //    rewiring. If no statusLine exists, there is nothing to capture.
  let capturedNote = '';
  if (existingHasStatusLine) {
    try {
      writePriorCaptureAtomic(existing.statusLine);
      capturedNote =
        'Your existing statusline was captured and will be restored automatically\n' +
        'outside workspace sessions (and on uninstall):\n' +
        '  ' + JSON.stringify(existing.statusLine) + '\n' +
        '  (captured to ' + priorCapturePath() + ')\n';
    } catch (err) {
      process.stdout.write(
        '[claude-workspace] ERROR: could not capture existing statusLine:\n' +
        '  ' + err.message + '\n' +
        'settings.json was NOT modified.\n'
      );
      process.exit(1);
      return;
    }
  }

  // 5. Copy statusline.js to the stable path.
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

  // 6. Back up existing settings.json (if any).
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

  // 7. Sole-slot wire — additive to all other keys; the statusLine key is
  //    replaced with ours (the prior value, if any, is already captured).
  const updated = Object.assign({}, existing || {}, {
    statusLine: {
      type: 'command',
      command: statusLineCommand(),
    },
  });

  // 8. Atomic write.
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

  // 9. Success output.
  process.stdout.write(
    '[claude-workspace] statusline installed successfully (takeover + delegate).\n' +
    '\n' +
    'Script copied to:\n' +
    '  ' + destScript + '\n' +
    '\n' +
    'settings.json updated:\n' +
    '  ' + settingsPath() + '\n' +
    (backedUpTo ? '  (backup: ' + backedUpTo + ')\n' : '') +
    '\n' +
    (capturedNote ? capturedNote + '\n' : '') +
    'The statusLine command is:\n' +
    '  ' + statusLineCommand() + '\n' +
    '\n' +
    'In a workspace session the ⚡<slug> segment is shown; outside a workspace\n' +
    'session your prior/default statusline is restored automatically.\n' +
    '\n' +
    'To uninstall:\n' +
    '  node ' + __filename + ' --uninstall\n' +
    '\n' +
    'See docs/statusline.md for more:\n' +
    '  plugins/claude-workspace/docs/statusline.md\n'
  );
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Uninstall / revert
// ---------------------------------------------------------------------------

function runUninstall() {
  const existing = readSettings(); // null → file missing; {} → empty/invalid

  if (existing === null) {
    process.stdout.write(
      '[claude-workspace] No settings.json found — nothing to uninstall.\n'
    );
    process.exit(0);
    return;
  }

  const prior = readPriorCapture();

  // Back up before any write.
  let backedUpTo = null;
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

  // Build the restored settings: replace/remove the statusLine key only,
  // leaving every other key byte-identical.
  const updated = Object.assign({}, existing);
  if (prior) {
    updated.statusLine = prior; // restore captured value byte-for-byte
  } else {
    delete updated.statusLine; // nothing pre-existed — remove the key
  }

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

  // Clean up the prior-capture sidecar and the stable script copy — the
  // takeover is fully removed.
  removePriorCapture();
  try { fs.unlinkSync(stableScriptPath()); } catch (_) {}

  process.stdout.write(
    '[claude-workspace] statusline uninstalled — prior statusLine restored.\n' +
    '\n' +
    'settings.json updated:\n' +
    '  ' + settingsPath() + '\n' +
    (backedUpTo ? '  (backup: ' + backedUpTo + ')\n' : '') +
    '\n' +
    (prior
      ? 'Restored statusLine (byte-for-byte the captured prior value):\n' +
        '  ' + JSON.stringify(prior) + '\n'
      : 'No prior statusLine existed before install — the statusLine key was removed.\n')
  );
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const uninstall = process.argv.includes('--uninstall');
  if (uninstall) {
    runUninstall();
  } else {
    runInstall();
  }
}

main();
