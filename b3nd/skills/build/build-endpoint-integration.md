# Build a B3nd endpoint integration into an existing system

To emit Outputs downstream from a flow you already have, map your domain result
into `Output[]` and hand it to a PIN's `receive`. The mapping is pure; the PIN
behind it is a swap.

### 1. Map your domain result → `Output[]` — a pure function

```ts
import type { Output } from "@bandeira-tech/b3nd-core";

// no b3nd calls here — just your shapes → addressed tuples
function mapOrderToOutputs(o: MyOrder): Output[] {
  return [
    [`mutable://orders/${o.id}`, o],
    [`mutable://orders/by-customer/${o.customer}/${o.id}`, { ref: o.id }],
  ];
}
```

### 2. Call a PIN's `receive` from the existing operation

```ts
import type { ProtocolInterfaceNode } from "@bandeira-tech/b3nd-core/types";

// the PIN is injected — the legacy flow never names its backend
async function existingOperation(pin: ProtocolInterfaceNode, data: MyData): Promise<void> {
  const order = /* ...existing work... */ toOrder(data);
  // receive returns problems as data — one ReceiveResult per output, never throws
  // for domain rejects (see build-error-handling.md). payload must match the PIN's
  // contract: objects if a SaveClient mapper encodes them, Uint8Array for raw move clients.
  const results = await pin.receive(mapOrderToOutputs(order));
  const failed = results.filter((r) => !r.accepted);
  if (failed.length) throw new Error(failed.map((r) => r.error).join("; ")); // your policy
}
```

### 3. Point the flow at any PIN — a local rig now, a remote server later

```ts
import { connection, Rig } from "@bandeira-tech/b3nd-core";

// `backend` is any storage PIN (SaveClient, ... — see build-backend-app.md).
// mapOrderToOutputs is untouched; only the PIN behind the rig changes.
const rig = new Rig({ routes: { receive: [connection(backend, ["mutable://orders/**"])] } });
await existingOperation(rig, data);
// emitting to a raw move client instead? encode payloads to Uint8Array first —
// see build-web-app.md (client) and build-backend-app.md (server).
```
