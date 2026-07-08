# Build multi-node composition on B3nd

Route different URIs to different backends, layer storage, and replicate across
peers — all through the same PIN interface. Every other build guide wires a
*single* store; this is the guide for more than one.

> **STATUS: STUB — not yet written.** Scaffolded so the gap is tracked and can be
> picked up outside this session. Follow RULE 0 and `CLAUDE.md` when filling it.

## To write — one code block per item

- [ ] Route by uri — multiple `connection(client, [patterns])` on one rig, each
      pattern to a different backend.
- [ ] **Aggregator client** — the cache→origin fall-through. NOTE the footgun:
      rig `read` is *first-accepts-wins with no fall-through* (`read:[cache,
      primary]` shadows primary on a cache miss). The fix is one client that
      falls through internally; route to that.
- [ ] Replication — `network()` with `peer()` + a policy (`flood`,
      `path-vector`, `tell-and-read`).
- [ ] Asymmetric topology — write-mirror + read-cache + narrow observe (see the
      `connection.ts` example).
