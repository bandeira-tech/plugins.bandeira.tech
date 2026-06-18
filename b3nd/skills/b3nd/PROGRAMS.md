# PROGRAMS — classifiers → codes

> STUB — fill in iteratively.

## Cover

- Programs are pure: `(message) → Code[]`.
- A code is a small named instruction with a payload. Codes are the contract between programs and handlers.
- Common code kinds: store, derive, emit, validate-only.
- One program per ingest path; many small programs beats one big one.

## Smells

- Anything async or effectful in a program.
- "Codes" with no shape (e.g. `{ kind: "doStuff", whatever }`).
- Hard-coded URI scheme constants instead of protocol parameters.
