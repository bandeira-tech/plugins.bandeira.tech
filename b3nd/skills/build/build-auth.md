# Build authenticated + owned writes on B3nd

Wire identity end-to-end: sign a write, verify it at the receiver, and choose how
ownership is carried. `Identity`/Ed25519 lives in core; `preSend` in move; mapper
encryption in save. This guide connects them.

### 1. sign a write — minimal authenticated send

```ts
import { Identity, Rig, connection } from "@bandeira-tech/b3nd-core";
// (node setup elided; assume `rig` is already wired)

const id = await Identity.fromSeed("my-secret"); // deterministic from seed

// sign produces { pubkey, signature } — sign the payload you're about to send
const payload = { action: "transfer", amount: 42 };
const auth = await id.sign(payload);

// wrap as an AuthenticatedMessage shape and send as the Output payload
const envelope = { auth: [auth], payload };
const [result] = await rig.send([["mutable://app/transfer", envelope]]);
result.accepted; // true — pipeline accepted; routes settle in background
```

### 2. signMessage shorthand — same shape, one call

```ts
import { Identity } from "@bandeira-tech/b3nd-core";
// rig setup elided — see block 1

const id = await Identity.fromSeed("my-secret");
// signMessage<T>(payload: T): Promise<AuthenticatedMessage<T>>
// returns { auth: [{ pubkey, signature }], payload }
const envelope = await id.signMessage({ action: "transfer", amount: 42 });

await rig.send([["mutable://app/transfer", envelope]]);
```

### 3. verify at the receiver — `beforeReceive` gate

```ts
import { Identity, Rig, connection } from "@bandeira-tech/b3nd-core";
// node (storage PIN) setup elided

// beforeReceive ctx: { uri: string; data: unknown }
// throw to reject the tuple before it enters the pipeline
const rig = new Rig({
  routes: { receive: [connection(node, ["mutable://app/**"])] },
  hooks: {
    beforeReceive: async (ctx) => {
      const env = ctx.data as { auth?: { pubkey: string; signature: string }[]; payload?: unknown };
      const entry = env?.auth?.[0];
      if (!entry) throw new Error("missing auth");

      // Identity.verify(payload, signature) checks against this.pubkey
      const sender = Identity.publicOnly({ signing: entry.pubkey });
      const ok = await sender.verify(env.payload, entry.signature);
      if (!ok) throw new Error("invalid signature");
      // return void to proceed; throw = rejection (accepted: false)
    },
  },
});
```

### 4. inject a token/signature over HTTP — move `HttpClient` `preSend`

```ts
import { HttpClient } from "@bandeira-tech/b3nd-move/http/client";
import { httpOutputsFrame } from "@bandeira-tech/b3nd-move/codecs/http";

// preSend: (req: HttpPreSendRequest) => void | Promise<void>
// req has { url: URL; headers: Headers; body: BodyInit | null } — mutate in place
const client = new HttpClient({
  url: "https://api.example.com",
  codec: httpOutputsFrame(),
  preSend: (req) => {
    req.headers.set("Authorization", `Bearer ${getToken()}`);
    // or: req.headers.set("X-Signature", sign(req.body))
  },
});
// preSend fires once per request; works for receive, read, and observe
```

### 5. trusted-domain model — auth node mints a grant; data nodes check it

```ts
// An auth node (a PIN) mints grants — callers prove they hold a valid grant,
// not a personal key. Data nodes never see user keys; they validate the grant.
import { FunctionalClient, Rig, connection, type Output, type ReceiveResult } from "@bandeira-tech/b3nd-core";
// data-node PIN setup elided

// auth-node PIN: receive a grant-request, issue a signed grant
const authNode = new FunctionalClient({
  receive: async (msgs: Output[]): Promise<ReceiveResult[]> =>
    Promise.all(msgs.map(async ([uri, req]) => {
      const grant = await issueGrant(uri, req); // /* your grant-minting logic */
      return { accepted: true, /* carry grant in your envelope convention */ };
    })),
});

// data-node rig: beforeReceive checks the grant, not the user key
const dataRig = new Rig({
  routes: { receive: [connection(dataNode, ["mutable://data/**"])] },
  hooks: {
    beforeReceive: async (ctx) => {
      const env = ctx.data as { grant?: unknown; payload?: unknown };
      if (!await verifyGrant(env.grant)) throw new Error("invalid grant");
      // /* your grant check */ — domain logic, not per-user key
    },
  },
});
```

### 6. key-as-ownership model — authority travels with the signed Output

```ts
// No central trust needed. The sender signs the content; the receiver verifies
// the signature against the sender's pubkey. Ownership is self-evident from the key.
import { Identity, Rig, connection } from "@bandeira-tech/b3nd-core";
// rig setup elided — sender rig constructed separately (see block 1)
// node (storage PIN) setup elided

// sender: sign the specific content being claimed
const sender = await Identity.fromSeed("sender-secret");
const content = { resourceId: "xyz", owner: sender.pubkey };
const envelope = await sender.signMessage(content);

await rig.send([["mutable://owned/xyz", envelope]]);

// receiver: the signature over the content IS the ownership proof —
// no external authority needed to confirm it
const receiverRig = new Rig({
  routes: { receive: [connection(node, ["mutable://owned/**"])] },
  hooks: {
    beforeReceive: async (ctx) => {
      const env = ctx.data as { auth?: { pubkey: string; signature: string }[]; payload?: unknown };
      const entry = env?.auth?.[0];
      if (!entry) throw new Error("unsigned");
      const claimedOwner = Identity.publicOnly({ signing: entry.pubkey });
      if (!await claimedOwner.verify(env.payload, entry.signature)) {
        throw new Error("ownership not proven");
      }
    },
  },
});
```

### 7. encrypt at rest — a `SaveMapper` that encrypts on write, decrypts on read

```ts
import type { SaveMapper } from "@bandeira-tech/b3nd-save/clients";
import { encryptSymmetric, decryptSymmetric, type EncryptedPayload } from "@bandeira-tech/b3nd-core/encrypt";

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const KEY_HEX = /* 32-byte hex key from your key-management layer */ "...";

// EncryptedPayload: { data: string /* base64 ciphertext */; nonce: string /* base64 */ }
// encryptSymmetric(bytes, keyHex) => Promise<EncryptedPayload>
// decryptSymmetric(payload: EncryptedPayload, keyHex) => Promise<Uint8Array>

// SaveMapper<TIn, TOut>: toStore runs on write; fromStore runs on read
// entity must store the EncryptedPayload object shape (data + nonce as base64 strings)
const encryptedMapper: SaveMapper<unknown, unknown> = {
  async toStore(wireUri, payload) {
    const bytes = encoder.encode(JSON.stringify(payload));
    const encrypted: EncryptedPayload = await encryptSymmetric(bytes, KEY_HEX);
    return { uri: wireUri, record: { payload: encrypted } };
  },
  async fromStore(storeUri, record) {
    if (!record?.payload) return { uri: storeUri };
    const bytes = await decryptSymmetric(record.payload as EncryptedPayload, KEY_HEX);
    return { uri: storeUri, payload: JSON.parse(decoder.decode(bytes)) };
  },
};
// pass encryptedMapper to new SaveClient(encryptedMapper, entity, store)
```
