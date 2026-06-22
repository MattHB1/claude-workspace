#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

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
    if (line.includes('**ACTIVE**')) {
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

// ANSI helpers.
const CYAN    = '\x1b[36m';
const MAGENTA = '\x1b[35m';
const DIM     = '\x1b[2m';
const RESET   = '\x1b[0m';

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

  // Resolve active initiative slug.
  const slug = resolveSlug(cwd);

  if (segmentMode) {
    // --segment: print ONLY ⚡<slug> or nothing.
    if (slug) {
      process.stdout.write(MAGENTA + '⚡' + slug + RESET + '\n');
    }
    // No slug → empty output (no newline).
    process.exit(0);
  }

  // Default mode: shortened-cwd [⚡<slug>] [model].
  const shortCwd = shortenCwd(cwd);
  let line = CYAN + shortCwd + RESET;

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
