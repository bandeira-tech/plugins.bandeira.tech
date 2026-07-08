# Build a B3nd Client, a Protocol Interface Node (PIN)

A PIN is anything implementing `ProtocolInterfaceNode` — `receive` / `read` /
`observe` / `status`. Grow one a verb at a time with `FunctionalClient`:
implement only the verbs you need; omitted ones fall back to safe defaults (an
unimplemented `receive` rejects, `read`/`observe` return empty, `status`
reports healthy).

### 1. receive — a write-only PIN

```ts
import {
  FunctionalClient,
  type Output,
  type ReceiveResult,
} from "@bandeira-tech/b3nd-core";

const store = new Map<string, unknown>();

// setup — implement just receive
const node = new FunctionalClient({
  receive: (msgs: Output[]): Promise<ReceiveResult[]> =>
    Promise.resolve(msgs.map(([uri, payload]) => {
      store.set(uri, payload);
      return { accepted: true };
    })),
});

// use
const [w] = await node.receive([["mutable://users/alice", { name: "Alice" }]]);
w.accepted; // true
```

### 2. add read — answer queries, 1:1 with input

```ts
const node = new FunctionalClient({
  receive: (msgs: Output[]): Promise<ReceiveResult[]> =>
    Promise.resolve(msgs.map(([uri, payload]) => {
      store.set(uri, payload);
      return { accepted: true };
    })),
  // each result echoes the input locator as its first element; misses are absent
  read: <T = unknown>(locs: string[]): Promise<Output<T>[]> =>
    Promise.resolve(
      locs.filter((l) => store.has(l)).map((l): Output<T> => [l, store.get(l) as T]),
    ),
});

// use
await node.receive([["mutable://users/alice", { name: "Alice" }]]);
const [hit] = await node.read(["mutable://users/alice"]);
hit?.[1]; // { name: "Alice" }
```

### 3. add observe — stream uris as they change

```ts
import { ObserveEmitter } from "@bandeira-tech/b3nd-core";

// the emitter is the listener / async-iterator machinery; fire it on each write
class Bus extends ObserveEmitter {
  fire(uri: string) {
    this._emit(uri, null);
  }
}
const bus = new Bus();

const node = new FunctionalClient({
  receive: (msgs: Output[]): Promise<ReceiveResult[]> =>
    Promise.resolve(msgs.map(([uri, payload]) => {
      store.set(uri, payload);
      bus.fire(uri); // emit on successful write
      return { accepted: true };
    })),
  read: <T = unknown>(locs: string[]): Promise<Output<T>[]> =>
    Promise.resolve(
      locs.filter((l) => store.has(l)).map((l): Output<T> => [l, store.get(l) as T]),
    ),
  observe: (locs, signal) => bus.observe(locs, signal),
});

// use — abort to stop; read each changed uri for its state
const abort = new AbortController();
for await (const uris of node.observe(["mutable://users/**"], abort.signal)) {
  for (const [uri, payload] of await node.read([...uris])) handle(uri, payload);
}
```

### 4. status — advertise health + what you serve

```ts
const node = new FunctionalClient({
  // ...the verbs you implemented above...
  status: () =>
    Promise.resolve({
      status: "healthy" as const,
      // resources: uri prefixes you serve, per verb — used for discovery
      resources: { receive: ["mutable://"], read: ["mutable://"] },
    }),
});

// use
const s = await node.status();
s.status; // "healthy" | "degraded" | "unhealthy"
```
