# Build a B3nd Client, a Protocol Interface Node (PIN)

A PIN is anything implementing `ProtocolInterfaceNode` — `receive` / `read` /
`observe` / `status`. The smallest one is core-only and in-memory.

### The smallest node — core-only, in-memory

```ts
import {
  FunctionalClient,
  ObserveEmitter,
  type Output,
  type ProtocolInterfaceNode,
  type ReceiveResult,
} from "@bandeira-tech/b3nd-core";

const store = new Map<string, unknown>();

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
      bus.fire(uri);
      return { accepted: true };
    })),

  read: <T = unknown>(locs: string[]): Promise<Output<T>[]> =>
    Promise.resolve(
      locs.filter((l) => store.has(l))
        .map((l): Output<T> => [l, store.get(l) as T]),
    ),

  observe: (locs, signal) => bus.observe(locs, signal),

  status: () =>
    Promise.resolve({
      status: "healthy" as const,
      resources: { receive: ["mutable://"], read: ["mutable://"] },
    }),
});
```

### Calling it — just the four methods

```ts
// write
const [w] = await node.receive([["mutable://users/alice", { name: "Alice" }]]);
w.accepted; // true

// read — 1:1 with input, each result is [inputLocator, payload]
const [hit] = await node.read(["mutable://users/alice"]);
hit?.[1]; // { name: "Alice" }

// observe — abort to stop; read each changed uri for its state
const abort = new AbortController();
for await (const uris of node.observe(["mutable://users/**"], abort.signal)) {
  for (const [uri, payload] of await node.read([...uris])) handle(uri, payload);
}
```

### No `FunctionalClient` needed — any object with the four methods is a PIN

```ts
const raw: ProtocolInterfaceNode = {
  receive: (msgs) => Promise.resolve(msgs.map(() => ({ accepted: true }))),
  read: (locs) => Promise.resolve([]),
  observe: async function* (_locs, _signal) {},
  status: () => Promise.resolve({ status: "healthy" }),
};
```
