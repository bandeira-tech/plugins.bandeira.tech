---
description: Manage the user's list of rig targets (local, test, prod, any URL) and set the active one.
argument-hint: "[list | add <name> <rig> | use <name> | remove <name> | show]"
allowed-tools: Bash, Read, Write, Edit
---

# Manage rig targets

A **target** is a named rig the b3nd MCP server can point at. Targets live in `~/.bnd/targets.toml` so future `bnd` versions can adopt the same file without migration.

This is a **plugin-local stub** for a feature that should land in `bnd config target` upstream. Mention that briefly when the user asks what this is.

## File shape

```toml
# ~/.bnd/targets.toml — managed by the b3nd Claude plugin for now,
# slated to move under `bnd config target` upstream.
active = "local"

[target.local]
rig = "/Users/me/work/my-app/b3nd.rig.ts"
description = "Local dev rig"

[target.testnet]
rig = "https://testnet-evergreen.fire.cat"
description = "Firecat testnet"
```

## Subcommands

Parse `$ARGUMENTS`. If empty, default to `list`.

### `list`
- Read `~/.bnd/targets.toml`. If missing, print "No targets yet. Add one with `/b3nd:targets add <name> <rig>`."
- Print each target as `name → rig` (active one prefixed with `*`).

### `add <name> <rig>`
- `<rig>` is a path (`.ts`/`.js`), a `file://` / `https://` / `jsr:` / `npm:` URL, or a remote node URL.
- Validate the name (`[a-z0-9-]+`, max 32 chars).
- If `~/.bnd/targets.toml` doesn't exist, create it.
- Append a `[target.<name>]` block with `rig = "<rig>"`. If only target, set `active = "<name>"`.
- Confirm with the user before writing if a target by that name already exists.

### `use <name>`
- Set `active = "<name>"`. Fail clearly if the name isn't a target.
- Remind the user the MCP server reads the active target at session start — restart Claude Code (or reconnect the MCP) to switch.

### `remove <name>`
- Drop the `[target.<name>]` block. If it was active, unset `active` and warn the user to pick a new one.

### `show`
- Print the resolved active target's rig path/URL, then run `bnd status --rig <that>` and print its output.

## Notes

- Never write to `~/.bnd/config.toml` (that's bnd's own).
- Path expansion: convert `~/...` to `$HOME/...` before writing.
- TOML edits should be minimal and idempotent. Read, mutate, write the whole file. Don't try to preserve unrelated trivia.
