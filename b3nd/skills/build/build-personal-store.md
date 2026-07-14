# Build a personal store — data that is cryptographically yours

A store where "mine" means a keypair, not a login: a namespace at
`immutable://{pubkey}/…`, writes signed and content-addressed. b3nd gives the
primitives (identity, hashing, a program layer); ownership, write-once, and
integrity are a program you write.

### Identity — a keypair is the owner

```ts
import { Identity } from "@bandeira-tech/b3nd-core";

const owner = await Identity.fromSeed(mySeed); // deterministic Ed25519 + X25519
owner.pubkey;           // your address — the root of your namespace
owner.encryptionPubkey; // where private records get encrypted to
```

### Address a record by its content

```ts
import { computeSha256 } from "@bandeira-tech/b3nd-core/hash";

const addr = await computeSha256(body);                    // 64-char hex (RFC 8785 for objects)
const uri = `immutable://${owner.pubkey}/shared/${addr}`;  // the address IS the content
// the store won't stop a different payload landing here — the program below enforces it.
```

### Ownership + write-once — the program you write

```ts
import type { Program } from "@bandeira-tech/b3nd-core";
import { verify } from "@bandeira-tech/b3nd-core/encrypt";
import { computeSha256 } from "@bandeira-tech/b3nd-core/hash";

// b3nd verifies signatures over payloads, not over uris — bind the destination in yourself.
const signingContext = (uri: string, body: unknown) => ({ uri, body });

type Signed = { sig: { pubkey: string; signature: string }; body: unknown };

const owns: Program<Signed> = async ([uri, rec]) => {
  const [, , ownerPubkey, , addr] = uri.split("/"); // immutable://{owner}/{kind}/{addr} — schematic
  // signed THIS uri (a bare-payload signature replays to another uri)
  const authentic = await verify(rec.sig.pubkey, rec.sig.signature, signingContext(uri, rec.body));
  if (!authentic || rec.sig.pubkey !== ownerPubkey) return { code: "forbidden", error: "not owner" };
  // write-once: address must equal the content hash (the store won't check)
  if (addr !== await computeSha256(rec.body)) return { code: "bad-address" };
  return { code: "ok" };
};
// mount at your namespace prefix, map codes to writes — see build-data-protocol.md for the wiring.
```

### Write a record — sign the destination; private = encrypt, shared = plaintext

```ts
const signingContext = (uri: string, body: unknown) => ({ uri, body }); // same as the program's

// shared: plaintext, readable by anyone, writable only by the owner
async function putShared(plainBody: unknown) {
  const addr = await computeSha256(plainBody);
  const uri = `immutable://${owner.pubkey}/shared/${addr}`;
  return [uri, { sig: await owner.sign(signingContext(uri, plainBody)), body: plainBody }];
}

// private: same spine, body is ciphertext only the owner's key opens
async function putPrivate(plain: Uint8Array) {
  const body = await owner.encrypt(plain, owner.encryptionPubkey); // encrypt to self
  const addr = await computeSha256(body);
  const uri = `immutable://${owner.pubkey}/private/${addr}`;
  return [uri, { sig: await owner.sign(signingContext(uri, body)), body }];
}
```

### Verify on read — re-hash, don't trust storage

```ts
// stores don't re-check on read — re-hash before trusting what came back.
async function getVerified(node, uri: string) {
  const [[, rec]] = await node.read([uri]);
  const [, , , , addr] = uri.split("/");
  if (addr !== await computeSha256(rec.body)) throw new Error("integrity: content != address");
  return rec.body; // private record? owner.decrypt(rec.body) for the plaintext
}
```

### Open edges — b3nd gives the mechanism, not the guarantee

```ts
// each is a mechanism b3nd exposes; the guarantee on top is yours to build:
// - durable read-after-write: `receive` acks before the store settles → await op.settled
// - multi-device sync: list a peer, pull missing uris, re-receive locally (program re-checks each)
// - automate without loops: reactions can retrigger — keep derived writes in a disjoint
//   namespace so they can't re-match; b3nd ships no loop guard
```
