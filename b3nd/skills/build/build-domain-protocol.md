# Build a B3nd Domain Protocol

Package a domain as uri + payload rules — what a resource *means*, its states and
transitions, the invariants operators commit to — decoupled from any transport
or store. (Transport/handling/persistence plumbing is the sibling data protocol.)

### Model the resource as canonical uris — one per state, injectable basepath

```ts
// mount anywhere: `${base}/order/...` — operator owns the base, you own the shape
export const uris = (base: string) => ({
  draft:     (id: string) => `${base}/order/${id}/draft`,
  placed:    (id: string) => `${base}/order/${id}/placed`,
  fulfilled: (id: string) => `${base}/order/${id}/fulfilled`,
  // frontload identity for findability: `${base}/order/{customer}/{ts}-{id}`
});
```

### The payload shape for each state / transition

```ts
export type Draft     = { items: LineItem[]; customer: string };
export type Placed    = Draft & { placedAt: string; total: number };
export type Fulfilled = { shippedAt: string; carrier: string; tracking: string };

type LineItem = { sku: string; qty: number };
```

### The lifecycle — which transitions the domain permits

```ts
// the invariant the protocol asserts; operators commit to honoring it
export const transitions: Record<string, string[]> = {
  draft:     ["placed"],
  placed:    ["fulfilled", "cancelled"],
  fulfilled: [],
  cancelled: [],
};
```

### Map user content into domain `Output[]` — pure, so it runs frontend OR backend

```ts
import type { Output } from "@bandeira-tech/b3nd-core";

// no I/O, no rig — just the domain shape. same fn on a form or in a worker.
export const placeOrder = (
  base: string,
  id: string,
  draft: Draft,
): Output[] => [
  [uris(base).placed(id), { ...draft, placedAt: now(), total: sum(draft.items) }],
];
```

### Validate a transition as a `Program` — classify, don't mutate

```ts
import type { Program, ReadFn } from "@bandeira-tech/b3nd-core";

// Program = (output, upstream, read) => Promise<{ code, error? }>
// pure classifier: reads confirmed state, returns a protocol code
export const classifyPlaced: Program<Placed> = async ([uri, payload], _up, read) => {
  const id = idOf(uri); // idOf/baseOf: recover id + mount from the uri (cf. parseUrl, build-data-protocol.md)
  const [, prior] = await read(uris(baseOf(uri)).draft(id)); // ReadFn: read([loc])[0]
  if (!prior)                    return { code: "no-draft", error: "nothing to place" };
  if (payload.items.length === 0) return { code: "empty" };
  if (!canGo("draft", "placed")) return { code: "illegal-transition" };
  return { code: "ok" };
};

const canGo = (from: string, to: string) => transitions[from]?.includes(to);
```

### Handle each code as a `CodeHandler` — pure transform to the `Output[]` to dispatch

```ts
import type { CodeHandler } from "@bandeira-tech/b3nd-core";

// CodeHandler = (out, result, read) => Promise<Output[]>. Rig owns the wire.
export const onPlaced: Record<string, CodeHandler> = {
  ok:                 async (out) => [out],                 // persist
  "no-draft":         async () => [],                       // refuse
  "illegal-transition": async () => [],                     // refuse
  empty:              async () => [],
};
```

### Ship it — the domain as a mountable package, over a generic data node

```ts
import type { ProtocolInterfaceNode } from "@bandeira-tech/b3nd-core";

// a domain = uris + payload types + programs + handlers + operator commitments.
// nothing here names HTTP, a DB, or a rig — mount it on any data PIN.
export const orderDomain = (base: string) => ({
  uris: uris(base),
  transitions,
  programs: { placed: classifyPlaced /* , fulfilled: ..., cancelled: ... */ },
  handlers: { placed: onPlaced /* , ... */ },
  // what operators must commit to for this domain to hold
  commitments: [
    "persist accepted outputs durably",
    "reject transitions not in `transitions`",
    "emit the placed uri on observe when an order is placed",
  ],
});

// mounting = pointing the domain's outputs at a data node at a chosen base.
// `node` is any ProtocolInterfaceNode (memory, HTTP, store — the data layer).
export const mount = (node: ProtocolInterfaceNode) => {
  const domain = orderDomain("mutable://acme");
  return {
    place: (id: string, d: Draft) => node.receive(placeOrder("mutable://acme", id, d)),
    _domain: domain,
  };
};
```
