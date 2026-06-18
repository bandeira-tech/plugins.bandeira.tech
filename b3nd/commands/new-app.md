---
description: Build a whole b3nd app — URI scheme, programs, handlers, and a browser UI that is itself a b3nd.
argument-hint: "<app-name> [--ui vite-react | --no-ui]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# New b3nd app

A b3nd app is **not** a service. It's:

1. a **URI scheme** (the language the data speaks),
2. a **protocol module** (programs + handlers) that defines the rules,
3. a **UI** that reads and writes the same URIs as everything else.

This command walks the full flow. Don't skip steps to "just scaffold something" — the conversation with the user *is* the design.

## 0. Preflight

- Confirm the active rig target with `/b3nd:targets`. The app's protocol will need at least one connection that owns its URI scheme. Note this; we'll wire it up at the end.
- Read the b3nd skill files (`SKILL.md`, `APP.md`, `RIG.md`) so your suggestions match the framework's current shape. Verify package versions per TARGETS.md before generating any code.

## 1. Pick the URI scheme — talk to the user

Don't guess. Ask:
- What does the app *contain*? (posts, photos, sensor readings, anything.)
- What identifies a single item — a hash, a timestamp, a slug?
- Are there derived/secondary surfaces? (indexes, tags, relations.)

Propose 1–3 scheme shapes. Walk through one example URI per shape. The user picks.

The output of this step is a written URI table — every concrete URI pattern the protocol will own. Save it to `apps/<app-name>/URIS.md`.

## 2. Programs

For each ingest path (each thing the user can write), call `/b3nd:program` (or follow its steps inline): one program per input class. Programs classify, emit codes.

## 3. Handlers

For each code emitted by step 2, call `/b3nd:handler`: one handler per code kind. Handlers turn codes into `[uri, payload]` outputs.

## 4. Protocol module

Create `apps/<app-name>/mod.ts`:
- Export `programs`, `handlers`, optionally a `status()` manifest.
- Export an installer that takes a `Rig` and registers the protocol on the right URI patterns.
- **Do not** put storage choices here. Storage is the rig's concern.

## 5. UI — a b3nd on the frontend

UI default: **Vite + React + Tailwind** (matches `b3nd-web-rig`). If `--no-ui`, skip this step.

The UI is itself a b3nd consumer:
- It builds its own `Rig` in-browser (with `localStorage` / `IndexedDB` stores, or an `HttpClient` pointing at the user's node).
- It uses the **same protocol module** as the server side. One file, both sides.
- It reads through `read` and subscribes through `observe`. No bespoke fetch wrappers.

Scaffold:
- `apps/<app-name>/web/` — Vite project, Tailwind configured, one example page that lists items at the protocol's main URI pattern and a form that submits a new item via `receive`.
- Wire the protocol module by relative import; do not duplicate it.
- Run `deno check` (or the project's check) on the new files.

## 6. Wire into the rig

Tell the user the last step is theirs (or run it on confirmation):
- Add a connection in the active rig that owns the app's URI scheme (`/b3nd:rig add-connection`).
- Mount the protocol's installer on that connection.
- `bnd status` to confirm.

## 7. Hand off

Summarize what was created, the URIs the app speaks, and how to send / read / observe the first record from `bnd` and from the browser. Point the user at the skill for deeper material on data-oriented thinking and on contributing fixes upstream.

## Tone

This is a thinking exercise as much as a scaffolding one. Keep prose short, ask one question at a time when the user seems to be deciding, and never present 14 generated files in a wall — show the URI table first and confirm before generating handlers.
