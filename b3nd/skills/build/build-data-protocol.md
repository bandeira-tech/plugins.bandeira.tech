# Build a B3nd data protocol — reusable transport/handling/persistence

A data protocol is the domain-agnostic plumbing: how `[uri, payload]` tuples are
addressed, classified, validated, and expected to be handled. You ship it as
pure functions + uri templates, deployable to either side of a wire. (Domain
object lifecycle/semantics live in `build-domain-protocol.md`, not here.)

## 1. URI structure — templates as consts, basepath injectable

### Frontload identity/index segments; keep the basepath a parameter

```ts
// A protocol is a set of uri templates over an injectable mount.
// Never hardcode the scheme root — let the operator mount you.
type Mount = string; // e.g. "mutable://app" or "b3nd://tenant/42"

const uris = (base: Mount) => ({
  // identity + index frontloaded so the path itself is a query surface
  record: (id: string) => `${base}/records/${id}.json`,
  byCat: (cat: string, ts: string, slug: string) =>
    `${base}/index/${cat}/${ts}-${slug}.json`,
  // observe/read patterns are part of the grammar you publish
  allInCat: (cat: string) => `${base}/index/${cat}/**`,
});
```

### A parsed uri is your routing surface — reuse the save parser, don't invent

```ts
import { parseUrl, uriOf, type ParsedUrl } from "@bandeira-tech/b3nd-save";

const p: ParsedUrl = parseUrl("mutable://app/index/notes/2026-note.json");
p.program; // "mutable://app"      — routing root above the path
p.path;    // "/index/notes/..."   — your template segments
p.uri;     // canonical uri (literal prefix when the source globs)
p.glob;    // wildcard tail, "" when none
uriOf("mutable://app/x?pattern=**"); // strip request-time decoration → bare uri
```

## 2. Payload types + classification codes

### Declare payload shapes and the closed set of codes your program emits

```ts
// payload variants the protocol carries
type Put<T> = { op: "put"; body: T };
type Del = { op: "del" };
type ProtoPayload<T> = Put<T> | Del;

// codes are protocol-defined strings; handlers key off them (§3)
const Code = {
  put: "data:put",
  del: "data:del",
  badUri: "data:bad-uri",
  badPayload: "data:bad-payload",
} as const;
```

## 3. Validation + handling — pure `Program` + `CodeHandler`, distributable

### Program — pure classifier `[uri,payload] → {code, error?}`

```ts
import type { Program, ProgramResult } from "@bandeira-tech/b3nd-core";
import { parseUrl } from "@bandeira-tech/b3nd-save";

// Program<T> = (output, upstream, read) => Promise<ProgramResult>
// pure: no writes, no rig callbacks; `read` sees only confirmed state.
const program = (base: string): Program<ProtoPayload<unknown>> =>
async ([uri, payload], _upstream, read): Promise<ProgramResult> => {
  const p = parseUrl(uri);
  if (p.program !== base) return { code: Code.badUri, error: `off-mount: ${uri}` };
  if (payload?.op === "del") {
    const [, prev] = await read(uri); // gate on prior state if the protocol needs it
    if (prev === undefined) return { code: Code.badPayload, error: "nothing to delete" };
    return { code: Code.del };
  }
  if (payload?.op === "put" && "body" in payload) return { code: Code.put };
  return { code: Code.badPayload, error: "unknown op" };
};
```

### CodeHandler — pure transform `→ Output[]` the rig will dispatch

```ts
import type { CodeHandler, Output } from "@bandeira-tech/b3nd-core";

// CodeHandler = (out, result, read) => Promise<Output[]>
const handlers: Record<string, CodeHandler> = {
  [Code.put]: async ([uri, payload]) => [[uri, (payload as Put<unknown>).body]], // persist
  [Code.del]: async ([uri]) => [[uri, null]],                                    // tombstone
  // refuse: return [] — a valid outcome, not an error
  [Code.badUri]: async () => [],
  [Code.badPayload]: async () => [],
  // decompose: fan one envelope into many writes
  // async ([uri, env], _r, _read) => [[uri, env], ...env.outputs as Output[]],
};
```

### Package the protocol as pure exports — same object mounts on either side

```ts
// One module. Import it in a browser rig OR a backend rig — no wire assumptions.
export const dataProtocol = (base: string) => ({
  uris: uris(base),
  program: program(base),
  handlers,
});
```

## 4. Register on a Rig — programs keyed by uri prefix, handlers by code

```ts
import { Rig, connection } from "@bandeira-tech/b3nd-core";

const base = "mutable://app";       // operator picks the mount
const proto = dataProtocol(base);
const store = connection(myStore, [`${base}/**`]); // your persistence PIN

const rig = new Rig({
  routes: { receive: [store], read: [store], observe: [store] },
  programs: { [base]: proto.program },   // prefix → classifier
  handlers: proto.handlers,              // code   → Output[] transform
});

await rig.receive([[proto.uris.record("42"), { op: "put", body: { hi: 1 } }]]);
```

## 5. Coordination expectations — state them as shape, not prose

### Advertise what you serve; expect the operator to satisfy it

```ts
// status.resources is the contract surface: the mount must appear under the
// verbs your protocol needs (a chat-like protocol needs receive AND observe).
const s = await rig.status();
s.resources; // { receive: ["mutable://app/**"], observe: ["mutable://app/**"], ... }
```

### Encode persistence/replication/signature expectations in the uri or payload

```ts
// Expectations travel with the data, not in a side channel:
const expects = {
  persisted: (uri: string) => `${uri}`,                    // plain: expect stored
  replicated: (uri: string, n: number) => `${uri}?x-replicas=${n}`, // x-* ext params
  signed: (base: string, hash: string) => `${base}/secure/${hash}/record.json`, // sig in path
};
// A stricter protocol makes its Program reject unsigned/unreplicated uris,
// so the coordination expectation is enforced by classification, not trust.
```
