# RIG — the lifecycle controller for your data

Once data starts flowing, you find out fast that just "storing it" isn't enough. You need to validate the shape on the way in. You need to react when something arrives. You need to fan one write out to several places. You need to log, audit, debug, and respond. You need to decide which of several stores actually owns a given URI.

A **rig** is the thing that handles all of that — *mechanically*, so the rest of your code can stay focused on the business.

In one sentence: each protocol you compose into a rig is a `ProtocolInterfaceNode` that knows *the rules* for its data; the rig is what wraps those nodes with the data affordances around them so the rules don't have to know about transport, storage, validation, or observation.

## What's in a rig

A rig has two parts and nothing else:

- **Connections** — each one is a `ProtocolInterfaceNode` (a remote node over HTTP/WS/gRPC, a local store, an in-process protocol module) plus the URI patterns it owns.
- **Routes** — four arrays: `send`, `receive`, `read`, `observe`. Each one is an ordered list of connections that will be consulted for that verb.

That's it. A real rig file is usually under 50 lines. If yours is sprawling, the sprawl belongs in a protocol module or a store, not the rig.

## The running example

This file uses one rig throughout — a journal app where you draft locally, publish shared, and content-address binary blobs:

```ts
// journal.rig.ts (conceptual; verify exports per TARGETS.md before generating)
import { Rig, connection, createClientFromUrl } from "@bandeira-tech/b3nd-core/rig";
import { fsStore } from "@bandeira-tech/b3nd-save/fs";
import { s3Store } from "@bandeira-tech/b3nd-save/s3";

export default async () => {
  const drafts = connection(fsStore({ root: "~/journal" }), ["journal://drafts/**"]);
  const node   = await createClientFromUrl("https://my-node.example.com");
  const shared = connection(node, ["journal://posts/**", "journal://comments/**"]);
  const blobs  = connection(s3Store({ bucket: "journal-blobs" }), ["hash://sha256/**"]);

  return new Rig({
    routes: {
      send:    [drafts, shared, blobs],
      receive: [drafts, shared, blobs],
      read:    [drafts, shared, blobs],
      observe: [drafts, shared, blobs],
    },
  });
};
```

Drafts stay on disk. Posts and comments go to a shared node. Binary blobs go to S3, addressed by `hash://sha256/...`. Same surface — `receive` / `read` / `observe` — across all three.

## The four routes

Plain: each route is a verb your code does, and the rig decides which connection handles it for a given URI.

| Route | What it means | Used by |
|---|---|---|
| `receive` | Something arrived — classify, transform, store. | `bnd receive`, app writes, server inbox. |
| `read` | Give me what's at this URI right now. | `bnd read`, UI reads, agent recalls. |
| `observe` | Tell me whenever URIs matching this pattern change. | `bnd observe`, reactive UIs, agents. |
| `send` | Push outputs outward (to a peer, another node, a transport). | Protocols that publish, replicators. |

For the journal rig above: `bnd read 'journal://posts/2026-06-21-*'` consults `shared` (the remote node) because `shared` owns `journal://posts/**`. A draft write at `journal://drafts/today` goes to the local FS. A binary attachment lands at `hash://sha256/...` on S3. None of that branching lives in the protocol — it lives in the rig.

## What `bnd` does with a rig

`bnd` is the thin runner around a rig. Every command imports the user's rig module and calls one of its routes:

| Command | Route used |
|---|---|
| `bnd send <file\|->` | `send` |
| `bnd receive <file\|->` | `receive` |
| `bnd read <uri>...` | `read` |
| `bnd observe <pattern>` | `observe` |
| `bnd node [--http --grpc --mcp]` | hosts the whole rig as services |
| `bnd status` | introspects the rig and reports |

This plugin's MCP server runs `bnd node --mcp --rig <active-target>` where `<active-target>` is the user's currently selected rig (see "Targeting" below).

Resolution order for the rig file: `--rig` flag → `./b3nd.rig.ts` in cwd → `rig = "..."` in `~/.bnd/config.toml`.

## Growing the rig

When the user asks "how do I add X to my rig", you are almost always answering one of three questions.

### 1. "I want to read or write somewhere new" → add a connection

Plain: somewhere the rig couldn't reach before should now be on the map.

In the journal example, the user wants to add a second laptop's drafts folder, accessible over the network. Pick the right client/store:

- A remote node over HTTP/WS/gRPC → `createClientFromUrl(url)`.
- A local filesystem path → the FS store from `@bandeira-tech/b3nd-save`.
- A SQLite file → the SQLite store.
- A Postgres/Mongo/Elasticsearch/S3/IPFS → the matching backend.
- The browser → `localStorage` or `IndexedDB` store.

Wrap it in `connection(client, [patterns])`. Add it to the relevant `routes` arrays. Done.

The `[patterns]` argument is the most consequential decision in the file. It says *which URIs this connection owns*. A connection that owns `**` will be consulted for every read/write — fine for a single-connection rig, dangerous once you have several. Narrow patterns are the discipline of a good rig:

```ts
// Don't:
const everything = connection(node, ["**"]);

// Do (journal example):
const drafts = connection(fsStore(...), ["journal://drafts/**"]);
const shared = connection(node,         ["journal://posts/**", "journal://comments/**"]);
const blobs  = connection(s3Store(...), ["hash://sha256/**"]);
```

That rig sends drafts to disk, posts and comments to the shared node, and binary blobs to S3 — all behind the same `receive` / `read` / `observe` surface.

### 2. "I want to add a new feature to my app" → that's a protocol concern, not a rig concern

Plain: adding rules lives in the protocol module, not the wiring.

Programs and handlers live in **protocol modules**. The rig wires a protocol's connection into routes; it doesn't host its logic. If the user reaches for `/b3nd:rig add-program`, redirect them: use `/b3nd:program` inside the relevant protocol module, then make sure a connection owns the URI scheme the protocol uses.

The point of the split: a protocol module can be imported by the rig (in-process), by a remote node (over HTTP), or by a browser tab (over WS or in-browser stores) — *unchanged*. Folding it into the rig file kills that portability.

### 3. "I want to change where the data is stored" → swap the store, keep the connection

Plain: move drafts from disk to SQLite without rewriting the journal.

If the user is happy with how the connection participates in routes but wants Postgres instead of SQLite, the change is one import and one constructor in the rig file. No business rules change. No protocol code changes. This is the single biggest payoff of writing data-first in the first place.

```ts
// before:
const drafts = connection(fsStore({ root: "~/journal" }), ["journal://drafts/**"]);
// after:
const drafts = connection(sqliteStore({ file: "~/.journal.db" }), ["journal://drafts/**"]);
```

The protocol doesn't care. The UI doesn't care. The user's existing URIs are still the contract.

## Hooks and events — the data lifecycle

Plain: when something flows through, you almost always want to react to it — validate, log, transform, fan out, respond. Hooks and events are how the rig lets you do that without burying the logic inside protocols.

The split is intentional. Protocols answer *what the data means*; the rig answers *what happens around the data flowing*. Things that fit the second category and belong on the rig:

- **Validation at the seam** — reject malformed payloads on `receive` before they reach a handler. Keeps handlers pure.
- **Audit / logging** — every write to `journal://posts/**` writes a paired line to `journal://audit/{ts}` so you can replay the day.
- **Response shaping** — after `receive` completes, return a structured ack the caller can consume (the result of a write, a derived URI, an error envelope).
- **Routing decisions on data**, not on URI patterns alone — e.g. blobs over 4MB go to S3, smaller ones to local FS. The pattern `hash://sha256/**` decides *what kind*; a hook decides *which physical store*.
- **Observability** — emit metrics or traces every time a route fires. The protocol shouldn't know about your tracer; the rig can.
- **Reactive fan-out** — on `receive` of a `journal://posts/**` write, mirror to `journal://feeds/{author}/**` so observers downstream see it without the protocol orchestrating fan-out.

The mental model: a `ProtocolInterfaceNode` is "the business" — it knows the rules for journal entries. The rig is the **mechanical data affordances** that wrap business: validation, audit, fan-out, response handling, observation. The node stays small and pure; the rig handles the inevitable surface area of moving data through a real system.

When the user reaches for "where do I put this side concern?", route them here first. If it's about meaning, it's a protocol concern. If it's about the *flow* — what happens to data on the way in, the way out, or to whom it gets repeated — it's a rig concern.

## `bnd status` — read it as a manifest

Plain: ask the rig what it thinks it is, then trust that view as your first diagnostic.

`bnd status` returns the resolved rig's view of itself: which connections are wired, which patterns they own, which routes they participate in, whether they're reachable, which hooks are registered. Use it as the first diagnostic when something is off:

- "I wrote a post and nothing happened" → check `status` for a connection that owns `journal://posts/**` in `receive`.
- "I can read but my UI doesn't refresh" → connection likely wired in `read` but not `observe`.
- "Everything is slow" → a remote connection may be timing out; status often surfaces it.

When the user runs `/b3nd:rig status`, that's the call.

## Targeting — which rig is active

Plain: keep more than one rig around (local dev, shared testnet, your own production node) and switch between them.

Targets live in `~/.bnd/targets.toml`:

```toml
active = "local"

[target.local]
rig = "/Users/me/work/journal/b3nd.rig.ts"
description = "Local dev rig"

[target.testnet]
rig = "https://testnet-evergreen.fire.cat"

[target.prod]
rig = "/Users/me/work/journal/prod.rig.ts"
```

`/b3nd:targets` manages this file. The MCP server reads `active` at session start and runs `bnd node --mcp --rig <that>`. Switching targets at runtime requires reconnecting the MCP (restart Claude Code, or trigger MCP reconnect).

## What does *not* belong in the rig

- Schemas. Lives in the protocol module.
- Programs and handlers. Live in the protocol module.
- Business rules of any kind. Live in the protocol module.
- API endpoints. The URI shape *is* the surface; routes are how the rig serves them.
- App-specific UI state. Browser concern, not protocol or rig.

If you find yourself writing any of the above in `b3nd.rig.ts`, stop. The rig is wiring + lifecycle. The wiring should be obvious at a glance; the lifecycle hooks should be small, named, and easy to find.

## Common rig mistakes to catch

- **Overlapping patterns with conflicting backends.** Two connections in `receive` both owning `journal://posts/**` — first one wins, the second is dead weight. Tell the user; narrow one.
- **`["**"]` everywhere.** Wildcards are fine for a single-connection rig. Once there are two connections, narrow patterns. Otherwise routing depends on array order, which is fragile.
- **A connection in `read` but not `observe`.** Common after adding a remote node. The user notices "I can read this but my UI never refreshes". Mirror connections across both unless there's a clear reason not to.
- **Bypassing the rig.** If a handler or a UI is calling `fetch` directly to "just get the data fast", that's a leak. The rig is the only thing that should reach across boundaries. Push the user back through `read`/`observe`.
- **Business logic in a hook.** Hooks are for mechanical affordances around the data flow — validation, audit, fan-out shape. If your hook is deciding journal taxonomy or computing derivations, that's a program or a handler. Move it.
