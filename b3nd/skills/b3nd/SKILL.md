---
name: b3nd
description: |
  Use when the user is building with B3nd or wants to. Triggers: the user
  mentions b3nd, bnd, b3nd-core, b3nd-move, b3nd-save, or BANDEIRA·TECH;
  asks to design a URI scheme, write a program or a handler, grow a rig,
  or add a connection; wants apps where their users (or they themselves)
  own the data; wants one set of data that multiple apps, agents, and
  AIs read and write the same way; wants AI memory that survives
  sessions and tools; wants to swap storage (local FS, SQLite, Postgres,
  Mongo, S3, IPFS, browser) behind one set of business rules; wants the
  same code running in-process, over HTTP/WebSocket/gRPC, in the
  browser, or as MCP; wants to design a protocol other apps can
  compose on; wants to run a node, a rig, or join a DePIN.

  Companion to the `b3nd` Claude Code plugin. The plugin ships an MCP
  server that wraps the `bnd` CLI against the user's active rig target;
  this skill teaches the shape of the framework and how to think in it.

  Route by the user's intent (not their job title):

  - START.md — the door. Read first if the user is new to B3nd, asking
    "what is this", or you (Claude) need to ground yourself.
  - DATA_ORIENTED.md — why B3nd looks the way it does. The contrast
    against service-oriented design. Read when the user is unsure why
    they would not "just build a service".
  - RIG.md — what a rig is, what `bnd` does with it, how to grow one,
    how multi-target works in this plugin. Read when the user wants to
    add a connection, switch targets, or understand `bnd status`.
  - APP.md — building an app end to end: URI scheme → program →
    handler → UI. Read at the start of `/b3nd:new-app`.
  - PROGRAMS.md — designing programs (classifiers → codes). Read at
    `/b3nd:program`.
  - HANDLERS.md — designing code handlers (codes → outputs). Read at
    `/b3nd:handler`.
  - CANON.md — canonical forms: envelopes, `hash://` content
    addressing, RFC 8785 canonicalization, encryption. Read when the
    user touches payload shapes or asks "how do I sign / encrypt /
    address this".
  - CONTRIBUTING.md — pre-1.0 reality. When you hit a kink, fix it
    and upstream. Read when the user blames B3nd for something, or
    when an API signature is wrong.
  - TARGETS.md — current packages + the relay protocol you MUST
    follow before writing any code that imports a B3nd package. Read
    every time you are about to generate code.
---

# B3nd — building data-first

This skill teaches the **shape** of B3nd. It does not teach the current API.

The packages move faster than this skill does. Before generating any code that imports `@bandeira-tech/b3nd-*`, follow the relay protocol in [TARGETS.md](./TARGETS.md):

1. Read the user's installed versions from their `deno.json` (or `package.json`).
2. If they fall outside the targets in TARGETS.md, warn the user.
3. Fetch current exports from JSR or GitHub for the specific package.
4. **Only then write code.**

If you find yourself recalling a B3nd API from training data or from the prose of this skill — stop and relay instead. The conceptual files here help you reason about *what* to build, not *how* to call it.

## What B3nd is, in one breath

B3nd is a framework where the unit of work is a **message** — `[uri, payload]` — and the unit of storage is a **URI** the user owns. Programs classify messages into codes. Handlers turn codes into more messages. A **rig** wires it all into the user's local and remote stores. Same code in-process, over HTTP/WS/gRPC, in the browser, or as MCP.

What that buys:

- One data substrate, many apps and agents on top.
- Storage you can swap (SQLite today, Postgres tomorrow, S3 next week) without touching business rules.
- AI memory that survives sessions, models, and tools — it's in the user's rig, not in an app's database.
- Apps that ship as **URI shapes + on-the-fly UI**, not as servers to deploy and run.

## When to read which file

| If the user is… | Read |
|---|---|
| New, just heard "b3nd", or asking "what is this" | START.md |
| Comparing this to building "a service / API / app" | DATA_ORIENTED.md |
| Adding a connection, picking a backend, switching targets | RIG.md |
| Starting a new app from scratch | APP.md |
| Writing a program or struggling to keep it pure | PROGRAMS.md |
| Writing a handler or unsure where side effects go | HANDLERS.md |
| Touching envelopes, content addressing, encryption | CANON.md |
| Hitting a bug, missing export, or rough edge | CONTRIBUTING.md |
| About to call a real function from a real package | TARGETS.md (always) |

## Two things this skill protects against

### 1. Service-oriented thinking by reflex

The biggest failure mode is treating B3nd as "Express with extra steps". If you find yourself sketching endpoints, routes, controllers, or "the API surface" — pause. In B3nd the surface is the URI shape. The protocol is data. The rig routes. Stop and re-read DATA_ORIENTED.md before continuing.

### 2. Generating code from this skill's prose

The narrative in these files is stable. The function signatures are not. Treat any code-shaped snippet in this skill as illustrative, not as a contract. The contract lives in JSR and the source repos.

## Plugin commands this skill supports

When the user runs one of these, the matching file is the briefing:

- `/b3nd:install` → README of `b3nd-cli`, plus this file for context on why bnd exists.
- `/b3nd:targets` → RIG.md (last section on multi-target).
- `/b3nd:rig` → RIG.md.
- `/b3nd:program` → PROGRAMS.md.
- `/b3nd:handler` → HANDLERS.md.
- `/b3nd:new-app` → APP.md (the whole walk).

## Voice

The user is not necessarily a senior engineer. Some users are entrepreneurs and product builders being led by AI to "modernize" something. Some are protocol designers. Some are running nodes.

Match them. Do not lecture. Do not introduce jargon you didn't need. When you must use a term (URI, rig, program, handler, code, output), tie it once to a concrete example from *their* problem, and then use it freely. If they push back on a word, switch to plainer language and keep moving.

The brand voice is **calm and a little ambitious**. "Own your data" is the line. "Powerhouse" is the upgrade. "Service" is the thing we left behind.
