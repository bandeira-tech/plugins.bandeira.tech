# Build authenticated + owned writes on B3nd

Wire identity end-to-end: sign a write, verify it at the receiver, and choose how
ownership is carried. The primitives live across all three repos
(`Identity`/Ed25519 in core, `preSend` in move, mapper encryption in save) — this
guide is the missing recipe that connects them. Anchors the Envoy and HAMMER
stances (`build-stances.md`).

> **STATUS: STUB — not yet written.** Scaffolded so the gap is tracked and can be
> picked up outside this session. Follow RULE 0 and `CLAUDE.md` when filling it.

## To write — one code block per item

- [ ] Sign: `Identity.sign` → `message({ auth, inputs, outputs })` → `rig.send`.
- [ ] Verify at the receiver: `beforeReceive` gate calling `Identity.verify`
      (throw to reject).
- [ ] `preSend` injection — bearer token or request signature on a move client.
- [ ] **Envoy variant** — authority from a trusted domain + auth node (a PIN
      that mints/checks grants); no user keys.
- [ ] **HAMMER variant** — key-as-ownership; authority travels with the Output,
      no central trust.
- [ ] Encrypted-at-rest via a `SaveMapper` (decrypt on read); the 1.0-readiness
      "authenticated write + encrypted-at-rest" cookbook.
