#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');

// Read all of stdin synchronously.
// Uses fd 0 (cross-platform; works on macOS, Linux, and Windows).
function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (_) {
    return '';
  }
}

// Parse JSON safely; never throw.
function safeParse(raw) {
  if (!raw || !raw.trim()) return {};
  try {
    return JSON.parse(raw);
  } catch (_) {
    return {};
  }
}

// Replace the user's home dir prefix with '~' (cross-platform).
function shortenCwd(dir) {
  const home = os.homedir();
  if (dir === home) return '~';
  const sep = home.endsWith(path.sep) ? home : home + path.sep;
  if (dir.startsWith(sep)) return '~' + path.sep + dir.slice(sep.length);
  return dir;
}

// Resolve the current git branch for `dir`, or '' if not a repo / detached /
// on any error. Mirrors the prior bash statusline's `git -C <dir>
// --no-optional-locks symbolic-ref --short HEAD`. Never throws.
function gitBranch(dir) {
  try {
    const out = cp.spawnSync(
      'git',
      ['-C', dir, '--no-optional-locks', 'symbolic-ref', '--short', 'HEAD'],
      { encoding: 'utf8', timeout: 1000 }
    );
    if (out && out.status === 0 && typeof out.stdout === 'string') {
      return out.stdout.trim();
    }
  } catch (_) {}
  return '';
}

// Walk up from `startDir` looking for `.workspace/initiatives.md`.
// Returns the file path if found, or null.
function findInitiativesFile(startDir) {
  let current = startDir;
  while (true) {
    const candidate = path.join(current, '.workspace', 'initiatives.md');
    try {
      fs.accessSync(candidate, fs.constants.R_OK);
      return candidate;
    } catch (_) {
      // not found here; go up
    }
    const parent = path.dirname(current);
    if (parent === current) break; // reached filesystem root
    current = parent;
  }
  return null;
}

// Extract the ACTIVE slug from the initiatives.md content.
// Slug = first backtick-delimited cell of the row containing '**ACTIVE**'.
function extractActiveSlug(content) {
  const lines = content.split('\n');
  for (const line of lines) {
    // Whole-cell marker match: split on '|', trim each cell, exact-match
    // '**ACTIVE**'. A mention of the token inside another cell (e.g. a
    // description) no longer collides. D3: escaped pipes ('\|') inside a
    // cell are out of scope — such a cell simply won't equal '**ACTIVE**'
    // (fail-safe non-match, not a crash).
    const isActiveRow = line.split('|').some((cell) => cell.trim() === '**ACTIVE**');
    if (isActiveRow) {
      // Match first backticked cell: | `slug` |
      const m = line.match(/^\s*\|\s*`([^`]+)`/);
      if (m) return m[1];
    }
  }
  return null;
}

// Resolve the active initiative slug from cwd.
function resolveSlug(cwd) {
  const file = findInitiativesFile(cwd);
  if (!file) return null;
  try {
    const content = fs.readFileSync(file, 'utf8');
    return extractActiveSlug(content);
  } catch (_) {
    return null;
  }
}

// Determine whether the workspace-orchestrator session is "active" for the
// given session_id: a pure-existence marker file at
// ~/.claude/.workspace-active/<session_id>. Missing session_id, missing dir,
// or any read error all degrade to "inactive" — never an error.
function isSessionActive(sessionId) {
  if (!sessionId || typeof sessionId !== 'string') return false;
  try {
    const markerPath = path.join(os.homedir(), '.claude', '.workspace-active', sessionId);
    return fs.existsSync(markerPath);
  } catch (_) {
    return false;
  }
}

// ANSI helpers.
const CYAN    = '\x1b[36m';
const MAGENTA = '\x1b[35m';
const DIM     = '\x1b[2m';
const RESET   = '\x1b[0m';
const YELLOW  = '\x1b[33m';

// ---------------------------------------------------------------------------
// Takeover + delegate (C3/INV3) — installer-authored sidecar carrying the
// captured prior statusLine command, if the installer took over an existing
// slot. This file is written by install-statusline.js BEFORE it rewires the
// sole statusLine; it is deterministic, PII-safe (only ever contains whatever
// the user's own prior statusLine.command string already was), and read-only
// from this script's perspective.
// ---------------------------------------------------------------------------
function priorStatuslinePath() {
  return path.join(os.homedir(), '.claude', '.claude-workspace-statusline-prior.json');
}

// Read the captured prior statusLine command (verbatim), if any. Returns the
// prior settings.statusLine object (e.g. { type: 'command', command: '...' })
// or null on any absence/parse/shape error — never throws.
function readCapturedPrior() {
  try {
    const raw = fs.readFileSync(priorStatuslinePath(), 'utf8');
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.command === 'string' && parsed.command.length > 0) {
      return parsed;
    }
    return null;
  } catch (_) {
    return null;
  }
}

// Re-invoke the captured prior statusLine command with the SAME raw stdin and
// emit its output verbatim (byte-for-byte), so the inactive-state output
// reproduces the user's prior/default statusline exactly. Returns true if
// delegation was attempted and its output was written (regardless of the
// delegate's own exit code — we still forward whatever it printed); returns
// false if delegation could not be attempted at all (e.g. no captured prior),
// in which case the caller falls back to this script's own default line.
function delegateToPrior(rawStdin) {
  const prior = readCapturedPrior();
  if (!prior) return false;

  try {
    const result = cp.spawnSync(prior.command, {
      input: rawStdin,
      encoding: 'utf8',
      shell: true,
      timeout: 5000,
    });
    // Emit the delegate's stdout verbatim — no trimming, no re-formatting —
    // so the byte-for-byte contract (AC3/INV3) holds even if the delegate
    // itself emits no trailing newline.
    if (typeof result.stdout === 'string') {
      process.stdout.write(result.stdout);
    }
    process.exit(0);
    return true;
  } catch (_) {
    // Delegate could not be spawned at all — degrade to this script's own
    // default line rather than erroring (INV9 spirit: never break the line).
    return false;
  }
}

function main() {
  const segmentMode = process.argv.includes('--segment');

  // Read + parse stdin.
  const raw = readStdin();
  const json = safeParse(raw);

  // Resolve cwd.
  const cwd = (json.workspace && json.workspace.current_dir)
    ? json.workspace.current_dir
    : (json.cwd || process.cwd());

  // Resolve model display name.
  const model = (json.model && typeof json.model.display_name === 'string')
    ? json.model.display_name
    : '';

  // Resolve session_id and the session-marker gate. Missing session_id (or
  // any error resolving the marker) is treated as "no marker" → inactive.
  const sessionId = (typeof json.session_id === 'string') ? json.session_id : null;
  const active = isSessionActive(sessionId);

  // Takeover + delegate (C3/INV3/AC3): when inactive and NOT in --segment
  // mode (--segment remains a developer/compose affordance, never the
  // restore mechanism), and a prior statusLine was captured by the
  // installer, re-invoke it verbatim and pass its output straight through.
  // If there is no captured prior (e.g. fresh install, nothing to restore),
  // fall through to this script's own default-mode line with no segment.
  if (!active && !segmentMode) {
    const delegated = delegateToPrior(raw);
    if (delegated) return; // process.exit(0) already called inside.
  }

  // Resolve active initiative slug only when the session is marker-active.
  const slug = active ? resolveSlug(cwd) : null;

  if (segmentMode) {
    // --segment: print ONLY ⚡<slug> or nothing.
    if (slug) {
      process.stdout.write(MAGENTA + '⚡' + slug + RESET + '\n');
    }
    // No slug → empty output (no newline).
    process.exit(0);
  }

  // Default mode: [branch] shortened-cwd [⚡<slug>] [model].
  const shortCwd = shortenCwd(cwd);
  const branch = gitBranch(cwd);
  let line = '';
  if (branch) {
    line += YELLOW + branch + RESET + ' ';
  }
  line += CYAN + shortCwd + RESET;

  if (slug) {
    line += ' ' + MAGENTA + '⚡' + slug + RESET;
  }

  if (model) {
    line += ' ' + DIM + model + RESET;
  }

  process.stdout.write(line + '\n');
  process.exit(0);
}

main();
