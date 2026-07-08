# Build a Web App on a B3nd backend

Build the frontend against a single b3nd PIN — `receive` / `read` /
`observe`. The app never names its backend; you swap browser-local storage for a
remote server later without touching a line of app code.

### The app talks to a PIN it is handed — nothing backend-specific

```ts
import type { ProtocolInterfaceNode } from "@bandeira-tech/b3nd-core/types";

// the whole app sees only this — receive to write, read to load, observe to live-update
function mountApp(pin: ProtocolInterfaceNode) {
  async function saveTodo(id: string, todo: unknown) {
    await pin.receive([[`mutable://todos/${id}`, todo]]);
  }
  async function loadTodo(id: string) {
    const [hit] = await pin.read([`mutable://todos/${id}`]);
    return hit?.[1];
  }
  async function watchTodos(signal: AbortSignal, on: (uri: string, v: unknown) => void) {
    for await (const uris of pin.observe(["mutable://todos/**"], signal)) {
      for (const [uri, v] of await pin.read([...uris])) on(uri, v);
    }
  }
  return { saveTodo, loadTodo, watchTodos };
}
```

### A rig is the natural PIN — it routes URIs to whatever client backs them

```ts
import { connection, Rig } from "@bandeira-tech/b3nd-core";

// backend is one argument to connection(); app is handed the rig, not the client
function makeRig(backend: ProtocolInterfaceNode): Rig {
  const node = connection(backend, ["mutable://todos/**"]);
  return new Rig({ routes: { receive: [node], read: [node], observe: [node] } });
}

const app = mountApp(makeRig(/* backend chosen below */));
```

## Stage 1 — browser-local, no server

### `SaveClient` over a `LocalStorageStore` is a full PIN in the browser

```ts
import { SaveClient, mapToBytes } from "@bandeira-tech/b3nd-save/clients";
import { BYTES_ENTITY } from "@bandeira-tech/b3nd-save";
import { LocalStorageStore } from "@bandeira-tech/b3nd-save/localstorage";

const store = new LocalStorageStore(/* { keyPrefix } */);
await store.provisionEntity(store.entitySupport(BYTES_ENTITY)); // app-boot, out of band

// mapper + entity + store — "receive bytes, map opaque, store on localStorage"
const backend = new SaveClient(mapToBytes, BYTES_ENTITY, store);

const app = mountApp(makeRig(backend)); // ships with zero server
```

### Swap the store for `IndexedDBStore` — same client, larger/async medium

```ts
import { IndexedDBStore } from "@bandeira-tech/b3nd-save/indexeddb";

const store = new IndexedDBStore(/* { databaseName } */);
await store.provisionEntity(store.entitySupport(BYTES_ENTITY));
const backend = new SaveClient(mapToBytes, BYTES_ENTITY, store);
```

## Stage 2 — point at a remote server

### Replace the backend with an `HttpClient` — the codec must match the operator's

```ts
import { HttpClient } from "@bandeira-tech/b3nd-move/http/client";
import { httpOutputsFrame } from "@bandeira-tech/b3nd-move/codecs/http";

// same codec the server passed to httpApi(rig, { codec }) — server side: build-backend-app.md
const backend = new HttpClient({
  url: "https://my-b3nd-server.example",
  codec: httpOutputsFrame(),
  // preSend: (r) => r.headers.set("Authorization", `Bearer ${token}`),
});

const app = mountApp(makeRig(backend)); // makeRig / mountApp unchanged
```

### Or a `WebSocketClient` for live observe over one connection

```ts
import { WebSocketClient } from "@bandeira-tech/b3nd-move/ws/client";
import { wsJsonEnvelopeBase64 } from "@bandeira-tech/b3nd-move/codecs/ws";

const backend = new WebSocketClient({
  url: "wss://my-b3nd-server.example",
  codec: wsJsonEnvelopeBase64(), // byte-faithful; must match the server's wsApi codec
});
```

### The punchline — only the backend line changed

```ts
// stage 1
const backend = new SaveClient(mapToBytes, BYTES_ENTITY, new LocalStorageStore());
// stage 2
const backend = new HttpClient({ url: myUrl, codec: httpOutputsFrame() });

// identical either way — makeRig(backend), mountApp(rig), every pin.receive/read/observe call
```

### Browser packaging — one bundle for core + local store + transports

```ts
// @bandeira-tech/b3nd-web bundles core (Rig/connection), LocalStorageStore/MemoryStore,
// and HttpClient/WebSocketClient in one import. SaveClient/mapToBytes/BYTES_ENTITY (and
// IndexedDBStore) still come from @bandeira-tech/b3nd-save subpaths.
```
