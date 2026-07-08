# Build a B3nd backend app that serves over the wire

A backend is a `Rig` with a storage client wired into `routes`, stood up behind
one or more `b3nd-move` transports. The transport is a deployment choice — every
client (browser, CLI, other backends) reaches the same PIN surface either way.

### storage client — `SaveClient` turns an `EntityStore` into a PIN

```ts
import { SaveClient, mapToBytes } from "@bandeira-tech/b3nd-save/clients";
import { BYTES_ENTITY } from "@bandeira-tech/b3nd-save";
import { MemoryStore } from "@bandeira-tech/b3nd-save/memory";
// backends are interchangeable: swap for SqliteStore, PostgresStore, ... same client
// import { SqliteStore } from "@bandeira-tech/b3nd-save/sqlite";

const store = new MemoryStore();
// provision the entity once before serving (no lifecycle hook on the client)
await store.provisionEntity(store.entitySupport(BYTES_ENTITY));

// SaveClient(mapper, targetSchema, store) — the mapper is your seam:
// mapToBytes = opaque bytes; or your own SaveMapper<T> to encode a typed record
// into BYTES_ENTITY (see k3p's clipToBytes); or passThroughRecord + a custom schema.
const backend = new SaveClient(mapToBytes, BYTES_ENTITY, store);
```

### rig — wire the storage client into `routes`; add domain logic as needed

```ts
import { Rig, connection } from "@bandeira-tech/b3nd-core";

// connection(client, patterns) scopes which uris this route accepts
const c = connection(backend, ["mutable://**", "hash://**"]);

const rig = new Rig({
  routes: { receive: [c], read: [c], observe: [c] },
  // a served rig is exposed to the network — gate writes with a beforeReceive
  // hook for auth (throw to reject; see build-error-handling.md):
  hooks: { beforeReceive: (ctx) => {/* verify ctx.uri / ctx.data */} },
  // domain services live here — see build-error-handling.md for the full grammar:
  programs:  { "store://balance": /* classify */ myProgram },
  handlers:  { "app:valid": async (out) => [out] },
  reactions: { "mutable://users/*": async (out, _read) => [/* fan-out tuples */] },
});
```

### serve over HTTP — `httpApi(rig, { codec })` → a `(Request) => Response`

```ts
import { httpApi } from "@bandeira-tech/b3nd-move/http/service";
import { httpOutputsFrame } from "@bandeira-tech/b3nd-move/codecs/http";

// run: deno run --allow-net server.ts
Deno.serve({ port: 3000 }, httpApi(rig, { codec: httpOutputsFrame() }));
// cross-origin browsers: wrap with withCors from "@bandeira-tech/b3nd-move/cors"
```

### serve over WebSocket — `wsApi(rig, { codec })` → attach per upgraded socket

```ts
import { wsApi } from "@bandeira-tech/b3nd-move/ws/service";
import { wsJsonEnvelope } from "@bandeira-tech/b3nd-move/codecs/ws";

const attach = wsApi(rig, { codec: wsJsonEnvelope() });
Deno.serve({ port: 8080 }, (req) => {
  if (req.headers.get("upgrade") !== "websocket") return new Response(null, { status: 404 });
  const { socket, response } = Deno.upgradeWebSocket(req); // host owns the upgrade
  attach(socket);
  return response;
});
```

### serve over MCP — `mcpHttpApi(rig, { codec })` → stateless fetch handler

```ts
import { mcpHttpApi } from "@bandeira-tech/b3nd-move/mcp/http/service";
import { mcpTextJsonStringify } from "@bandeira-tech/b3nd-move/codecs/mcp";

// exposes b3nd_receive / b3nd_read / b3nd_status tools + b3nd://* resources
Deno.serve({ port: 3000 }, mcpHttpApi(rig, { codec: mcpTextJsonStringify() }));
```

### one rig, all three transports on one port — dispatch by request shape

```ts
const http = httpApi(rig, { codec: httpOutputsFrame() });
const ws   = wsApi(rig, { codec: wsJsonEnvelope() });
const mcp  = mcpHttpApi(rig, { codec: mcpTextJsonStringify() });

Deno.serve({ port: 3000 }, (req) => {
  if (req.headers.get("upgrade") === "websocket") { const { socket, response } = Deno.upgradeWebSocket(req); ws(socket); return response; }
  if (new URL(req.url).pathname.startsWith("/api/v1/mcp")) return mcp(req);
  return http(req);
});
// clients reach the same receive/read/observe/status PIN regardless of transport
```
