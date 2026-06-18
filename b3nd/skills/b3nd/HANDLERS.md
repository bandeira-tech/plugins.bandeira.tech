# HANDLERS — codes → outputs

> STUB — fill in iteratively.

## Cover

- Handlers are pure: `(code) → Output[]` where `Output = [uri, payload]`.
- Side effects are the rig's job, not the handler's.
- One handler per code kind. Collisions are bugs.
- Multiple outputs per code is fine and idiomatic (write + emit-event).

## Smells

- `fetch` / `Deno.writeFile` / `Date.now()` inside a handler — split into rig concern.
- Output URIs no connection owns. Document protocol's expected URI patterns.
