# Build Error Handling for B3nd PINs to deliver the experience you need

B3nd PIN interface and the return types and throw expectations should provide
all affordances you need to build the right error handling for your operations.

## Handling errors on Protocol Interface Node API

The PIN interface splits errors two ways. **`receive` returns problems as
data** — one result per message. **`read` / `observe` / `status` throw** for
transport and programmer errors; anything domain-level ("not found", auth
refusal) is encoded in the payload per the client's convention, never thrown.

The structured pieces you'll use:

```ts
import {
  type B3ndError,
  ClientError,
  ErrorCode, // enum: UNAUTHORIZED, FORBIDDEN, INVALID_URI, INVALID_SCHEMA,
  //         INVALID_SEQUENCE, NOT_FOUND, CONFLICT, STORAGE_ERROR, INTERNAL_ERROR
  Errors, // convenience constructors: Errors.notFound(uri), Errors.forbidden(uri), ...
  type ReceiveResult,
} from "@bandeira-tech/b3nd-core";
```

### receive — errors are returned, not thrown

`receive(msgs)` resolves to one `ReceiveResult` per input message, in order:

```ts
interface ReceiveResult {
  accepted: boolean;
  error?: string; // human string (kept for compatibility)
  errorDetail?: B3ndError; // structured: { code, message, uri?, details? }
}
```

A message can be rejected without the whole batch failing — inspect each
result. Prefer `errorDetail.code` (an `ErrorCode`) over parsing the string:

```ts
const results = await node.receive([
  ["mutable://users/alice", { name: "Alice" }],
  ["mutable://users/bob", { name: "Bob" }],
]);

for (const r of results) {
  if (r.accepted) continue;
  switch (r.errorDetail?.code) {
    case ErrorCode.UNAUTHORIZED:
    case ErrorCode.FORBIDDEN:
      // caller lacks rights for this uri
      break;
    case ErrorCode.CONFLICT:
      // e.g. sequence/version clash — retry with fresh state
      break;
    default:
      console.error(r.error ?? "rejected");
  }
}
```

When you author a node, populate both fields so callers can choose their
level: set `error` to a string and build `errorDetail` with an `Errors`
constructor.

```ts
receive: (msgs) =>
  Promise.resolve(msgs.map(([uri]) => {
    if (!allowed(uri)) {
      const detail = Errors.forbidden(uri);
      return { accepted: false, error: detail.message, errorDetail: detail };
    }
    return { accepted: true };
  })),
```

### read — throws transport/programmer errors, encodes the rest

`read(locators)` is 1:1 with input and returns `Output<T>[]`. The interface
contract is explicit: **transport / programmer errors throw** (network down,
no route accepts a locator, a grammar violation the client rejects).
Everything domain-level is in the payload, on the client's terms — a miss
might be an absent entry, or a present `[locator, undefined]`, or a
`[locator, { error: ... }]`. That convention is agreed out-of-band, so read
the target client's contract; don't assume.

```ts
try {
  const outs = await node.read(["mutable://users/alice"]);
  const hit = outs.find(([loc]) => loc === "mutable://users/alice");
  if (!hit) {
    // this node's convention: miss = absent Output
  } else {
    const [, payload] = hit;
    // interpret payload per the client's contract (may itself carry a miss/error shape)
  }
} catch (err) {
  // transport or programmer error — no route, network, bad grammar
  if (err instanceof ClientError) console.error(err.code, err.message);
  throw err;
}
```

Because absence and error are distinct here — a miss is *data*, a broken
route is a *throw* — never treat an empty result as failure.

### observe — throws on setup, then a long-lived stream

`observe(locators, signal)` returns an `AsyncIterable<readonly string[]>`.
Setup problems (no route accepts the pattern, transport unavailable) surface
as a throw when you start iterating — wrap the `for await`. The stream itself
yields batches of concrete uris that changed; it carries no error channel of
its own. Stop it by aborting the signal, and use `finally` to clean up.

```ts
const abort = new AbortController();
try {
  for await (const uris of node.observe(["mutable://users/**"], abort.signal)) {
    const outs = await node.read([...uris]); // read errors handled as above
    for (const [uri, payload] of outs) handle(uri, payload);
  }
} catch (err) {
  // subscription/transport failure
  console.error("observe failed", err);
} finally {
  abort.abort();
}
```

A dropped connection on a transport-backed node surfaces as the iterator
throwing; re-subscribe if you need resilience.

### status — throws only on transport failure

`status()` resolves to a `StatusResult` and is the health probe itself, so
degraded/unhealthy states are **not** errors — they're the return value.
`status.status` is `"healthy" | "degraded" | "unhealthy"`; a `message` and
per-verb `resources` may accompany it. A thrown error from `status()` means
the node is unreachable (transport failure), which is strictly worse than an
`"unhealthy"` result.

```ts
try {
  const s = await node.status();
  if (s.status !== "healthy") console.warn(s.status, s.message);
  // s.resources?.receive / .read / .observe → uri prefixes this node serves
} catch {
  // couldn't even reach the node — treat as fully down
}
```

## Handling errors on B3nd Rig

The Rig is itself a `ProtocolInterfaceNode`, so the PIN rules above still
apply — but `send` and `receive` are richer. They return an
`OperationHandle`, which is **both** an awaitable `PromiseLike<ReceiveResult[]>`
and a scoped event emitter. A single write can fail at several distinct
stages (before-hook, program, handler, per-route dispatch, reaction), and the
Rig surfaces each differently. The rule of thumb: **stage rejections come back
as `accepted: false` in the awaited results and as events; only a thrown hook
turns the await itself into a rejection.**

```ts
import {
  type OperationHandle,
  type ReceiveResult,
  Rig,
} from "@bandeira-tech/b3nd-core";
```

### send / receive — awaited result vs. events vs. settled

```ts
const op = rig.send([["mutable://app/state", { value: 42 }]]);

const results = await op; // pipeline-stage ack: process + handle finished
if (!results[0].accepted) console.error(results[0].error);

await op.settled; // all background route dispatch has settled
```

Three layers of outcome, each with its own error surface:

1. **Pipeline ack (`await op`).** Resolves to one `ReceiveResult` per input
   tuple once `process` + `handle` decide what to dispatch. A tuple that is
   rejected at process/handle time comes back `{ accepted: false, error }` —
   the batch does **not** throw; other tuples still proceed. Structural misses
   ("No connection accepts receive for `<uri>`") land here too, as
   `accepted: false`.
2. **Per-stage / per-route events (`op.on(...)`).** Dispatch to connections
   runs in the background *after* the ack, so route outcomes only appear as
   events:

   ```ts
   op.on("process:error", (e) => log(e.input, e.error, e.errorDetail));
   op.on("handle:error", (e) => log(e.input, e.error, e.cause));
   op.on("route:error", (e) =>
     retry(e.emission, e.connectionId, e.errorDetail));
   op.on("route:success", (e) => mark(e.emission, e.connectionId));
   op.on("reaction:error", (e) => log(e.pattern, e.error));
   ```

   A per-route failure (a connection's `receive` returned `accepted: false`,
   or its client threw) is reported as a `route:error` event, **not** by
   rejecting the await — the pipeline already acked. Use `op.settled` (or
   subscribe to `route:*`) if you need read-after-write across replicas.
3. **The await rejects only when a hook throws.** A `beforeSend` /
   `beforeReceive` throw, or an `onError` hook that re-throws, rejects the
   pipeline promise — `await op` and `await op.settled` both reject with that
   value.

If you don't want to inspect `accepted`, use the throw-on-rejection
convenience wrappers:

```ts
await rig.receiveOrThrow(outs); // throws on the first accepted:false tuple
await rig.sendOrThrow(outs);
```

### read — throws; emits read:error

`rig.read(locators)` routes each locator to the first connection that accepts
it. It **throws** if no route accepts a locator (`No read route accepts <loc>`
— a programmer/config error) or if the underlying client throws (transport).
On throw it emits a `read:error` rig event per locator, then re-throws.
Domain-level "not found" is not an error here — it rides in the payload, same
as the bare-PIN contract. Wrap `read` in try/catch; treat absence as data.

### observe — resilient stream; per-source errors are swallowed

`rig.observe(locators, signal)` groups locators by accepting connection and
merges their streams. By design **one broken source does not tear down the
merged stream** — per-stream errors are swallowed internally so a single flaky
peer can't kill your subscription. That means you won't get an exception when
one upstream drops; you simply stop receiving its uris. If you need liveness
guarantees, track them yourself (heartbeat uris, `status()` polling) rather
than relying on the stream to throw. Abort the signal to stop; clean up in
`finally`.

### status — aggregates, doesn't throw on degraded

`rig.status()` aggregates health across all connected clients: if any is
`unhealthy` the rig reports `unhealthy`, else if any is `degraded` it reports
`degraded`, else `healthy`. `resources` is derived from the rig's own route
table (the per-verb connection patterns), not from downstream nodes. As with a
bare PIN, a degraded/unhealthy *result* is not an error — a throw means a
client's `status()` itself threw (unreachable).

### Programs — classify; return an error to reject a tuple

A `Program` is a pure classifier returning `{ code, error? }`. If it returns
an `error` string, the Rig rejects that tuple: `accepted: false`, a
`process:error` event, and the `onError` hook fires with `phase: "process"`.
If a program **throws**, the Rig isolates it per-tuple — the thrown message
becomes that tuple's error; the rest of the batch is unaffected. So prefer
returning a code/error for expected classification outcomes and reserve throws
for genuine faults.

### Handlers — throwing rejects the tuple

A `CodeHandler` returns the `Output[]` to dispatch. If it throws, the Rig
catches it, emits `handle:error` (with `input`, `classification`, `error`,
`cause`), records `accepted: false`, fires the `receive:error`/`send:error`
event and the `onError` hook with `phase: "handle"`. It does not fail sibling
tuples. Returning `[]` is a valid "refuse / observe-only" outcome, not an
error.

### Hooks — before throws to reject, after can throw, onError can abort

- **Before-hooks (`beforeSend`/`beforeReceive`/`beforeRead`) throw to reject.**
  A throw here is the rejection mechanism — it rejects the pipeline promise
  (`await op` rejects) for send/receive, and propagates out of `rig.read` for
  reads. Return `void` to proceed, or `{ ctx }` to rewrite the tuple/locator.
- **After-hooks observe** and cannot modify the result, but may throw to
  enforce a post-condition (which propagates).
- **`onError` hook** fires synchronously in the catch path for every
  `process`/`handle`/`route`/`reaction` error. **Throw from it to abort** the
  whole operation (rejects `await op` and `op.settled`, stops scheduling new
  routes/reactions); **return** to let the rig continue with normal handling
  (that tuple is `accepted: false`, the `*:error` event fires, siblings
  proceed). Use it for fail-fast batch policies or to convert specific phases
  into application exceptions. Its `ctx` carries `phase`, `input`, and
  per-phase extras (`emission`, `connectionId`, `classification`, `pattern`,
  `errorDetail`, `cause`).

### Events — fire-and-forget; handler errors never propagate

Rig events (`send:success`, `receive:error`, `read:success`, the `*:success`/
`*:error` wildcards) run asynchronously *after* the operation and never block
or fail the caller. An error thrown inside an event handler is caught and
routed to any `onHandlerError` listener, falling back to `console.warn` — it
can never break the operation. Don't rely on event handlers for control flow;
use hooks (which can reject) for that. `rig.drain()` returns in-flight handler
promises if you need to await them before exit.

### Reactions — observers, not blockers

Reactions fire after an emission's routes settle (only if at least one route
accepted). A reaction that **throws** is caught: the Rig emits `reaction:error`
and fires `onError` with `phase: "reaction"`, but the triggering operation is
unaffected. Reaction return tuples are dispatched through a **fresh**
`rig.send` with its own handle; that spawned op's rejections are swallowed
(logged via `console.warn`) — reactions are productive observers, never
blockers of the operation that triggered them. Reaction loops are a usage
error, not something the rig guards against.

## Handling errors on @bandeira-tech/b3nd-move HTTP, WS, MCP clients

## Handling errors on @bandeira-tech/b3nd-save clients


