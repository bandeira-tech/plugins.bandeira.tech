# APP — building a whole b3nd app

> STUB — fill in iteratively.

## Cover

- The five-step shape: URI scheme → programs → handlers → UI → wire into rig.
- The conversation pattern: design the URI table with the user before generating a single file.
- One protocol module, two consumers (server-side rig + browser-side rig). One file, both sides.
- Hand-off: how to teach the user to send, read, observe their first record.

## Anti-patterns

- Skipping the URI table and going straight to scaffolding.
- Generating a wall of files before the user has agreed on the shape.
- Inventing a route layer ("GET /api/posts") when the URIs already are the surface.
