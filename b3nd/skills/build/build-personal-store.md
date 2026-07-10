# Build a personal store — data that is cryptographically yours

The builder floor: "my data" means *mine* by a keypair, not by a login. b3nd
gives you the primitives — identity, hashing, a program layer. **Ownership,
write-once, and integrity are policy you write on top**, because only you know
what your URIs are supposed to mean. The two short blocks are the primitives;
everything after is the policy, and it is yours.

### Identity — a keypair is the owner

```ts
import { Identity } from "@bandeira-tech/b3nd-core";

const owner = await Identity.fromSeed(mySeed); // deterministic Ed25519 + X25519
owner.pubkey;           // your address — the root of your namespace
owner.encryptionPubkey; // where your private records get encrypted to
```

### Address a record by its content

```ts
import { computeSha256 } from "@bandeira-tech/b3nd-core/hash";

const addr = await computeSha256(body);                    // 64-char hex (RFC 8785 for objects)
const uri = `immutable://${owner.pubkey}/shared/${addr}`;  // the address IS the content
// nothing yet stops a different payload landing at this uri — that's your program's job, below.
```

### The policy is a program you write — ownership + write-once

```ts
import type { Program } from "@bandeira-tech/b3nd-core";
import { verify } from "@bandeira-tech/b3nd-core/encrypt";
import { computeSha256 } from "@bandeira-tech/b3nd-core/hash";

// b3nd verifies signatures over PAYLOADS; it does not know your URIs mean ownership.
// You decide what a write must prove — start by binding the destination into the signed thing:
const signingContext = (uri: string, body: unknown) => ({ uri, body });

type Signed = { sig: { pubkey: string; signature: string }; body: unknown };

const owns: Program<Signed> = async ([uri, rec]) => {
  const [, , ownerPubkey, , addr] = uri.split("/"); // immutable://{owner}/{kind}/{addr} — schematic
  // 1. the writer signed THIS uri (a bare-payload signature could be replayed to another uri)
  const authentic = await verify(rec.sig.pubkey, rec.sig.signature, signingContext(uri, rec.body));
  if (!authentic || rec.sig.pubkey !== ownerPubkey) return { code: "forbidden", error: "not owner" };
  // 2. write-once: the address must be the content hash (the store won't enforce this)
  if (addr !== await computeSha256(rec.body)) return { code: "bad-address" };
  return { code: "ok" };
};
// mount at your namespace prefix + map codes to writes — see build-data-protocol.md for the wiring.
```

### Write a record — sign the destination; private = encrypt, shared = plaintext

```ts
const signingContext = (uri: string, body: unknown) => ({ uri, body }); // same as the program's

// shared: plaintext, readable by anyone, writable only by you
async function putShared(plainBody: unknown) {
  const addr = await computeSha256(plainBody);
  const uri = `immutable://${owner.pubkey}/shared/${addr}`;
  return [uri, { sig: await owner.sign(signingContext(uri, plainBody)), body: plainBody }];
}

// private: same spine, body is ciphertext only your key can open
async function putPrivate(plain: Uint8Array) {
  const body = await owner.encrypt(plain, owner.encryptionPubkey); // encrypt to yourself
  const addr = await computeSha256(body);
  const uri = `immutable://${owner.pubkey}/private/${addr}`;
  return [uri, { sig: await owner.sign(signingContext(uri, body)), body }];
}
```

### Verify on read — re-hash, don't trust storage

```ts
// stores check nothing on the read path; the integrity guarantee is yours to keep:
async function getVerified(node, uri: string) {
  const [[, rec]] = await node.read([uri]);
  const [, , , , addr] = uri.split("/");
  if (addr !== await computeSha256(rec.body)) throw new Error("integrity: content != address");
  return rec.body; // private record? owner.decrypt(rec.body) to read the plaintext
}
```

### Where you design — the edges b3nd hands you, not a library

```ts
// these are your calls; b3nd gives the mechanism, not the guarantee. Each is an open
// shape today — how you solve it is the signal for what should become canon:
//
// - durable read-after-write: `receive` acks before the store settles → await op.settled
// - multi-device sync: list a peer, pull the uris you're missing, re-receive locally
//   (your program re-checks every record, so an untrusted copy can't slip in)
// - automate without loops: a reaction can retrigger itself; keep derived writes in a
//   disjoint namespace so they can't re-match — b3nd ships no loop guard
```
