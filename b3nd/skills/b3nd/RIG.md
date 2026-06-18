# RIG — your wiring diagram

A **rig** is the user's wiring of data. It doesn't store anything itself; it routes. The shape is small and stays small:

- **Connections** — each one is a thing that can talk to a piece of the world (an HTTP node, a WebSocket node, a local FS store, a SQLite file, an in-process protocol module) plus the URI patterns it owns.
- **Routes** — four arrays: `send`, `receive`, `read`, `observe`. Each one is an ordered list of connections that will be consulted for that verb.

That's it. A real rig file is usually under 50 lines. If yours is sprawling, the sprawl belongs in a protocol module or a store, not the rig.

## What `bnd` does with a rig

`bnd` is a thin runner. Every command imports the user's rig module and calls one of its routes:

| Command | Route used |
|---|---|
| `bnd send <file\|->` | `send` |
| `bnd receive <file\|->` | `receive` |
| `bnd read <uri>...` | `read` |
| `bnd observe <pattern>` | `observe` |
| `bnd node [--http --grpc --mcp]` | hosts the whole rig as services |
| `bnd status` | introspects the rig and reports |

The rig file resolution order (every command does this):

1. `--rig <path|url>` flag — wins if present.
2. `./b3nd.rig.ts` in the current directory.
3. `rig = "..."` in `~/.bnd/config.toml`.

This plugin's MCP server runs `bnd node --mcp --rig <active-target>` where `<active-target>` comes from `~/.bnd/targets.toml` (see "Multi-target" below).

## What a rig file looks like

A default export — a `Rig`, a `() => Rig`, or `async (env) => Rig`:

```ts
// b3nd.rig.ts — conceptual shape (verify exports per TARGETS.md before generating)
import { Rig, connection, createClientFromUrl } from "@bandeira-tech/b3nd-core/rig";

export default async () => {
  const node = await createClientFromUrl("https://my-node.example.com");
  const everything = connection(node, ["*"]);
  return new Rig({
    routes: {
      send:    [everything],
      receive: [everything],
      read:    [everything],
      observe: [everything],
    },
  });
};
```

That single-connection rig is the smallest useful one. Most rigs grow by adding connections that own different URI patterns, not by adding logic to the rig file.

## Growing the rig

When the user asks "how do I add X to my rig", you are almost always answering one of three questions:

### 1. "I want to read/write somewhere new" → add a connection

Pick the right client/store for the destination:

- A remote node over HTTP/WS/gRPC → `createClientFromUrl(url)` (or the explicit client class).
- A local filesystem path → the FS store from `@bandeira-tech/b3nd-save`.
- A SQLite file → the SQLite store.
- A Postgres/Mongo/S3/IPFS/etc. → the matching backend.
- The browser → `localStorage` or `IndexedDB` store.

Wrap it in `connection(client, [patterns])`. Add it to the relevant `routes` arrays. Done.

The `[patterns]` parameter is the most important decision in the file. It says *which URIs this connection owns*. A connection that owns `**` will be consulted for every read/write — fine for a single-connection rig, dangerous once you have several. Narrow patterns are the discipline of a good rig:

```ts
const local  = connection(fsStore, ["myapp://drafts/**"]);
const shared = connection(remoteNode, ["myapp://posts/**", "myapp://comments/**"]);
const hashes = connection(s3Store, ["hash://sha256/**"]);
```

That rig sends drafts to disk, posts and comments to the shared node, and binary blobs to S3 — all behind the same `send/receive/read/observe` surface.

### 2. "I want to add a new feature to my app" → that's a protocol concern, not a rig concern

Programs and handlers live in **protocol modules**, not in the rig file. The rig wires a protocol's connection into routes; it doesn't host its logic. If the user asks `/b3nd:rig add-program`, redirect them: use `/b3nd:program` inside the relevant protocol module, then make sure a connection owns the URI scheme the protocol uses.

This separation is the whole point. A protocol module can be imported by the rig (in-process), by a remote node (over HTTP), or by a browser tab (over WS or in-browser stores) — *unchanged*. Putting it in the rig file kills that.

### 3. "I want to change where the data is stored" → swap the store, keep the connection

If the user is happy with how the connection participates in routes but wants Postgres instead of SQLite, the change is one import and one constructor in the rig file. No business rules change. No protocol code changes. This is the single biggest reason to write data-first in the first place.

## `bnd status` — read it as a manifest

`bnd status` returns the resolved rig's view of itself: which connections are wired, which patterns they own, whether they're reachable. Use it as the first diagnostic when something is off:

- "I sent something and nothing happened" → check `status` for a connection that owns that URI pattern in `send`.
- "I can read but not observe" → connection might be wired in `read` only.
- "Everything is slow" → a remote connection may be timing out; status often surfaces it.

When the user runs `/b3nd:rig status`, that's the call.

## Multi-target — this plugin's stub

A user often wants more than one rig: a local dev rig with a SQLite file, a shared testnet rig pointing at a remote node, a production rig pointing at their own node. Switching by editing `~/.bnd/config.toml` works but is clumsy.

This plugin adds `~/.bnd/targets.toml`:

```toml
active = "local"

[target.local]
rig = "/Users/me/work/my-app/b3nd.rig.ts"
description = "Local dev rig"

[target.testnet]
rig = "https://testnet-evergreen.fire.cat"

[target.prod]
rig = "/Users/me/work/my-app/prod.rig.ts"
```

`/b3nd:targets` manages it. The MCP server reads `active` at session start and exec's `bnd node --mcp --rig <that>`. Switching targets at runtime requires reconnecting the MCP (restart Claude Code, or trigger MCP reconnect).

This file format is a **stub**. The intent is to upstream the same shape to `bnd config target` so the file lives in bnd's own surface and this plugin defers. When that happens, this plugin reads the same file via `bnd` and the manual stub goes away.

## What does *not* belong in the rig

- Schemas. Lives in the protocol module.
- Programs. Live in the protocol module.
- Handlers. Live in the protocol module.
- Business rules of any kind. Live in the protocol module.
- API endpoints. The "API" is the URI shape; the routes are how the rig serves them.
- Auth logic specific to an app. That's a protocol concern (via canon envelopes / signing) or a connection concern (per-connection client config).

If you find yourself writing any of the above in `b3nd.rig.ts`, stop. The rig is wiring. The wiring should be obvious at a glance.

## Common rig mistakes to catch

- **Overlapping patterns with conflicting backends.** Two connections in `send` both owning `myapp://**` — first one wins, the second is dead weight. Tell the user; narrow one.
- **`["*"]` everywhere.** Wildcards are fine for a one-connection rig. Once there are two connections, narrow patterns. Otherwise the rig becomes ambiguous and routing depends on array order.
- **A connection in `read` but not `observe`.** Common when remote nodes are added. The user notices "I can read this but my UI never refreshes". Mirror connections across both unless there's a reason not to.
- **Bypassing the rig.** If a handler or a UI is calling `fetch` directly to "just get the data fast", that's a leak. The rig is the only thing that should reach across boundaries. Push the user back through `read`/`observe`.
