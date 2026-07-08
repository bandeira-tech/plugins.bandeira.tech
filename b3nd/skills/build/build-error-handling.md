# Build Error Handling for B3nd PINs to deliver the experience you need

The PIN return types and throw expectations carry every affordance you need to build the error handling your operations require. Read the code; wire your own policy.

## Handling errors on Protocol Interface Node API

`receive` returns problems as data (one `ReceiveResult` per message). `read` / `observe` / `status` throw transport/programmer errors and encode domain outcomes in the payload.

### import — the structured error surface

```ts
import {
  type B3ndError, // { code, message, uri?, details? }
  ClientError,
  ErrorCode, // UNAUTHORIZED FORBIDDEN INVALID_URI INVALID_SCHEMA INVALID_SEQUENCE NOT_FOUND CONFLICT STORAGE_ERROR INTERNAL_ERROR
  Errors, // constructors: Errors.notFound(uri), Errors.forbidden(uri), ...
  type ReceiveResult,
} from "@bandeira-tech/b3nd-core";
```

### receive — errors returned per message, not thrown

```ts
const results = await node.receive([
  ["mutable://users/alice", { name: "Alice" }],
  ["mutable://users/bob", { name: "Bob" }],
]);

for (const r of results) {
  if (r.accepted) continue;
  switch (r.errorDetail?.code) { // prefer the code over parsing r.error
    case ErrorCode.UNAUTHORIZED:
    case ErrorCode.FORBIDDEN:
      /* caller lacks rights for this uri */ break;
    case ErrorCode.CONFLICT:
      /* sequence/version clash — retry with fresh state */ break;
    default:
      console.error(r.error ?? "rejected");
  }
}
```

### receive (authoring) — populate both fields so callers pick their level

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

### read — throws transport/programmer errors; a miss is data

```ts
try {
  const outs = await node.read(["mutable://users/alice"]);
  const hit = outs.find(([loc]) => loc === "mutable://users/alice");
  if (!hit) {
    /* this node's convention: miss = absent Output */
  } else {
    const [, payload] = hit;
    // interpret payload per the client's contract (may itself carry a miss/error shape)
  }
} catch (err) {
  // transport / programmer error — no route, network, bad grammar
  if (err instanceof ClientError) console.error(err.code, err.message);
  throw err;
}
```

### observe — throws on setup; stream carries no error channel

```ts
const abort = new AbortController();
try {
  for await (const uris of node.observe(["mutable://users/**"], abort.signal)) {
    const outs = await node.read([...uris]); // read errors handled as above
    for (const [uri, payload] of outs) handle(uri, payload);
  }
} catch (err) {
  console.error("observe setup/transport failed", err); // re-subscribe for resilience
} finally {
  abort.abort();
}
```

### status — the probe itself; degraded/unhealthy is the return, not a throw

```ts
try {
  const s = await node.status(); // "healthy" | "degraded" | "unhealthy"
  if (s.status !== "healthy") console.warn(s.status, s.message);
  // s.resources?.receive / .read / .observe → uri prefixes this node serves
} catch {
  // couldn't reach the node — strictly worse than "unhealthy"
}
```

## Handling errors on B3nd Rig

The Rig is a `ProtocolInterfaceNode`, so the PIN rules hold — but `send`/`receive` return an `OperationHandle` (awaitable `PromiseLike<ReceiveResult[]>` **and** a scoped emitter). Stage rejections come back as `accepted: false` and as events; only a thrown hook rejects the await itself.

### import — the rig error surface

```ts
import {
  type OperationHandle,
  type ReceiveResult,
  Rig,
} from "@bandeira-tech/b3nd-core";
```

### send / receive — three outcome layers: ack vs. events vs. settled

```ts
const op = rig.send([["mutable://app/state", { value: 42 }]]);

// 1. Pipeline ack — process + handle decided. Batch never throws here;
//    a rejected tuple (incl. "No connection accepts receive for <uri>")
//    is { accepted: false, error }; siblings still proceed.
const results = await op;
if (!results[0].accepted) console.error(results[0].error);

// 2. Per-route / per-stage events — dispatch runs in background AFTER the ack.
op.on("process:error", (e) => log(e.input, e.error, e.errorDetail));
op.on("handle:error", (e) => log(e.input, e.error, e.cause));
op.on("route:error", (e) => retry(e.emission, e.connectionId, e.errorDetail));
op.on("route:success", (e) => mark(e.emission, e.connectionId));
op.on("reaction:error", (e) => log(e.pattern, e.error));

// 3. Settled — every background route has answered (read-after-write).
await op.settled; // rejects only if a hook threw
```

### send / receive — throw-on-rejection convenience

```ts
await rig.receiveOrThrow(outs); // throws on the first accepted:false tuple
await rig.sendOrThrow(outs);
```

### read — throws on no-route/transport; emits read:error; miss is data

```ts
try {
  const outs = await rig.read(["mutable://users/alice"]);
  // domain "not found" rides in the payload — treat absence as data
} catch (err) {
  // "No read route accepts <loc>" (config) or client threw (transport);
  // rig emitted a read:error event per locator before re-throwing.
  throw err;
}
```

### observe — resilient merge; per-source errors are swallowed

```ts
const abort = new AbortController();
// One broken source does NOT tear down the merged stream — you simply
// stop receiving its uris (no exception). Track liveness yourself if needed.
for await (const uris of rig.observe(["mutable://app/**"], abort.signal)) {
  for (const uri of uris) handle(uri);
}
abort.abort();
```

### status — aggregates; degraded/unhealthy is a value, not a throw

```ts
const s = await rig.status();
// any client unhealthy → "unhealthy"; else any degraded → "degraded"; else "healthy".
// s.resources is derived from the rig's own route table, not downstream nodes.
// A throw means a client's own status() threw (unreachable).
```

### Programs — return an error to reject a tuple; throws are isolated per-tuple

```ts
const rig = new Rig({
  routes: { receive: [node] },
  programs: {
    "store://balance": async (out, _upstream, read) => {
      if (/* your check */ false) {
        return { code: "rejected", error: "insufficient funds" };
        // → accepted:false, process:error event, onError phase:"process"
      }
      return { code: "ok" }; // reserve throws for genuine faults (isolated per-tuple)
    },
  },
});
```

### Handlers — throwing rejects the tuple; `[]` refuses without error

```ts
const rig = new Rig({
  routes: { receive: [node] },
  handlers: {
    "app:valid": async (out, _result, _read) => {
      if (/* fault */ false) throw new Error("boom");
      // → catches, emits handle:error {input,classification,error,cause},
      //   accepted:false, receive:error/send:error event, onError phase:"handle"
      return [out]; // return [] to refuse / observe-only — a valid outcome, not an error
    },
  },
});
```

### Hooks — before throws to reject; after can throw; onError can abort

```ts
const rig = new Rig({
  routes: { receive: [node] },
  hooks: {
    // Before-hook: throw is the rejection mechanism (rejects await op / propagates out of rig.read).
    beforeReceive: (ctx) => { if (!ok(ctx.uri)) throw new Error("denied"); },
    // Return void to proceed; return { ctx } to rewrite the tuple/locator.
    beforeSend: (ctx) => ({ ctx: { message: rewrite(ctx.message) } }),
    // After-hook: observes, may throw to enforce a post-condition (propagates).
    afterRead: (ctx, result) => { audit(ctx.url, result); },
    // onError: fires in the catch path for every process/handle/route/reaction error.
    onError: (ctx) => {
      // ctx.phase, ctx.input, + per-phase extras: emission, connectionId,
      //   classification, pattern, errorDetail, cause
      if (ctx.phase === "route") return; // return → rig continues (accepted:false, *:error fires, siblings proceed)
      throw new Error(`abort: ${ctx.error}`); // throw → rejects await op AND op.settled, stops scheduling new routes/reactions
    },
  },
});
```

### Events — fire-and-forget; handler errors never propagate

```ts
const rig = new Rig({
  routes: { receive: [node] },
  on: {
    "send:success": [(e) => audit(e.uri)],
    "receive:error": [(e) => alert(e.uri, e.error)],
    "*:error": [(e) => metrics(e.op)], // wildcards fire for all ops
  },
});
// A throw inside a handler is caught → onHandlerError listener, else console.warn.
// It can never break the operation. Use hooks (not events) for control flow.
rig.on("read:error", (e) => log(e.uri, e.error)); // runtime registration
await Promise.allSettled(rig.drain()); // await in-flight handlers before exit
```

### Reactions — observers, not blockers

```ts
const rig = new Rig({
  routes: { receive: [node] },
  reactions: {
    "mutable://app/users/*": async (out, _read) => {
      if (/* fault */ false) throw new Error("boom");
      // → caught: emits reaction:error, onError phase:"reaction";
      //   the triggering operation is UNAFFECTED.
      const id = out[0].split("/").pop();
      return [[`notify://email/${id}`, { kind: "user-updated" }]];
      // returned tuples spawn a FRESH rig.send (own handle);
      // that spawned op's rejections are swallowed (console.warn).
    },
  },
});
```

## Handling errors on @bandeira-tech/b3nd-move HTTP, WS, MCP clients

## Handling errors on @bandeira-tech/b3nd-save clients
