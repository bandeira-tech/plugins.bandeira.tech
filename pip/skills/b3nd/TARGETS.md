# TARGETS — current packages + the relay protocol

> STUB — keep this file alive. It is the only one in the skill that should drift quickly.

## Relay protocol (Claude must follow before writing any B3nd code)

1. **Find installed versions.** Read the user's `deno.json` (or `package.json`) imports for `@bandeira-tech/*`. Note version specifiers.
2. **Compare to the targets below.** If the user is outside the supported window, warn them and ask whether to proceed.
3. **Fetch current exports.** For each package you'll import from, look it up on JSR (`jsr.io/@bandeira-tech/<pkg>`) or its source repo (`github.com/bandeira-tech/<pkg>`). Confirm the symbols and signatures you're about to use exist.
4. **Now write code.** Not before.

If you skip step 3, you will hallucinate signatures. The prose in this skill cannot be the source of truth for API.

## Current targets (update as packages move)

| Package | Target version | Notes |
|---|---|---|
| `@bandeira-tech/b3nd-core` | `^0.12.0` | Rig, connection, message types, Ed25519/X25519, hooks, events. |
| `@bandeira-tech/b3nd-move` | track latest | HTTP, WS, gRPC-over-HTTP, MCP services + clients. |
| `@bandeira-tech/b3nd-save` | track latest | EntityStore + backends (memory, fs, sqlite, postgres, mongo, es, s3, ipfs, localStorage, IndexedDB). Strict by design. |
| `@bandeira-tech/b3nd-canon` | track latest | Envelopes, RFC 8785, `hash://`, encryption. |
| `@bandeira-tech/b3nd-servers` | `^0.11.0` | Used by `bnd`; exposes `bnd node --http --grpc --mcp`. |
| `@bandeira-tech/b3nd-cli` | `^0.4.0` | The `bnd` binary. This plugin's MCP server wraps `bnd node --mcp`. |
| `@bandeira-tech/b3nd-sdk` | track latest | Umbrella ergonomics package. Cores stay puritan; sugar lives here. |
| `b3nd-web` | track latest | Browser-side companion to `b3nd-sdk`. |

(Verify these against JSR before relying on them. If the version range here is wrong, fix it and bump the plugin.)

## When TARGETS goes stale

- Bump the version cells.
- If a package name moved, update every cross-reference in the skill.
- If a package was added or removed, update SKILL.md routing and any commands that mention it.
