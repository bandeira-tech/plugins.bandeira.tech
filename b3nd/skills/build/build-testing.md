# Build tests for a B3nd PIN

Sharing the `ProtocolInterfaceNode` interface does not mean shared behavior — a `MemoryStore` is a fast fixture, not a behavioral substitute for the real backend you'll ship on.

### 1. receive — assert per-slot ReceiveResult (partial batch success)

```ts
import { FunctionalClient, type ReceiveResult } from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const node = new FunctionalClient({
  receive: (msgs) =>
    Promise.resolve(
      msgs.map((_, i): ReceiveResult =>
        i % 2 === 0
          ? { accepted: false, error: "even-slot rejected" }
          : { accepted: true }
      ),
    ),
});

const results = await node.receive([
  ["mutable://a", 1],
  ["mutable://b", 2],
  ["mutable://c", 3],
]);

// batch never throws — inspect per-slot
assertEquals(results[0].accepted, false);
assertEquals(results[0].error, "even-slot rejected");
assertEquals(results[1].accepted, true);
assertEquals(results[2].accepted, false);
```

### 2. observe — drive a fixture stream, assert fired uris; abort and teardown

```ts
import { FunctionalClient } from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const client = new FunctionalClient({
  observe: async function* (_urls, signal) {
    if (signal.aborted) return;
    yield ["mutable://items/1", "mutable://items/2"] as const;
    yield ["mutable://items/3"] as const;
  },
});

const ac = new AbortController();
const fired: string[] = [];

for await (const uris of client.observe(["mutable://items/**"], ac.signal)) {
  fired.push(...uris);
  if (fired.length >= 3) ac.abort(); // loop exits cleanly on next iteration
}

assertEquals(fired, ["mutable://items/1", "mutable://items/2", "mutable://items/3"]);
```

### 3. fake backend — canned read responses (test a consumer before wiring the real store)

```ts
import { FunctionalClient, type Output } from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const fake = new FunctionalClient({
  read: <T = unknown>(urls: string[]): Promise<Output<T>[]> =>
    Promise.resolve(
      urls.map((u): Output<T> => [u, { name: "cached" } as T]),
    ),
  receive: (msgs) =>
    Promise.resolve(msgs.map(() => ({ accepted: true }))),
});

// consumer under test calls read — gets fixture data without a real store
const [[, payload]] = await fake.read(["mutable://items/1"]);
assertEquals((payload as { name: string }).name, "cached");
```

### 4. spy — capture what a flow dispatched (FunctionalClient as call recorder)

```ts
import {
  connection,
  FunctionalClient,
  Rig,
  type Output,
} from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const calls: Output[][] = [];
const spy = new FunctionalClient({
  receive: (msgs) => {
    calls.push(msgs);
    return Promise.resolve(msgs.map(() => ({ accepted: true })));
  },
});

const conn = connection(spy, ["mutable://**"]);
const rig = new Rig({ routes: { receive: [conn], read: [conn] } });

const op = rig.receive([["mutable://items/1", { name: "apple" }]]);
await op;           // pipeline ack
await op.settled;   // wait for background dispatch to backend

// assert on what the rig dispatched to the backend
assertEquals(calls.length, 1);
assertEquals(calls[0][0][0], "mutable://items/1");
```

### 5. beforeReceive gate — throw to reject

```ts
import {
  connection,
  FunctionalClient,
  Rig,
} from "@bandeira-tech/b3nd-core";
import { assertRejects } from "@std/assert";

const store = new FunctionalClient({
  receive: (msgs) => Promise.resolve(msgs.map(() => ({ accepted: true }))),
});
const conn = connection(store, ["mutable://**"]);

const rig = new Rig({
  routes: { receive: [conn], read: [conn] },
  hooks: {
    beforeReceive: (ctx) => {
      if (ctx.uri.includes("forbidden")) throw new Error("denied");
    },
  },
});

await assertRejects(
  () => rig.receiveOrThrow([["mutable://forbidden/x", {}]]),
  Error,
  "denied",
);
```

### 6. program gate — a truthy `.error` rejects

```ts
import {
  connection,
  FunctionalClient,
  Rig,
} from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const store = new FunctionalClient({
  receive: (msgs) => Promise.resolve(msgs.map(() => ({ accepted: true }))),
});
const conn = connection(store, ["mutable://**"]);

const rig = new Rig({
  routes: { receive: [conn], read: [conn] },
  programs: {
    "mutable://items": () =>
      Promise.resolve({ code: "reject", error: "policy violation" }),
  },
});

const [res] = await rig.receive([["mutable://items/x", {}]]);
assertEquals(res.accepted, false);
assertEquals(res.error, "policy violation");
```

### 7. handler gate — return `[]` to skip dispatch (pipeline still accepted)

```ts
import {
  connection,
  FunctionalClient,
  Rig,
} from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const store = new FunctionalClient({
  receive: (msgs) => Promise.resolve(msgs.map(() => ({ accepted: true }))),
});
const conn = connection(store, ["mutable://**"]);

const rig = new Rig({
  routes: { receive: [conn], read: [conn] },
  programs: {
    "mutable://items": () => Promise.resolve({ code: "ok" }),
  },
  handlers: {
    "ok": async (_out, _result, _read) => [], // no emissions → no dispatch
  },
});

const [h] = await rig.receive([["mutable://items/y", {}]]);
assertEquals(h.accepted, true);
```

### 8. contract test across backends — one suite, MemoryStore now; swap in Postgres later

```ts
import { SaveClient, mapToBytes } from "@bandeira-tech/b3nd-save/clients";
import { MemoryStore } from "@bandeira-tech/b3nd-save/memory";
import { BYTES_ENTITY } from "@bandeira-tech/b3nd-save";
import type { ProtocolInterfaceNode } from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

// MemoryStore applies multi-write batches non-atomically; a real backend may differ.
// push-down: MemoryStore walks the bucket in JS; a DB engine indexes

async function makeMemoryPin(): Promise<ProtocolInterfaceNode> {
  const store = new MemoryStore();
  await store.provisionEntity(store.entitySupport(BYTES_ENTITY));
  return new SaveClient(mapToBytes, BYTES_ENTITY, store);
}

// async function makePostgresPin(): Promise<ProtocolInterfaceNode> { ... }

function runPinContract(makePin: () => Promise<ProtocolInterfaceNode>) {
  Deno.test("contract: receive then read-back", async () => {
    const pin = await makePin();
    const [r] = await pin.receive([["mutable://x", new TextEncoder().encode("hi")]]);
    assertEquals(r.accepted, true);
    const [[, payload]] = await pin.read(["mutable://x"]);
    void payload; // assert the shape your consumers depend on
  });

  Deno.test("contract: batch receive — per-slot results", async () => {
    const pin = await makePin();
    const results = await pin.receive([
      ["mutable://a", new TextEncoder().encode("A")],
      ["mutable://b", new TextEncoder().encode("B")],
    ]);
    assertEquals(results.length, 2);
    assertEquals(results.every((r) => r.accepted), true);
  });
}

runPinContract(makeMemoryPin);
// runPinContract(makePostgresPin); // same suite, real backend
```

### 9. observability — inject a correlation id via a beforeSend hook

```ts
import {
  connection,
  FunctionalClient,
  Rig,
} from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

const store = new FunctionalClient({
  receive: (msgs) => Promise.resolve(msgs.map(() => ({ accepted: true }))),
});
const conn = connection(store, ["mutable://**"]);

const trace: { uri: string; correlationId: string }[] = [];

const rig = new Rig({
  routes: { receive: [conn], read: [conn] },
  hooks: {
    beforeSend: (ctx) => {
      trace.push({ uri: ctx.message[0] as string, correlationId: "req-001" });
    },
  },
});

const op = rig.send([["mutable://items/z", { v: 1 }]]);
await op;
// beforeSend runs synchronously in the pipeline before _pipelineDone resolves await op —
// trace is fully populated here; asserting inside a route:success handler is unsafe
// (handler throws are caught and logged, never reaching the test runner).
assertEquals(trace.length, 1);
assertEquals(trace[0].uri, "mutable://items/z");
assertEquals(trace[0].correlationId, "req-001");
await op.settled;
```
