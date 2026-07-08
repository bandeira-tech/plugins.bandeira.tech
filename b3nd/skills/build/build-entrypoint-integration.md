# Build a B3nd entrypoint integration into an existing system

To drive a flow you already have from b3nd, either wrap it as a PIN whose
`receive` calls through to it, or run a worker that `observe`s a pattern and
triggers it. Same existing operation, two trigger shapes.

### Mode A — call-through: a PIN whose `receive` invokes the existing operation

```ts
import { FunctionalClient, type Output, type ReceiveResult } from "@bandeira-tech/b3nd-core";

// wrap the legacy system as a write-only PIN; every received Output calls through.
// return problems as data (accepted:false) — don't throw for a domain failure.
function integrationPin(existing: { run(args: MyArgs): Promise<void> }): FunctionalClient {
  return new FunctionalClient({
    receive: (msgs: Output[]): Promise<ReceiveResult[]> =>
      Promise.all(msgs.map(async ([uri, payload]): Promise<ReceiveResult> => {
        try {
          await existing.run(toArgs(uri, payload)); // your mapping: Output → call args
          return { accepted: true };
        } catch (e) {
          return { accepted: false, error: e instanceof Error ? e.message : String(e) };
        }
      })),
  });
}
// wire it into a rig route so writes to your prefix trigger the flow:
//   new Rig({ routes: { receive: [connection(integrationPin(existing), ["job://**"])] } })
```

### Mode B — observe trigger: a worker watches a pattern and fires the flow

```ts
import type { ProtocolInterfaceNode } from "@bandeira-tech/b3nd-core/types";

// long-running: observe emits changed uris; read each, then call through.
async function integrationWorker(
  pin: ProtocolInterfaceNode,
  existing: { run(a: MyArgs): Promise<void> },
): Promise<void> {
  const abort = new AbortController();
  for await (const uris of pin.observe(["mutable://jobs/**"], abort.signal))
    for (const [uri, payload] of await pin.read([...uris]))
      await existing.run(toArgs(uri, payload));
  // observe swallows per-source errors and re-reads current state on resubscribe —
  // it carries no delivery guarantee. See build-error-handling.md.
}
```
