# Build tests for a B3nd PIN — verify behavior, not just shape

Contract-test a PIN against the verbs it implements, and against the *real*
backend it will run on — the `ProtocolInterfaceNode` interface is a shape, not a
behavioral guarantee (a `MemoryStore` and a `PostgresStore` differ in atomicity,
durability, and push-down). This guide anchors RULE 1's "defensive testing
scales with the stance."

> **STATUS: STUB — not yet written.** Scaffolded so the gap is tracked and can be
> picked up outside this session. Follow RULE 0 and `CLAUDE.md` when filling it.

## To write — one code block per item

- [ ] Assert against `RecordingClient` (core `testing/` module) — capture and
      inspect the Outputs a flow emits.
- [ ] **Contract test**: one suite run across multiple *real* backends (the
      Warden move) — prove substitutability instead of assuming it.
- [ ] `MemoryStore` for fast unit tests vs. the real backend for truth; when
      each lies.
- [ ] `receive` — assert per-slot `ReceiveResult` (partial batch success).
- [ ] `observe` — drive a stream, assert fired uris; abort/teardown.
- [ ] `beforeReceive` / program / handler gates — assert rejection paths.
- [ ] Fold in observability: tracing via Rig hooks/events + a `preSend`
      correlation id (analysis G7 — no separate file).
