---
description: Scaffold or edit a b3nd code handler (pure transform from a code to outputs).
argument-hint: "<protocol-dir> <handler-name>"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Scaffold a handler

A **handler** consumes one **code** (emitted by a program) and returns one or more **outputs** (`[uri, payload]` tuples) that the rig will route, store, or emit. Handlers are still pure — they describe *what* should happen, not perform it. The rig performs.

If your "handler" calls `fetch`, opens a file, or talks to a DB directly, you've reinvented a service. Stop and let the rig route the output to a connection that owns those side effects.

## Inputs

- `<protocol-dir>` — protocol module dir (must already exist; create via `/b3nd:new-app` or by hand if missing).
- `<handler-name>` — kebab-case. Usually matches the code kind it handles, e.g. `store-post` for code `{ kind: "store-post", ... }`.

## Steps

1. **Verify live API.** Fetch the current `Handler`/`Output` types from JSR for the user's installed `@bandeira-tech/b3nd-core` before writing.

2. **Identify the code being handled.**
   - Ask which code kind this handler covers. Cross-check that a program in `<protocol-dir>/programs/` actually emits it. If none does, ask whether the program is missing or this handler is premature.

3. **Define the outputs.**
   - Each output is `[uri, payload]`. URIs should follow the protocol's scheme (or `hash://` for content-addressed payloads).
   - One handler may emit multiple outputs (e.g. write + emit-event). That is fine and idiomatic.

4. **Create the file** at `<protocol-dir>/handlers/<handler-name>.ts`:
   - Export a pure function matching the live `Handler` signature for the chosen code kind.
   - Doc comment: "given code X, returns outputs Y, Z".

5. **Wire it up.**
   - Register in `<protocol-dir>/mod.ts` alongside other handlers. If the file uses a `Map<CodeKind, Handler>` or similar, extend it.
   - Run `deno check` on the protocol module.

## What goes wrong

- **Effectful handlers.** No fetch, no fs, no time. Returns outputs; that's it.
- **Code-kind collisions.** Two handlers claiming the same code kind. Detect by grepping the registry and warn before writing.
- **Output URIs that don't match any connection.** If the handler emits `[someapp://x, payload]` and no connection owns `someapp://**`, the rig drops it. Make sure the protocol's installer documents which connections it expects.
