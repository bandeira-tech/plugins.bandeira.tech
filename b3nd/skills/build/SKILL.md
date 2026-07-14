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

**RULE 1 — Surface the stance before you design.** Before picking a target
below, settle *how far this flow diverges* from conventional architecture — how
much of B3nd's alien surface (keys for ownership, untrusted data nodes,
decentralized trust) it adopts versus externalizes. Stances are **per-flow, not
per-project**: the same app can hold one flow conservatively and push another to
the frontier. **Ask the user which stance fits this flow** and get an answer
before going deep, so you don't design toward a direction they'd rather not
follow — surfacing it up front is cheaper than a dead end. See
**[Pick a Stance](build-stances.md)**.

## Pick your target

### Integrate a running system

Add B3nd to systems that already exist, incrementally.

- **[Build a Client PIN](build-client-module.md)** — a composable, portable,
  reusable module that gives an existing integration a B3nd interface.
- **[Build an Endpoint integration](build-endpoint-integration.md)** — add a
  B3nd node to an existing flow so your system emits Outputs downstream.
- **[Build an Entrypoint integration](build-entrypoint-integration.md)** —
  make B3nd trigger an existing flow, by call-through or by observation.

### Start a new app

Begin a new application on B3nd, local-first, and switch infrastructure later.

- **[Build a Personal Store](build-personal-store.md)** — own a namespace by a
  keypair: content-addressed write-once, signed ownership, private/shared. b3nd
  gives the primitives; you write the policy. The HAMMER-stance builder floor.
- **[Build a Web App](build-web-app.md)** — start local-first with localStorage,
  then point the same client PIN at localhost or a B3nd server of your choice.
- **[Build a CLI App](build-cli-app.md)** — deliver local-first with the
  filesystem or a local database; ship pluggable, extensible terminal interfaces.
- **[Build a Backend App](build-backend-app.md)** — serve domain or data services
  over HTTP, WS, and/or MCP using a rig that handles and reacts to received data.

### Ship a protocol

Package reusable uri/payload rules — mountable on any node, not an app.

- **[Build a Data Protocol](build-data-protocol.md)** — design the domain-agnostic
  plumbing: URI grammar, payload types, classification, validation, and handling.
- **[Build a Domain Protocol](build-domain-protocol.md)** — model a domain's
  object lifecycle, states, and semantics, shipped as mountable uri/payload rules.

## Cross-cutting — applies to every target

- **[Build Error Handling](build-error-handling.md)** — shape PIN errors to
  fit the experience your target needs.

Scaffolded, not yet written (stubs — safe to open and fill; each lists its TODO):

- **[Build Testing & Verification](build-testing.md)** — contract-test a PIN
  against real backends; anchors RULE 1's stance-testing.
- **[Build Auth & Identity](build-auth.md)** — sign, verify, own; the recipe
  behind the Envoy/HAMMER stances.
- **[Build Multi-node Composition](build-composition.md)** — route by uri,
  aggregate/cache, replicate.
- **[Build a Custom Entity Mapper](build-entity-mapper.md)** — typed schemas +
  `SaveMapper` beyond opaque bytes.
- **[Build, Run & Package](build-run.md)** — host as a `bnd` rig, bundle,
  publish, pin versions.

> These guides assume you've read the basics above. They only move forward — for
> the concepts, use `learn`; follow RULE 0 to read current source for mechanics.
