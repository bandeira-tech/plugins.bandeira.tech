# Build, run & package a B3nd app

Ship what you built: host a rig as a `bnd` module, bundle for the browser, and
publish. The run/deploy bits are scattered across the app guides today (the `bnd`
rig module in `build-cli-app.md`, the `b3nd-web` bundle in `build-web-app.md`) —
this is their home.

> **STATUS: STUB — not yet written.** Scaffolded so the gap is tracked and can be
> picked up outside this session. Follow RULE 0 and `CLAUDE.md` when filling it.

## To write — one code block per item

- [ ] `b3nd.rig.ts` — default-export a Rig; `bnd node` drives every verb, adds
      `--http` / `--mcp-http` transports.
- [ ] Browser bundle — `@bandeira-tech/b3nd-web` (core + local store +
      transports in one import).
- [ ] Publishing — jsr vs. npm; the current npm-vendoring caveat
      (1.0-readiness §8).
- [ ] **Version pinning** — keep `b3nd-core` / `-move` / `-save` on matching
      versions; no wire-format negotiation yet (1.0-readiness §1, §4).
