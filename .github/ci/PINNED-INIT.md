# PINNED headless init-event shape

Durable reference for Tier-2 assertions (T9). Re-pin this file if a future CLI version changes the init-event schema.

## CLI version pinned against

`claude-code v2.1.185` — probed 2026-06-22.

## Probe command

Run from repo root:

```
claude --plugin-dir ./plugins/claude-workspace -p "noop" --output-format stream-json --verbose
```

## Init event

The init event is the `stream-json` line with `"type":"system","subtype":"init"`:

```json
{"type":"system","subtype":"init", ...}
```

It is emitted **before** the model turn.

## Pinned top-level jq paths

All paths are top-level — NOT nested under `.data.*`.

### `.plugins[]`

Objects with shape `{name, path, source}`.

Assert `claude-workspace` is present:

```
select(.type=="system" and .subtype=="init") | .plugins[] | select(.name=="claude-workspace")
```

must be non-empty.

### `.agents[]`

Array of namespaced strings. Must contain all 8 agents:

- `claude-workspace:archivist`
- `claude-workspace:context-recovery`
- `claude-workspace:implementation-verifier`
- `claude-workspace:implementer`
- `claude-workspace:proposal-writer`
- `claude-workspace:research-harvester`
- `claude-workspace:task-checker`
- `claude-workspace:task-planner`

### `.skills[]`

Contains `claude-workspace:workspace`.

### `plugin_errors`

On a clean load this key is **absent** (not present as `[]`). The assertion must be "absent OR empty" — never `== []`, which would false-fail on a clean load.

## Re-pinning rule

If a future CLI release changes the init-event schema (key names, nesting, or the presence/absence behaviour of `plugin_errors`), re-run the probe command against the new CLI version, update this file with the new paths, and update the Tier-2 assertion script accordingly.
