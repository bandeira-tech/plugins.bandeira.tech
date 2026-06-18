# RIG — your wiring diagram

> STUB — fill in iteratively.

## Cover

- What a rig actually is: `routes` × `connections` × URI patterns.
- What `bnd` does with one: `bnd send / receive / read / observe / node / status`.
- How to grow it:
  - add a connection (local FS, SQLite, HTTP remote, etc.)
  - choose URI patterns each connection owns
  - keep schemas and protocols out of the rig file
- Multi-target via this plugin: `~/.bnd/targets.toml`, `/b3nd:targets`, the `active` field. Note this is a stub for `bnd config target` upstream.

## Voice note

When the user says "where do I put X?", default answer is *probably not in the rig*. The rig is wiring; protocols live in their own modules; storage is delegated to b3nd-save backends.
