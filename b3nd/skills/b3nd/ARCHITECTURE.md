# ARCHITECTURE — Data Oriented Architecture

**Data Oriented Architecture (DOA)** designs an application by first naming its data. Every fact gets a URI. Every URI prefix has a program that classifies writes and a handler that emits the persisted outputs. The application's contract *is* the URI table plus the programs and handlers attached to it. There is no service tier above the data; the rig is the runtime.

Translated to b3nd:

- **The topology is the URI table.** Identifiers, relations, indexes, content-addressed blobs, append-only event logs — each is one URI pattern. Designing the app means choosing those patterns.
- **The contract is `{ programs, handlers }`.** Programs classify each incoming `[uri, payload]` message into a code. Handlers turn the code into the `Output[]` the rig dispatches. Both pure. The contract travels as one module that imports the same way into a server, a browser bundle, an in-process consumer, and an MCP boot script.
- **The rig wires it mechanically.** Routes bind URI patterns to PIN clients (storage and upstream nodes). Transports expose the rig over HTTP / WS / gRPC / MCP / in-process. Apps `receive`, `read`, and `observe`. No per-feature endpoint exists or is needed: the URI grammar *is* the API.

When a new consumer arrives — another app, another agent, another device — it doesn't get a new endpoint. It gets a URI prefix it didn't have before and the protocol module to interpret it. Connection happens at the data layer.

## A concrete protocol — ecommerce

Mounted under `shop://` for clarity (in production prefer behavior-named bases like `signed://<merchant-key>/shop/` or `encrypted://shop/customers/`; the protocol module accepts the basepath as a factory parameter so the mount is the user's call, not the app vendor's).

| URI pattern | Role |
|---|---|
| `shop://catalog/p/<sku>/data/<field>` | Product fields (title, price, description) — one field per write |
| `shop://catalog/p/<sku>/images/<n>` | Image references; payload is `hash://sha256/...` |
| `hash://sha256/<digest>` | Image (and other) blob bytes; integrity self-evident |
| `shop://catalog/index/by-category/<category>/<sku>` | Derived index; rebuildable from `catalog/p/**` |
| `shop://inventory/p/<sku>/data/on-hand` | Current stock count |
| `shop://inventory/p/<sku>/entries/<ts>-<kind>` | Append-only stock movements (`received`, `sold`, `adjusted`, `reserved`) |
| `shop://customers/c/<customer-id>/data/<field>` | Customer profile fields |
| `shop://orders/o/<order-id>/data/<field>` | Order header (customer, total, currency) |
| `shop://orders/o/<order-id>/lines/<n>` | Order line items (sku, qty, unit-price) |
| `shop://orders/o/<order-id>/entries/<ts>-<kind>` | Order event log (`placed`, `paid`, `picked`, `shipped`, `refunded`) |
| `shop://orders/index/by-customer/<customer-id>/<ts>-<order-id>` | Customer's orders, time-sorted |
| `shop://fulfillment/shipments/s/<shipment-id>/data/<field>` | Shipment header (carrier, tracking, status) |
| `shop://fulfillment/shipments/s/<shipment-id>/orders/<order-id>` | Shipment ↔ order relation |

Programs are keyed by prefix (`shop://catalog/`, `shop://inventory/`, `shop://orders/`, `shop://fulfillment/`, `shop://customers/`, `hash://sha256/`). Order status, on-hand quantity, customer order history are **derivable from URI listings** — not stored as fields. A read at `shop://orders/o/<id>` folds the subtree on the node side; status is computed from the entries listing.

That table is the design. Everything else — services, UI, agents, replication — composes onto it.

## Three integration patterns

Each pattern brings b3nd into an existing system at a different layer. They are not mutually exclusive; teams often start with sink and migrate toward backend over time.

### Sink — b3nd captures a copy the owner controls

The existing ecommerce stack (Shopify, WooCommerce, custom Rails, whatever) remains primary. A small worker tails the legacy webhook stream and `receive`s tuples into a b3nd rig the owner runs. The merchant (or each customer) now has a portable, queryable copy of their data they fully own.

- **Where the data contract lives:** the protocol module.
- **What enforces it:** the rig's programs/handlers on ingest — refused writes never persist. The legacy store remains source of truth; b3nd is the durable mirror.
- **When to pick it:** the existing system is fine; you want ownership and portability without migration.

### Trigger — b3nd is the front door; hooks fan out

The storefront writes directly to the rig. Programs validate (is this a signed order from this customer key?); handlers persist canonically. Hooks and events on the rig fan changes out to existing services — Stripe charge fires on `orders/o/<id>/entries/<ts>-placed`, ShipStation on `entries/<ts>-paid`, mailer on `entries/<ts>-shipped`.

- **Where the data contract lives:** the protocol module. Downstream services become observers, not gatekeepers.
- **What enforces it:** programs, before any external call. Refusals surface without round-tripping through downstream services.
- **When to pick it:** you want one canonical inbox for orders and one place to add new reactions; downstream services should not own the protocol.

### Backend — b3nd is the data layer; everything else is a consumer

The catalog admin, the storefront, the warehouse picker UI, and the analytics consumer are all `receive`/`read`/`observe` clients of the same rig. Operators pin the rig across regions; reads serve locally, receives propagate. A new "loyalty" feature is a new URI prefix (`shop://loyalty/`) and a new program — no new service.

- **Where the data contract lives:** the protocol module — the only contract any consumer depends on.
- **What enforces it:** the rig, uniformly, regardless of which transport the consumer uses (HTTP, WS, gRPC, MCP, in-process).
- **When to pick it:** new build, or willing to migrate; you want one place the data contract lives, with other tools as thin readers and writers against it.

## Anti-patterns — SOA reflexes leaking in

These are the ways DOA is undone in practice. None of them throw an error; all of them cost the architecture its leverage.

**Bespoke verbs on top of the rig.**
Shipping `create_order` / `list_orders` MCP tools or `POST /orders` HTTP endpoints instead of letting `b3nd_receive` and `b3nd_read` carry the URI grammar. If a consumer (a UI, an agent, a downstream service) has to learn verbs *and* URIs to interact, the data contract is no longer load-bearing — it's been demoted to a parameter of a service tier.

**Domain-named schemes for every concern.**
Inventing `order://`, `customer://`, `product://` when behavior-named schemes (`signed://`, `immutable://`, `encrypted://`, `hash://`) would compose. Schemes should name *behavior*; paths name the application. One concrete sign of this anti-pattern: every new app reinvents its own foundational surface (signing, integrity, encryption) from scratch.

**Record-shaped payloads where a URI subtree would do.**
Writing the whole order as one JSON blob at `shop://orders/o/<id>`, then read-modify-write for every line edit or status change. Decompose into `data/`, `entries/`, `lines/`. Editing a line is one write. Status derives from the entries listing. The subtree is the record.

**Programs that store, mutate, or network.**
Treating a program as "the controller" — calling out to Stripe, writing to a DB, emitting metrics, reading `Date.now()`. Programs are pure classifiers from `[uri, payload]` to codes. Side effects belong in handlers (which return outputs for the rig to dispatch) or in reactions (which fire after broadcast lands). If your program has an `await` for I/O, it isn't a program anymore.

**Hard-coded scheme or basepath in the protocol module.**
Shipping a protocol that only works at `shop://`. The factory pattern — `shopProtocol("signed://0xMerchant/shop/")` — is what lets the *user* decide where the data lives. Without it, the app becomes the moat. A protocol whose basepath is a constant is a protocol that can't be composed into anyone else's rig.

## See also

- [APP.md](./APP.md) — the build flow: URI table → programs → handlers → UI.
- [RIG.md](./RIG.md) — how the rig wires the protocol mechanically.
- [CONTRIBUTING.md](./CONTRIBUTING.md) — when the framework gets in the way, fix and upstream.
