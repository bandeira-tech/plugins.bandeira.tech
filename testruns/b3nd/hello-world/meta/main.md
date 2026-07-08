# hello-world

## Task

Write a minimal B3nd hello-world: a single-file Deno script that
creates a Rig in-process, registers one program that matches any message
sent to `hello://world`, and one handler that returns the string
`"Hello, world!"` as a text payload.

Then send one message to `hello://world` and print the result to stdout.

Use the b3nd skill to understand the right shapes — programs, handlers,
the Rig, and how to wire them together. Consult TARGETS.md for current
package names and imports before writing any code.

## Success criteria

- A single working Deno script at outputs/hello-world.ts
- Running it with `deno run -A outputs/hello-world.ts` prints "Hello, world!"
- Uses real b3nd-core imports (not mocked or stubbed)
- No unnecessary abstractions — just the minimum to make it work

## Notes

- In-process only, no HTTP or MCP needed
- Deno-first: use JSR imports
