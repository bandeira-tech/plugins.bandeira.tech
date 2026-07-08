# Authoring convention — `build/` reference files

These files are a **menu of code**, not essays. Whoever reads them can get the
concepts elsewhere (`learn`, the source). Here, the code does the talking.

## Shape of every reference file

1. A `#` title naming the build target.
2. A blurb — one or two sentences on when you'd reach for this. No more.
3. The body: a sequence of code blocks, each preceded by a **one-line lead** —
   a short `###` header or a single sentence naming what the block shows. One
   line, no more. It labels the block; it does not explain it. Let the code
   speak below it.

**Model to match:** `build-client-module.md` and `build-error-handling.md` —
verified TS at the right density. Match their code-first shape: a one-line lead,
then a block that speaks for itself. If a file has grown paragraphs of
explanation, it has drifted.

## Rules

- **No prose walkthroughs.** Don't explain the thinking behind the code or
  narrate lines in paragraphs. A short `// comment` inside a block is fine; a
  paragraph after it is not.
- **Show shape, not a locked frame.** An example demonstrates the interface and
  the move — it is not the one blessed design. Keep it schematic enough that
  another context pack can bring a different frame without fighting ours.
  Placeholders (`myUri`, `...`, `/* your check */`) are good — they say "your
  call here."
- **One example per idea.** Not five variations. Distinct modes get one small
  block each (see entrypoint: call-through vs. observe).
- **RULE 0 still holds.** Code reflects current source shape; names verified
  against `b3nd-core` / `-move` / `-save`. Minimal, adaptable — not copied
  wholesale.
- **`SKILL.md` is exempt.** It is the router + RULE 0, not a reference file.

**Why:** prose freezes a design direction. The interface is stable; the framings
around it are not. Ship the stable part — the code shape — and leave the framing
to whoever loads this next.
