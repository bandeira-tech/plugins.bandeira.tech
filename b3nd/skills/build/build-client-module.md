# Build a B3nd Client, a Protocol Interface Node (PIN)

To start building composable, portable and reusable modules with b3nd, you
use the universal interface for modules, the B3nd PIN, or Protocol Interface Node.

B3nd components are called this way because they are nodes to a system where
opaque information protocols gain an interface with compute nodes.

## The interface

A PIN is anything that implements `ProtocolInterfaceNode` — four primitives:

- `receive(msgs)` — state changes (writes), each addressed by a **uri**
- `read(locators)` — queries, each addressed by a **locator**
- `observe(locators, signal)` — stream of uris that changed
- `status()` — health + capabilities

That's the whole contract. A message is an `Output`: a `[uri, payload]`
tuple. The framework treats `payload` as opaque — what a write means, what a
"miss" looks like on read, what grammar a locator follows, are all your
client's business.

## The smallest thing that IS a PIN

You don't need a class, a transport, or a rig. The simplest way to stand up a
PIN is `FunctionalClient`: give it the functions you have, and it fills in
sensible defaults for the ones you don't. Here's a complete, core-only,
in-memory node with all four primitives:

```ts
import {
  FunctionalClient,
  ObserveEmitter,
  type Output,
  type ReceiveResult,
} from "@bandeira-tech/b3nd-core";

const store = new Map<string, unknown>();

// ObserveEmitter is the shared listener/async-iterator machinery.
// We call its protected _emit on each successful write via a subclass.
class Bus extends ObserveEmitter {
  emit(uri: string) {
    this._emit(uri, null);
  }
}
const bus = new Bus();

const node = new FunctionalClient({
  // receive: persist each [uri, payload], return one result per message.
  receive: (msgs: Output[]): Promise<ReceiveResult[]> => {
    const results = msgs.map(([uri, payload]) => {
      store.set(uri, payload);
      bus.emit(uri);
      return { accepted: true };
    });
    return Promise.resolve(results);
  },

  // read: one Output per hit, in input order. Misses are simply absent —
  // that's this node's chosen convention (the framework defines none).
  read: <T = unknown>(locators: string[]): Promise<Output<T>[]> => {
    const out: Output<T>[] = [];
    for (const loc of locators) {
      if (store.has(loc)) out.push([loc, store.get(loc) as T]);
    }
    return Promise.resolve(out);
  },

  // observe: hand the emitter the caller's patterns + abort signal.
  observe: (locators, signal) => bus.observe(locators, signal),

  // status: health + which uri prefixes we serve, per verb.
  status: () =>
    Promise.resolve({
      status: "healthy" as const,
      resources: {
        receive: ["mutable://"],
        read: ["mutable://"],
        observe: ["mutable://"],
      },
    }),
});
```

Calling it is just the four methods:

```ts
// write
const [w] = await node.receive([["mutable://users/alice", { name: "Alice" }]]);
console.log(w.accepted); // true

// read (1:1 with input; each result is [inputLocator, payload])
const [hit] = await node.read(["mutable://users/alice"]);
console.log(hit?.[1]); // { name: "Alice" }

// observe (abort to stop; read each uri to learn its state)
const abort = new AbortController();
(async () => {
  for await (const uris of node.observe(["mutable://users/**"], abort.signal)) {
    const outs = await node.read([...uris]);
    for (const [uri, payload] of outs) console.log("changed", uri, payload);
  }
})();

await node.receive([["mutable://users/bob", { name: "Bob" }]]); // fires observe
abort.abort();
```

That is a fully working Protocol Interface Node built with nothing but
`b3nd-core`. Every other client — HTTP, WebSocket, Postgres, the Rig itself —
implements this same four-method interface, which is what lets them compose.

Notes on the shape:

- `read` is **1:1 with input order** and each result echoes the caller's
  locator as the first tuple element, so results pair positionally.
- Omit any config function and `FunctionalClient` supplies a default:
  `receive` → `{ accepted: false, error: "not implemented" }`, `read` → empty
  (absence), `observe` → empty stream, `status` → `{ status: "healthy" }`.
- If you'd rather not use `FunctionalClient`, any object with those four
  method signatures satisfies `ProtocolInterfaceNode` just as well.
