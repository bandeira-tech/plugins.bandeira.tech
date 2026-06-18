# DATA_ORIENTED — why B3nd looks the way it does

> STUB — fill in iteratively. Outline below; expand as the skill matures.

## Argument to make

- Service-oriented design glues data + rules + transport + storage + UI + deploy.
- B3nd splits them by giving data a first-class addressable identity (URI) and routing decisions to small pure pieces (program, handler).
- "SOA on top of b3nd" produces an ugly hybrid — concretely show what that looks like and why it's worse than either pure pattern.
- "Data-first on b3nd" produces a powerhouse — the same primitives compose into a CLI tool, a browser app, a multi-user node, an MCP server, an agent's memory.

## Concrete contrasts to write

- The "blog" example: SOA version (Express + Postgres + REST + frontend) vs. B3nd version (URIs + program + handler + rig + glass UI).
- The "AI memory" example: per-app vendor lock vs. one rig many agents.
- The "swap storage" story: ORM migration vs. swap a `connection(...)` line.

## What to warn about

- Smuggling service idioms into protocols (`POST /posts` thinking).
- Putting effects in programs.
- Putting business logic in handlers' I/O glue.

(Flesh out from the user's WHY.md and VISION.md material in `~/ws/b3nd-skill/skills/b3nd/` — but rewrite, do not transplant. The old material is "too much for too little".)
