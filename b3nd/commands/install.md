---
description: Install and set up the `bnd` CLI so the b3nd MCP server can host the user's rig.
argument-hint: "[--global | --local]"
allowed-tools: Bash, Read, Write
---

# Set up `bnd`

The b3nd plugin's MCP server is a wrapper around `bnd node --mcp`. If `bnd` is not on PATH, the MCP server will not start. This command sets it up.

## Steps

1. **Check current state**
   - Run `command -v bnd` to see if it's already installed. If yes, run `bnd --version` and report it.
   - Run `command -v deno` to confirm Deno is available. If not, tell the user Deno 2.x is required and link `https://docs.deno.com/runtime/getting_started/installation/`. Stop here.

2. **Install bnd**
   - Default mode (`--global` or no arg): `deno install --global -A -n bnd jsr:@bandeira-tech/b3nd-cli`
   - Local mode (`--local`, for repo-scoped use): clone `https://github.com/bandeira-tech/b3nd-cli` somewhere obvious, then suggest `deno task dev` aliases.
   - Run the install command and stream output.

3. **Verify**
   - `bnd --version` (or `bnd help`) — confirm it runs.
   - If `~/.bnd/config.toml` does not exist, run `bnd config init` to scaffold a starter `~/.bnd/rig.ts`. Report where the file landed.

4. **Quick health check**
   - `bnd status` — show the resolved rig and whether it's reachable.
   - If status reports errors, briefly explain what likely needs fixing (rig file missing, connection unreachable) but don't try to fix them — that's the user's call.

5. **Next step prompt**
   Tell the user: "Your `bnd` is ready. Add or pick a rig target with `/b3nd:targets`, then restart Claude Code so the MCP server picks it up."

## Notes

- Do **not** modify `~/.bnd/config.toml` without confirming with the user. It is the user's own b3nd state.
- Do **not** install `bnd` silently when the user did not invoke this command.
- The MCP server wrapper lives at `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/mcp-server/bnd-mcp.sh` — it exec's `bnd node --mcp` against the active target.
