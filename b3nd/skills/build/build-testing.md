# Build tests for a B3nd PIN — verify behavior, not just shape

Contract-test a PIN against the verbs it implements, and against the *real*
backend it will run on. Reach for this guide when your tests need to assert
dispatch, rejection, or observability behavior (see the Warden + Defensive stance).

### RecordingClient — capture what the framework dispatched

```ts
// RecordingClient is a workspace-internal test helper (not published).
// Import via a relative or workspace-alias path — not a JSR specifier.
import { RecordingClient } from "../../src/testing/recording-client.ts";
import { Rig, connection } from "@bandeira-tech/b3nd-core";
import { assertEquals } from "@std/assert";

// Wire it behind a Rig and exercise your flow.
const client = new RecordingClient();
const rig = new Rig({
  routes: { receive: [connection(client, ["mutable://**"])], read: [connection(client, ["mutable://**"])] },
});

await rig.receive([["mutable://items/1", { name: "apple" }]]);
await rig.read(["mutable://items/1"]);

// Assert on dispatch — what the framework sent, not what the backend stored.
assertEquals(client.callsOf("receive").length, 1);
assertEquals(client.callsOf("receive")[0].msgs[0][0], "mutable://items/1");
assertEquals(client.callsOf("read")[0].urls, ["mutable://items/1"]);
```

### RecordingClient fixtures — supply canned responses

```ts
import type { Output } from "@bandeira-tech/b3nd-core";

// Override any subset of verbs; the rest fall back to sensible defaults:
// receive → { accepted: true }, read → [url, undefined], observe → empty stream, status → healthy.
const client = new RecordingClient({
  read: (urls) => urls.map((u): Output => [u, { name: "cached" }]),
  receive: (msgs) =>
    msgs.map((_, i) => i === 0 ? { accepted: false, error: "duplicate" } : { accepted: true }),
});

// client.reset() clears calls without touching fixtures — useful between sub-tests.
client.reset();
```

### Contract test — one suite, multiple real backends (Warden move)

```ts
import { SaveClient, mapToBytes } from "@bandeira-tech/b3nd-save/clients";
import { MemoryStore } from "@bandeira-tech/b3nd-save/memory";
import { BYTES_ENTITY } from "@bandeira-tech/b3nd-save";
import type { ProtocolInterfaceNode } from "@bandeira-tech/b3nd-core";

// The Warden stance: a PIN behind your interface, tested against every backend
// you'll ship. MemoryStore is fast but not a behavioral guarantee of PostgresStore.
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
    // backend-specific payload shape — check the contract your consumers depend on
    /* your assertion */
    void payload;
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

### MemoryStore for fast unit tests vs. real backend for truth

```ts
import { SaveClient, mapToBytes } from "@bandeira-tech/b3nd-save/clients";
import { MemoryStore } from "@bandeira-tech/b3nd-save/memory";
import { BYTES_ENTITY } from "@bandeira-tech/b3nd-save";

// MemoryStore: zero setup, synchronous semantics — iterate quickly on business logic.
const mem = new MemoryStore();
await mem.provisionEntity(mem.entitySupport(BYTES_ENTITY));
const fastPin = new SaveClient(mapToBytes, BYTES_ENTITY, mem);

// Where MemoryStore diverges from a real backend:
//  - atomicBatch: false — multi-write batches are NOT atomic; Postgres is.
//  - push-down: MemoryStore walks the bucket in JS; a DB engine indexes.
```

### receive — assert per-slot ReceiveResult (partial batch success)

```ts
import { FunctionalClient, type ReceiveResult } from "@bandeira-tech/b3nd-core";

// Build a PIN that rejects even-index messages.
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

// Batch never throws — inspect per-slot.
assertEquals(results[0].accepted, false);
assertEquals(results[0].error, "even-slot rejected");
assertEquals(results[1].accepted, true);
assertEquals(results[2].accepted, false);
```

### observe — drive a stream, assert fired uris; abort and teardown

```ts
import { RecordingClient } from "../../src/testing/recording-client.ts";

// Fixture: emit two batches then stop.
const client = new RecordingClient({
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
  if (fired.length >= 3) ac.abort(); // teardown — loop exits cleanly on next iteration
}

assertEquals(fired, ["mutable://items/1", "mutable://items/2", "mutable://items/3"]);
assertEquals(client.callsOf("observe")[0].urls, ["mutable://items/**"]);
```

### beforeReceive / program / handler gates — assert rejection paths

```ts
import { Rig, connection, FunctionalClient } from "@bandeira-tech/b3nd-core";
import { assertRejects } from "@std/assert";

const store = new FunctionalClient({
  receive: (msgs) => Promise.resolve(msgs.map(() => ({ accepted: true }))),
});
const conn = connection(store, ["mutable://**"]);

// beforeReceive hook — throw is the rejection mechanism; rejects the await.
const rig = new Rig({
  routes: { receive: [conn], read: [connection(store, ["mutable://**"])] },
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

// Program gate — a truthy `programResult.error` causes accepted:false; code value is irrelevant.
// Program key must prefix-match the URI: uri === key or uri.startsWith(key + "/").
const rigWithProgram = new Rig({
  routes: { receive: [conn], read: [connection(store, ["mutable://**"])] },
  programs: {
    "mutable://items": () => Promise.resolve({ code: "reject", error: "policy violation" }),
  },
});

const [result] = await rigWithProgram.receive([["mutable://items/x", {}]]);
assertEquals(result.accepted, false);
assertEquals(result.error, "policy violation");

// Handler gate — return [] to skip dispatch; pipeline still acks accepted:true.
const rigWithHandler = new Rig({
  routes: { receive: [conn], read: [connection(store, ["mutable://**"])] },
  programs: {
    "mutable://items": () => Promise.resolve({ code: "ok" }),
  },
  handlers: {
    "ok": async (_out, _result, _read) => [], // no emissions → dispatch skipped
  },
});

const [h] = await rigWithHandler.receive([["mutable://items/y", {}]]);
assertEquals(h.accepted, true); // [] from handler → dispatch skipped, pipeline accepted
```

### Observability — correlate a flow via hooks and on-handle events

```ts
import { Rig, connection } from "@bandeira-tech/b3nd-core";
import { RecordingClient } from "../../src/testing/recording-client.ts";

// Inject a correlation id in beforeReceive; pick it up in on-handle events.
const client = new RecordingClient();
const conn = connection(client, ["mutable://**"]);
const trace: { uri: string; correlationId: string }[] = [];

const rig = new Rig({
  routes: { receive: [conn], read: [connection(client, ["mutable://**"])] },
  hooks: {
    beforeReceive: (ctx) => {
      // Attach to the URI or to a side-channel your test controls.
      trace.push({ uri: ctx.uri, correlationId: "req-001" });
    },
  },
});

const op = rig.receive([["mutable://items/z", { v: 1 }]]);
op.on("route:success", (e) => {
  // e.emission is the dispatched Output; correlate via the trace side-channel.
  assertEquals(trace[0].uri, e.emission[0]);
});

await op;
await op.settled;
```
