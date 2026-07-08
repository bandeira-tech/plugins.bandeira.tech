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

/CONTINUE one session for each send/receive/read/observe/status
/CONTINUE one session for each hooks, events, programs, handlers

## Handling errors on @bandeira-tech/b3nd-move HTTP, WS, MCP clients

## Handling errors on @bandeira-tech/b3nd-save clients


