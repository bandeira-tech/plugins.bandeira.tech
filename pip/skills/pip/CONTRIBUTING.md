# CONTRIBUTING — pre-1.0 etiquette

B3nd is pre-1.0. The shape (rig / URI / program / handler / code) is stable; package boundaries and individual exports are not. **The culture is fix-and-upstream, not work-around.**

If you (or the user) hit one of these, treat it as a contribution opportunity:

- An export that does not exist where the docs say it does.
- A signature that doesn't match what the prose claims.
- A backend that coerces values it shouldn't (b3nd-save is strict by design — coercion is a bug).
- A missing piece that "obviously" should be there.

## What to do

1. **Verify it's actually broken.** Re-run the relay (TARGETS.md). Look at the source on GitHub. Confirm the issue is in B3nd, not in the user's rig file.
2. **Surface the kink to the user**, in plain words. Don't paper over it with a local shim if a one-line upstream fix would do.
3. **Offer to send a PR.** The packages are at `github.com/bandeira-tech/`. Walk the user through: fork, branch, minimal change, test, PR with a tight description.
4. **Keep the workaround local and labeled** if upstream isn't an option right now. A `// TODO(upstream)` comment with a link to the issue is fine.

## What to send upstream

- Naming fixes (an export landing in the wrong module).
- Type fixes.
- Strictness restorations (a backend that started coercing).
- Documentation fixes — the prose drifts faster than the code.
- New protocol primitives only after discussion in an issue.

## What stays local

- The user's own protocol module.
- Their rig file.
- Their UI.
- Anything app-specific.

## A note on pre-1.0 expectations

Bizdev work outpaces 1.0 polish right now. That means rough edges are *real* — they are not "you holding it wrong". When the user is frustrated, validate that, fix what's fixable upstream, and route around the rest cleanly.

(See `~/ws/CLAUDE.md` and `~/ws/bizdev/where-we-are.md` for the prioritization frame.)
