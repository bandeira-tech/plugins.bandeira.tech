# Build a custom SaveMapper + typed entity on B3nd

Move past `mapToBytes` + `BYTES_ENTITY`: declare a typed `EntitySchema` and a
`SaveMapper` that projects wire payloads into records, unlocking the field-aware
read grammar. This is the "adopt more of `save`" step every app guide defers with
"see k3p's `clipToBytes`."

> **STATUS: STUB — not yet written.** Scaffolded so the gap is tracked and can be
> picked up outside this session. Follow RULE 0 and `CLAUDE.md` when filling it.

## To write — one code block per item

- [ ] A typed `EntitySchema` — fields + `TYPE_TAGS` (string/number/bigint/
      timestamp/bytes/json).
- [ ] `passThroughRecord` for wires that already carry the record shape.
- [ ] A custom `SaveMapper<T>` — wire `(uri, payload)` → `EntityRecord`
      (projection, decode, per-schema validation).
- [ ] The read grammar this unlocks — `sortBy=<field>`, `fields=`, `pattern=`
      over typed columns (vs. uri-only for bytes).
- [ ] Tradeoff note — bytes (opaque, any backend) vs. typed entity (queryable,
      per-backend native layout + push-down).
