---
description: Grow the active target rig — add connections, mount programs, inspect status.
argument-hint: "[status | add-connection <name> <url-or-path> [pattern] | list-connections | add-program <uri-scheme>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Grow your rig

A **rig** is the user's personal data graph: a set of `connection`s (each one is a `ProtocolInterfaceNode` plus the URI patterns it owns) wired into `routes` for `send` / `receive` / `read` / `observe`.

This command edits the rig module of the **active target** (see `/b3nd:targets`). Most actions are surgical edits to a TypeScript file.

## Preflight

1. Resolve the active target's rig path. If it's a remote URL (`http://`, `jsr:`, `npm:`), tell the user this command only edits local rig modules and stop.
2. Read the rig file. Confirm its default export is either a `Rig` instance, a `() => Rig`, or `async (env) => Rig` form (see `b3nd-cli` README).
3. Before each command verifies live B3nd API: **follow TARGETS.md / the b3nd skill's relay protocol** — read the user's installed `@bandeira-tech/b3nd-core` version from `deno.json`, then fetch the actual export shape from JSR. Do not write code from memory.

## Subcommands

### `status`
- `bnd status --rig <active>` and print output.

### `list-connections`
- Parse the rig module's `connection(...)` calls and `routes:` wiring.
- Print: name (variable), URI patterns, which routes it serves.

### `add-connection <name> <url-or-path> [pattern]`
- `<url-or-path>` is what the connection talks to — an HTTP/WS/gRPC URL for a remote node, or a local store config (FS path, SQLite file). For v0.1 prefer:
  - HTTP/WS URL → `createClientFromUrl(...)` from `b3nd-core/rig`.
  - FS path → import the FS store from `@bandeira-tech/b3nd-save`.
  - SQLite path → import the SQLite store.
- `[pattern]` is the URI prefix (or set) this connection owns. Default to `**` if not provided; warn the user when defaulting.
- Edit the rig file:
  1. Add imports.
  2. Build the client/store.
  3. Wrap in `connection(client, [<patterns>])`.
  4. Add to relevant `routes` arrays.
- Run `deno check <rig>` and report any errors. Don't try to "auto-fix" — surface to the user.

### `add-program <uri-scheme>`
- Programs are protocol-side, not rig-side. Redirect the user: "Programs live in a protocol module, not the rig. Use `/b3nd:program` to scaffold one, then mount it via the protocol's installer (or via `connection(...)` if the protocol exposes an in-process node)."

## What a rig is *not*

- Not an app. The same rig hosts many apps and protocols.
- Not a server. Hosting is `bnd node --http --grpc --mcp`; the rig is the wiring.
- Not a database. It composes stores; you can swap them.

When the user asks "where does X go?", default to: **schemas and protocols in their own modules; the rig only wires them into routes.**
