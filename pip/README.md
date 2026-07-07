# b3nd — Claude Code plugin

Build with [B3nd](https://github.com/bandeira-tech) from inside Claude Code.

The plugin gives the user **their own rig** running as an MCP server, plus the skill and commands to grow it over time. Apps you build with Claude become URI shapes and on-the-fly UI, not services to deploy.

## What you get

- **MCP server `b3nd`** — wraps `bnd node --mcp` against the user's active rig target. The MCP surface is the standard b3nd tools (`b3nd_receive`, `b3nd_read`, `b3nd_status`); the skill teaches how to drive them.
- **Skill `b3nd`** — what B3nd is, why it looks the way it does, and how to think in URIs / programs / handlers. Friendly door at `START.md`; deep files for each piece. Pre-1.0 etiquette and a relay protocol that keeps Claude honest about current APIs.
- **Slash commands** (`b3nd:` namespace):
  - `/b3nd:install` — set up the `bnd` CLI if it isn't already.
  - `/b3nd:targets` — list / add / use / remove rig targets (local, testnet, prod, any URL).
  - `/b3nd:rig` — grow the active target rig: add a connection, list connections, status.
  - `/b3nd:program` — scaffold a program (classifier → codes).
  - `/b3nd:handler` — scaffold a handler (code → outputs).
  - `/b3nd:new-app` — full app walk: URI scheme → programs → handlers → UI.

## Requirements

- [Deno 2.x](https://docs.deno.com/runtime/getting_started/installation/) — `bnd` runs on it.
- The `bnd` CLI:
  ```bash
  deno install --global -A -n bnd jsr:@bandeira-tech/b3nd-cli
  ```
  Or run `/b3nd:install` from inside Claude Code and it walks you through it.

## Install

This plugin lives in the `bandeira-tech` marketplace:

```
/plugin marketplace add bandeira-tech/plugins.bandeira.tech
/plugin install b3nd
```

## How targets work

This plugin lets you point your MCP server at one of several **named rigs** — your local dev rig, a testnet node, a production node, anything. Targets live in `~/.bnd/targets.toml`:

```toml
active = "local"

[target.local]
rig = "/Users/me/work/my-app/b3nd.rig.ts"

[target.testnet]
rig = "https://testnet-evergreen.fire.cat"
```

Switch with `/b3nd:targets use <name>`, then restart Claude Code so the MCP picks it up.

> This file format is a plugin-local stub. The same shape is slated for upstream as `bnd config target` — when that lands, the file moves into bnd's own surface and this plugin defers.

## Status

Pre-1.0. The framework's shape is stable; package APIs evolve. When you hit a rough edge, the culture is **fix and upstream** — see `skills/b3nd/CONTRIBUTING.md`.

## License

MIT.
