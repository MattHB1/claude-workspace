#!/usr/bin/env bash
# check-manifests.sh — Tier 1: validate plugin.json and marketplace.json
# Run from repo root: bash .github/ci/check-manifests.sh
# Requires: jq
set -euo pipefail

PLUGIN_JSON="plugins/claude-workspace/.claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_jq() {
  command -v jq >/dev/null 2>&1 || fail "jq is not installed; cannot validate JSON manifests."
}

# ---------------------------------------------------------------------------
# Check 1: plugins/claude-workspace/.claude-plugin/plugin.json (AC2)
# ---------------------------------------------------------------------------
check_plugin_json() {
  echo "Checking $PLUGIN_JSON ..."

  [[ -f "$PLUGIN_JSON" ]] || fail "$PLUGIN_JSON does not exist."

  # Valid JSON
  jq . "$PLUGIN_JSON" >/dev/null 2>&1 || fail "$PLUGIN_JSON is not valid JSON."

  # Required field: name — must be a non-empty string
  name="$(jq -r '.name // empty' "$PLUGIN_JSON")"
  [[ -n "$name" ]] || fail "$PLUGIN_JSON: required field 'name' is missing or empty."

  # Required field: version — must be a non-empty string
  version="$(jq -r '.version // empty' "$PLUGIN_JSON")"
  [[ -n "$version" ]] || fail "$PLUGIN_JSON: required field 'version' is missing or empty."

  echo "  OK: $PLUGIN_JSON is valid JSON with non-empty 'name' and 'version'."
}

# ---------------------------------------------------------------------------
# Check 2: .claude-plugin/marketplace.json (AC3 / D4)
# ---------------------------------------------------------------------------
check_marketplace_json() {
  echo "Checking $MARKETPLACE_JSON ..."

  [[ -f "$MARKETPLACE_JSON" ]] || fail "$MARKETPLACE_JSON does not exist."

  # Valid JSON
  jq . "$MARKETPLACE_JSON" >/dev/null 2>&1 || fail "$MARKETPLACE_JSON is not valid JSON."

  # top-level name — non-empty string (value is NOT asserted; D4)
  top_name="$(jq -r '.name // empty' "$MARKETPLACE_JSON")"
  [[ -n "$top_name" ]] || fail "$MARKETPLACE_JSON: top-level 'name' is missing or empty."

  # top-level plugins — non-empty array
  plugins_length="$(jq '.plugins | length' "$MARKETPLACE_JSON" 2>/dev/null)" || \
    fail "$MARKETPLACE_JSON: could not read 'plugins' field."
  [[ "$plugins_length" -gt 0 ]] || fail "$MARKETPLACE_JSON: top-level 'plugins' must be a non-empty array."

  # Every plugins[] entry: non-empty name + source resolves to a real directory
  error_count=0
  while IFS= read -r entry_json; do
    entry_name="$(printf '%s' "$entry_json" | jq -r '.name // empty')"
    entry_source="$(printf '%s' "$entry_json" | jq -r '.source // empty')"

    if [[ -z "$entry_name" ]]; then
      echo "  FAIL: a plugins[] entry has a missing or empty 'name'." >&2
      (( error_count++ )) || true
    fi

    if [[ -z "$entry_source" ]]; then
      echo "  FAIL: plugins[] entry '${entry_name:-<unnamed>}' has a missing or empty 'source'." >&2
      (( error_count++ )) || true
    elif ! test -d "$entry_source"; then
      echo "  FAIL: plugins[] entry '${entry_name}' source '${entry_source}' is not a real directory." >&2
      (( error_count++ )) || true
    fi

    # owner (top-level) and description (per-entry) are expected but NOT fail-blocking (AC3 / D4).
  done < <(jq -c '.plugins[]' "$MARKETPLACE_JSON")

  [[ "$error_count" -eq 0 ]] || fail "$MARKETPLACE_JSON: $error_count plugins[] entry error(s) found."

  echo "  OK: $MARKETPLACE_JSON is valid JSON with non-empty top-level 'name', non-empty 'plugins' array, and all entries have non-empty 'name' and resolvable 'source' directories."
}

# ---------------------------------------------------------------------------
# Check 3: README badge versions match plugin.json version
# ---------------------------------------------------------------------------
check_readme_badge_versions() {
  echo "Checking README badge versions match $PLUGIN_JSON ..."

  plugin_version="$(jq -r '.version // empty' "$PLUGIN_JSON")"
  [[ -n "$plugin_version" ]] || fail "Could not read version from $PLUGIN_JSON."

  ROOT_README="README.md"
  PLUGIN_README="plugins/claude-workspace/README.md"

  for readme in "$ROOT_README" "$PLUGIN_README"; do
    [[ -f "$readme" ]] || fail "$readme does not exist."
    badge_version="$(grep -o 'img\.shields\.io/badge/version-[^-]*-brightgreen' "$readme" | sed 's|img\.shields\.io/badge/version-||; s|-brightgreen||')"
    if [[ -z "$badge_version" ]]; then
      fail "$readme: no version badge found (expected img.shields.io/badge/version-<VER>-brightgreen)."
    fi
    if [[ "$badge_version" != "$plugin_version" ]]; then
      fail "$readme: badge version '$badge_version' does not match plugin.json version '$plugin_version'."
    fi
    echo "  OK: $readme badge version '$badge_version' matches plugin.json."
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
require_jq
check_plugin_json
check_marketplace_json
check_readme_badge_versions

echo ""
echo "All manifest checks passed."
