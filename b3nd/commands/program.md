---
description: Scaffold or edit a b3nd program (classifier → codes) inside a protocol module.
argument-hint: "<protocol-dir> <program-name>"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Scaffold a program

A **program** is a classifier: it takes an incoming `[uri, payload]` message and returns one or more **codes** — small instructions like `{ kind: "store", at: "...", payload }` or `{ kind: "emit", uri: "...", payload }`. Programs are pure functions of the input message. They are the protocol's brain.

Programs are **not** handlers. Handlers turn codes into effects (writes, emits). Keep the two responsibilities split — that separation is the whole point of the architecture.

## Inputs

- `<protocol-dir>` — directory of an existing protocol module (or to-be-created). Convention: one protocol per directory, `mod.ts` exports the protocol surface.
- `<program-name>` — kebab-case. Used for the filename and the exported function name (camelCased).

## Steps

1. **Verify the live API.** Read the user's installed `@bandeira-tech/b3nd-core` version, then fetch the current `Program`, `Code`, `Output` type signatures from JSR before generating code. Do not write from memory.

2. **Ask before assuming.**
   - What URI scheme(s) does this program classify? (e.g. `myapp://posts/...`, `hash://sha256/...`)
   - What codes does it emit? Common shapes: store-by-URI, emit-derivative, validate-only. The user describes; you propose 1–3 codes; they confirm.
   - Is this program **input-side** (runs on `receive`) or **read-side** (runs on `read`)? Most are input-side.

3. **Create the file** at `<protocol-dir>/programs/<program-name>.ts`:
   - Single export: a pure function matching the live `Program` signature.
   - No I/O, no side effects, no async unless the classifier itself needs await (rare).
   - Doc comment naming the codes it emits.

4. **Wire it up.**
   - If `<protocol-dir>/mod.ts` exposes a `programs` array or registry, add the new program there.
   - If not, leave a comment in the new file explaining where it should be registered, and tell the user.

5. **Mention handlers.**
   Programs without handlers are useless. After scaffolding, tell the user which handlers (`/b3nd:handler`) they will need to write next to actually realize the codes this program emits.

## What goes wrong

- **Mixing program + handler logic in one function.** If your program has a network call, a write, or a `Date.now()`, it's not a program anymore — it's a handler. Stop and split.
- **Hard-coded URI schemes.** The scheme should be a parameter of the protocol module, not baked into the program file. If the protocol picks `myapp://` at instantiation, the program should receive it via closure or registry, not import a constant.
- **Codes that aren't really codes.** If you're emitting `{ kind: "doTheThing", payload }` with no schema, the consumer (handler) has no contract. Codes should be small, named, and shaped.
