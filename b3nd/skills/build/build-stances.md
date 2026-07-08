# Pick a B3nd stance — how far this flow diverges

A **stance** is how much conventional architecture a flow keeps and how much of
B3nd's alien surface it adopts. Chosen **per flow, not per project** — the same
app runs `Warden` on payments and `HAMMER` on an experiment. Surface it with the
user *before* designing (SKILL.md RULE 1). "Up" is not better; every stance is a
valid destination.

## Surface it like this

Ask before designing — one question, four options:

- **Warden** — keep it conventional; B3nd stays behind an interface I own.
- **Graft** — conventional trunk; B3nd seam on this *new* flow only.
- **Envoy** — adopt B3nd's data plane, but keep trust conventional (domain + auth nodes, no user keys).
- **HAMMER** — go native: keys as ownership, untrusted mesh, frontier.

## The adoption stack — where a stance draws its line

```
decentralized / permissionless trust     ← most alien
key-based ownership (Identity as authz)
untrusted / generic data nodes
the Output / PIN seam                     ← least alien, cheapest to adopt
```

Below the line: adopt native. Above: externalize into conventional machinery
(RBAC, a trusted domain, auth nodes).

## The four stances

| Stance | Keeps conventional | Adopts native | Externalizes | Blast radius |
|--------|--------------------|---------------|--------------|--------------|
| **Warden** | everything | nothing (B3nd behind an anti-corruption layer) | all | ~zero, reversible |
| **Graft** | the trunk | Output seam on *new* flows only | keys, generic nodes, decentralization | one flow |
| **Envoy** | the trust plane | Output seam + untrusted data nodes | key-ownership → trusted domain + auth nodes | data plane |
| **HAMMER** | nothing | the whole stack | nothing | end-to-end |

### Warden — contain and verify; rip-out stays cheap

```ts
// B3nd lives behind an interface you own.
interface NotesPort { save(n: Note): Promise<void>; get(id: string): Promise<Note | undefined>; }
class B3ndNotes implements NotesPort { /* a Rig inside; the app never sees it */ }

// Contract-test the SAME suite against the REAL backend, not MemoryStore —
// the PIN interface is not a behavioral guarantee.
for (const store of [pgStore /*, ... */]) runNotesContract(() => new B3ndNotes(store));
```

### Graft — conventional trunk, B3nd seam on the new flow only

```ts
// Old flows untouched. Only the NEW flow speaks B3nd; bridge existing auth.
const rig = new Rig({
  routes: { receive: [connection(store, ["mutable://app/new-flow/**"])] },
  hooks: { beforeReceive: (ctx) => { /* your existing session/authz check */ } },
});
await rig.receive([[`mutable://app/new-flow/${id}`, payload]]);
```

### Envoy — adopt the data plane, externalize ownership

```ts
// Trust is central (domain + auth node). Data nodes are dumb & interchangeable.
const authNode = connection(authClient, ["**"]);    // mints/verifies grants — trusted
const dataNode = connection(genericStore, ["**"]);   // untrusted, generic, swappable

const rig = new Rig({
  routes: { receive: [dataNode], read: [dataNode] },
  hooks: { beforeReceive: (ctx) => { /* verify a domain grant, not a user key */ } },
});
// No user keys. Never trust an untrusted node for integrity — validate on read.
```

### HAMMER — native ownership, signed writes, receiver verifies

```ts
// Ownership IS the key. Authority travels with the Output; no central trust.
const id = await Identity.fromSeed(secret);
const auth = await id.sign({ outputs });
await rig.send([await message({ auth, inputs: [], outputs })]);
// Receiver: beforeReceive → Identity.verify(...). Push into unpaved ground.
```

## Defensive testing scales with the stance

- **Warden** — contract-test every PIN against the **real** backend, not `MemoryStore`.
- **Graft** — test the seam; keep the conventional↔B3nd boundary explicit and rippable.
- **Envoy** — test the auth-node chokepoints; treat every data node as integrity-hostile.
- **HAMMER** — property tests (Byzantine safety, convergence, idempotency); carry Warden-grade tests before any real path.

## Graduate only on evidence

Move a flow up a rung when the current one has paid off and a concrete pull
appears — shared Output vocabulary across new flows (Graft→Envoy), user-held
ownership or cross-domain composition (Envoy→HAMMER). Never aspirationally.

## HAMMER and canon

HAMMER goes past the paved road. There is **no capture system** — canon emerges
through conversation and recurrence, slowly, as builders and maintainers fold
proven patterns back into `learn` / `build`. At the frontier: solve it, document
the solution clearly, and bring it as a **candidate, not a decree**. Canon is
earned when a pattern recurs across builders and survives scrutiny — not when it
ships once. The open edges are where to aim (capability contracts for
substitutability, resumable observe, reaction delivery).
