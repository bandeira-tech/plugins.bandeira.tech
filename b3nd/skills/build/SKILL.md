---
name: build
description: |
  Use when the user wants to build or ship something with B3nd — a web app,
  CLI, backend service, or data protocol — or integrate/migrate an existing
  system into B3nd. Triggers: build / scaffold / ship with b3nd; add b3nd to
  an existing flow (endpoint or entrypoint); build a client Protocol Interface
  Node (PIN); design URIs, payloads, or PIN coordination; handle errors in a
  b3nd PIN. For concepts and evaluation rather than building, use `learn`.
---

# Start Building with B3nd — learn by doing and keep shipping

The build skill helps you build what you want to build, using B3nd. Pick the
target that matches your situation and follow the linked guide.

**RULE 0 — Treat every code example here as possibly stale.** It shows shape
and intent only. Before writing any implementation plan or code you MUST
consult the latest (or your target version's) source. Package, function, and
flag names drift — verify against `b3nd-core`, `b3nd-move`, and `b3nd-save`
before committing to an approach.

## Migrate and/or integrate with running systems

Add B3nd to systems that already exist, incrementally.

- **[Build a Client PIN](build-client-module.md)** — a composable, portable,
  reusable module that gives an existing integration a B3nd interface.
- **[Build an Endpoint integration](build-endpoint-integration.md)** — add a
  B3nd node to an existing flow so your system emits Outputs downstream.
- **[Build an Entrypoint integration](build-entrypoint-integration.md)** —
  make B3nd trigger an existing flow, by call-through or by observation.
- **[Build Error Handling](build-error-handling.md)** — shape PIN errors to
  fit the experience your target needs.

## Start fresh

Begin a new application on B3nd, local-first, and switch infrastructure later.

- **[Build a Web App](build-web-app.md)** — start local-first with localStorage,
  then point the same client PIN at localhost or a B3nd server of your choice.
- **[Build a CLI App](build-cli-app.md)** — deliver local-first with the
  filesystem or a local database; ship pluggable, extensible terminal interfaces.
- **[Build a Backend App](build-backend-app.md)** — serve domain or data services
  over HTTP, WS, and/or MCP using a rig that handles and reacts to received data.
- **[Build a Data Protocol](build-data-protocol.md)** — design the domain-agnostic
  plumbing: URI grammar, payload types, classification, validation, and handling.
- **[Build a Domain Protocol](build-domain-protocol.md)** — model a domain's
  object lifecycle, states, and semantics, shipped as mountable uri/payload rules.

> These guides assume you've read the basics above. They only move forward — for
> the concepts, use `learn`; follow RULE 0 to read current source for mechanics.
