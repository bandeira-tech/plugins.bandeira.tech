#!/usr/bin/env bash
# bnd-mcp.sh — launch `bnd node --mcp` against the user's active rig target.
#
# Resolution (first wins):
#   1. $B3ND_RIG                          — explicit override
#   2. active target in ~/.bnd/targets.toml
#   3. let `bnd` resolve via its own config (~/.bnd/config.toml or ./b3nd.rig.ts)
#
# Stdout is reserved for the MCP JSON-RPC stream. All chatter goes to stderr.

set -u

log() { printf '[b3nd-mcp] %s\n' "$*" >&2; }

if ! command -v bnd >/dev/null 2>&1; then
  log "the \`bnd\` CLI is not on PATH."
  log "run the /b3nd:install slash command to set it up, or install manually:"
  log "  deno install --global -A -n bnd jsr:@bandeira-tech/b3nd-cli"
  exit 127
fi

TARGETS_FILE="${B3ND_TARGETS_FILE:-$HOME/.bnd/targets.toml}"

# Resolve rig from B3ND_RIG > targets file > bnd's own resolution.
RIG="${B3ND_RIG:-}"

if [ -z "$RIG" ] && [ -f "$TARGETS_FILE" ]; then
  # Minimal TOML read — find `active = "<name>"`, then `[target.<name>]` block's `rig = "..."`.
  ACTIVE=$(awk -F'=' '/^[[:space:]]*active[[:space:]]*=/ { gsub(/[[:space:]"]/,"",$2); print $2; exit }' "$TARGETS_FILE")
  if [ -n "$ACTIVE" ]; then
    RIG=$(awk -v t="[target.$ACTIVE]" '
      $0 == t { inblk = 1; next }
      /^\[/ { inblk = 0 }
      inblk && $1 ~ /^rig[[:space:]]*$/ {
        sub(/^[^=]*=[[:space:]]*/, "")
        gsub(/^"|"$/, "")
        print
        exit
      }
      inblk && /^[[:space:]]*rig[[:space:]]*=/ {
        sub(/^[[:space:]]*rig[[:space:]]*=[[:space:]]*/, "")
        gsub(/^"|"$/, "")
        print
        exit
      }
    ' "$TARGETS_FILE")
    [ -n "$RIG" ] && log "target '$ACTIVE' → rig $RIG"
  fi
fi

if [ -n "$RIG" ]; then
  exec bnd node --mcp --rig "$RIG"
else
  log "no explicit target; using bnd's default rig resolution."
  exec bnd node --mcp
fi
