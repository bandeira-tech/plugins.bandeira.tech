# PROGRAMS — pure classifiers

A **program** is a pure async classifier keyed on a URI prefix. The rig matches each incoming `[uri, payload]` against its prefix table, hands the message to the program registered there, and gets back one verdict: a **code**. The program does not store, does not transform, does not call out. It looks at the message — possibly reads confirmed state to decide — and returns one short string that says *what this message is*.

Programs are half of a protocol's contract. The other half is [HANDLERS.md](./HANDLERS.md), which turns codes into the tuples the rig will dispatch. Read them in order if you can.

## The contract

A program is a pure async function. Its inputs:

- the `[uri, payload]` being classified
- the parent output that produced this one (when applicable — e.g. when classifying a sub-write from a decomposition)
- a `read` lookup the program can use to consult confirmed state

Its output is a single `ProgramResult`: one `code: string`, plus an optional `error` message for human consumption when refusing. **One classification per call. One code.** If you find yourself wanting to emit two codes for one message, you don't — emit a single code whose handler returns multiple outputs.

What programs do not do (PROTOCOL.md is explicit on this):

- **Store data.** Persisting is the rig's job. A program cannot write.
- **Mutate global state.** No counters, no caches, no module-level variables.
- **Network calls or filesystem I/O.** No `fetch`, no `Date.now()`, no `Deno.readFile`. If a clock or a network value is needed, it should already be in the payload or available via `read`.
- **Sub-classify by calling back into the rig.** If decomposition is needed, return a code whose handler decomposes.

The async-ness is for `read` (which is asynchronous because confirmed state may live anywhere on the rig). It is not a license to do effectful work.

## The running example: place-order

A storefront posts to the rig:

```
rig.receive([
  ["data://orders/o/ord_42/entries/2026-06-21T14:00:00Z-placed",
   { customer: "c_99", lines: [...], total: 4200, currency: "USD" }]
])
```

A program is registered at prefix `data://orders/`. The rig hands the message to it.

The program does three things:

1. **Validates URI shape.** Is this a path under `o/<id>/{<field>|lines/<n>|entries/<ts>-<kind>}`? If not, return `refuse:bad-shape`.
2. **Validates payload shape.** For a `*-placed` entry, the payload must carry `customer`, `lines`, `total`, `currency`. If something's missing, return `refuse:bad-payload`.
3. **Checks idempotence.** Uses `read` to confirm no prior `*-placed` entry exists under `data://orders/o/ord_42/entries/`. If one does, return `refuse:duplicate-placement`.

Otherwise: return `ok:order-entry-placed`. That's the verdict. The program's work is done; the rig now dispatches to the handler keyed on that code.

Note what is **not** here: the program does not write the entry. It does not write the customer-index entry. It does not call Stripe. It does not record the time. It looked at the message, consulted confirmed state, and produced one string. The next step is in [HANDLERS.md](./HANDLERS.md).

## Code shape — what makes a good code

A code is a single string. There is no nested `kind` field, no payload slot, no structured envelope. The convention b3nd-skill names (and that taskwatch uses in production) is **colon-namespaced verdicts**:

| Family | Meaning | Examples |
|---|---|---|
| `ok:*` | Well-formed, accepted, dispatch the matching handler. | `ok:order-entry-placed`, `ok:inventory-movement`, `ok:catalog-field-set` |
| `refuse:*` | Well-formed enough to classify, but rejected. The handler returns `[]`; nothing persists. | `refuse:bad-shape`, `refuse:bad-payload`, `refuse:duplicate-placement`, `refuse:outside-basepath` |

Most protocols only need those two families. A third is occasionally useful for **messages that are well-formed but cannot yet be acted on** — e.g. an order line that references an unknown SKU the catalog hasn't synced, or a receipt that arrives before the order it pays for. The convention for that is up to the protocol; a common one is:

| `defer:*` | Accepted, recorded as pending, no immediate effects. A separate trigger (a later message, a reaction, a manual replay) will produce the eventual outputs. | `defer:awaiting-sku`, `defer:awaiting-order` |

This is a convention, not a requirement. Pick the names; keep them stable; publish them in the protocol's `status()` manifest so consumers (and handlers) know what to expect.

**Three properties of a well-shaped code:**

1. **It names a verdict, not an action.** `ok:order-entry-placed` says "this is a valid placed-order entry". It does *not* say "store this and emit an event" — that's the handler's reading. A code is what the program sees; the action is what the handler does.
2. **Its vocabulary is published.** Every code a program can emit appears in the protocol's `status()` manifest with a one-line meaning. Codes nowhere documented are not a contract — they're a leak.
3. **Every code has exactly one handler.** Two handlers on the same code are a bug. Zero handlers on a code the program emits is also a bug. The rig dispatches purely on the string; orphans drop silently.

## Keeping programs pure

The discipline that makes b3nd worth using lives in the program staying pure. Concretely:

- No `await fetch`. If a program needs an external value, it's wrong: that value should be a payload field, or it should already be on the rig and queryable via `read`.
- No `Date.now()`, no `Math.random()`. Time-stamped URIs come from whoever called `receive`, not from inside the program. If a program needs "now" for a comparison, the caller provides it in the payload.
- No file I/O, no DB writes, no metrics emissions. The rig has hooks for those (see [RIG.md](./RIG.md) on the data lifecycle); they don't belong inside classifiers.
- No mutable module-level state. Two parallel classifications must not interfere.

When a program needs to compare against confirmed state — "does this order already have a placed entry?" — the answer is always `await read(...)`. Not a side channel.

## Granularity — one program per prefix

A program is identified by the URI **prefix** it's registered at. The ecommerce protocol has one program at `data://orders/`, one at `data://inventory/`, one at `data://catalog/`, one at `data://customers/`, one at `data://fulfillment/`, one at `hash://sha256/`. **Not** one per entry-kind, one per field, or one per code.

Within a prefix, the program branches on URI shape and entry-kind internally. For inventory, the same program at `data://inventory/` looks at the URI's `<kind>` suffix (`received`, `sold`, `adjusted`, `reserved`) and decides which code to emit — all in one function.

If you want more programs, name more prefixes. Splitting `data://inventory/p/` from `data://inventory/index/` is fine, because those are routable destinations the rig can wire independently. Splitting "inventory-received-program" from "inventory-sold-program" at the same prefix is not — they would collide on the same key.

## Anti-patterns

- **A program that I/Os.** Any `await fetch`, file read, network call, or `Date.now()`. If you find one, the work belongs in the payload, in `read`, or in a reaction (see RIG.md). Programs do not have side effects.
- **A program that decides what to dispatch.** Treating the program as "the controller" — looking at the URI, then "deciding" to write to a database and emit an event. That's two handler responsibilities pretending to be one program. Return a code; let the handler decide the outputs.
- **A program that sub-classifies by re-entering the rig.** Calling `rig.receive(...)` from inside a program to recurse. Forbidden by PROTOCOL.md. If the message needs decomposing, emit a code whose handler returns the sub-outputs.
- **Codes with no published vocabulary.** Ad-hoc strings nowhere documented. Codes are the protocol's contract with handlers and consumers; they belong in `status()`.
- **A program per event kind.** One program per URI prefix; branch on shape inside. Multiple programs at the same prefix collide.

## Next

The code emitted here is dispatched in [HANDLERS.md](./HANDLERS.md). The place-order flow continues there — the `ok:order-entry-placed` verdict turns into the two tuples the rig actually persists.
