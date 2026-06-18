# START — the door

Read this when the user is new to B3nd, or you need to ground yourself before talking about it.

This is the plainest version of the pitch. No jargon until the second half. Use it when the user is not a framework nerd — when they're a builder, an entrepreneur, or someone using AI to modernize what they do and they've just heard "b3nd" for the first time.

## The promise, in one paragraph

You have data. It lives in too many places: chat tools, notes apps, your filesystem, three cloud accounts, that one spreadsheet. Every app that touches it has its own copy and its own rules. When you want a new app — built by you, by an agent, anyone — you start from zero again. **B3nd is the substrate that fixes that.** You run a small thing called a *rig* on your computer (and optionally on a node somewhere). Apps don't have their own databases — they read and write through your rig, into your storage. AI agents read and write the same way. You get to keep your data; the apps get to be tiny.

That's the whole idea. The rest of the framework is what makes it actually work.

## What this looks like in practice

- You ask Claude (or any agent) to build you a thing — a habit tracker, a CRM for your dog-walking business, a personal knowledge graph, a marketplace, anything.
- Claude does **not** spin up a server. It writes a small *protocol* — the shape of the data — and a UI that reads and writes that shape.
- Your rig is the only thing that stores anything. The UI is just glass. The protocol is just rules.
- Tomorrow you want a different UI for the same data? Build a different glass. Same protocol. Same rig. Same data.
- Next week you want an agent that helps you make decisions over that data? Point it at the same rig. It reads and writes the same URIs.

What changes for the user: you stop thinking about "which app holds my data". The answer is always **your rig**. Apps come and go on top.

## Who this is for

- **Builders.** People shipping things — solo, small team, agency. You want fewer moving parts and more leverage. B3nd lets you write the rules once and reuse them across every surface (CLI, web, MCP, server).
- **Entrepreneurs modernizing operations with AI.** You want digital tools that fit your business, not the other way around. With B3nd you accumulate one data substrate that every AI tool and every custom app you ever build can read. It compounds.
- **Protocol designers and DePIN engineers.** You're designing the shape of something other people will compose on. B3nd is built for this — programs and handlers are first-class, schemes are deliberate, the trust model is in your hands.

You don't have to be all three. You don't have to know which one you are yet.

## What you do not have to do

- You do not have to deploy a server to start.
- You do not have to pick a database. Pick one later. Swap it whenever.
- You do not have to write an API. The "API" is the URI shape.
- You do not have to learn a new query language. You read URIs and observe URI patterns.

## The four words

When you go deeper into this skill you'll see four words used constantly. Translate them on first contact and the rest is easy:

| Word | Plain version |
|---|---|
| **rig** | the little wiring diagram that holds your data and decides who can read/write what |
| **URI** | the address of a piece of data. `myapp://posts/2026-06-18` is a URI. |
| **program** | a function that looks at an incoming write and says "this should be stored at URI X" or "this should also trigger Y". It does not write anything itself. |
| **handler** | a function that takes the instruction a program emitted and produces the actual `[uri, payload]` to store or send |

A program is a thinker. A handler is a translator. The rig is the postman. The URIs are the addresses. The storage is the file cabinet. You can swap any piece without breaking the others.

## Why not "just build a service"

Because services bake everything together: data, rules, transport, storage, UI, deploy. Change one and the whole thing trembles. B3nd splits them. The cost is one more abstraction (codes, between programs and handlers); the payoff is enormous when you have more than one app, more than one storage backend, or more than one surface (CLI + browser + MCP) — which, once you start, you always do.

There's a longer version of this argument in [DATA_ORIENTED.md](./DATA_ORIENTED.md). Read it when the user asks "why this and not Express", or when you yourself reach for service-shaped scaffolding by reflex.

## Where to go from here

- "How do I install this and get a rig running?" → `/b3nd:install`, then `/b3nd:targets` to pick or add a target.
- "Help me build my first app." → `/b3nd:new-app`. The command walks the whole thing.
- "I want the architecture pitch in detail." → DATA_ORIENTED.md.
- "I want the package list and current API surface." → TARGETS.md.

## One thing to remember

B3nd is pre-1.0. The shape (rig / URI / program / handler / code) is stable; the package boundaries and exact APIs are not. When something looks off, it might genuinely be off. See CONTRIBUTING.md — the culture is *fix and upstream*, not work around.
