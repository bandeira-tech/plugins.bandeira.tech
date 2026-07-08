# Build a B3nd CLI app — local-first, pluggable

A terminal app whose state lives on disk (no server) by backing it with a
`b3nd-save` store client. Commands are thin wrappers over the four verbs, so the
same command set runs against a local store today and a remote target later.

### The backing store is a PIN — `SaveClient` wraps any store

```ts
// SaveClient(mapper, entity, store) → a ProtocolInterfaceNode (receive/read/observe/status).
// the mapper is your seam: mapToBytes = opaque bytes, or your own SaveMapper<T> to
// encode a typed record into BYTES_ENTITY (see k3p's clipToBytes).
import { SaveClient, mapToBytes } from "@bandeira-tech/b3nd-save/clients";
import { BYTES_ENTITY } from "@bandeira-tech/b3nd-save";

async function openStore(store /* any EntityStore */) {
  await store.provisionEntity(store.entitySupport(BYTES_ENTITY)); // caller's job, once at boot
  return new SaveClient(mapToBytes, BYTES_ENTITY, store);
}
```

### Filesystem store — `FsStore(rootDir, executor)`, Deno-native executor

```ts
import { FsStore, type FsExecutor } from "@bandeira-tech/b3nd-save/fs";
import { ensureDir } from "jsr:@std/fs/ensure-dir";
import { walk } from "jsr:@std/fs/walk";
import { dirname, relative } from "jsr:@std/path";

const denoFs: FsExecutor = {
  readFile: async (p) => (await Deno.open(p, { read: true })).readable,
  writeFile: async (p, c /* Uint8Array | ReadableStream<Uint8Array> */) => {
    await ensureDir(dirname(p));
    if (c instanceof Uint8Array) return Deno.writeFile(p, c);
    await c.pipeTo((await Deno.open(p, { write: true, create: true, truncate: true })).writable);
  },
  removeFile: (p) => Deno.remove(p),
  exists: async (p) => { try { await Deno.stat(p); return true; } catch { return false; } },
  listFiles: async (dir) => {
    const out: string[] = [];
    try { for await (const e of Deno.readDir(dir)) if (e.isFile) out.push(e.name); } catch { /* empty */ }
    return out;
  },
  // walkFiles is only needed for deep `?fn=find`; omit it if you only `?fn=ls` (like k3p)
  walkFiles: async function* (dir) {
    try {
      for await (const e of walk(dir, { includeDirs: false, includeFiles: true }))
        yield relative(dir, e.path).replaceAll("\\", "/");
    } catch { /* missing dir → yield nothing */ }
  },
};

const store = new FsStore(`${Deno.env.get("HOME")}/.myapp/data`, denoFs);
```

### SQLite store — `SqliteStore(tablePrefix, executor)`, `@db/sqlite` executor

```ts
import { SqliteStore, type SqliteExecutor } from "@bandeira-tech/b3nd-save/sqlite";
import { type BindValue, Database } from "jsr:@db/sqlite@0.12";

const db = new Database(`${Deno.env.get("HOME")}/.myapp/app.db`);
const isQuery = (sql: string) => /^\s*(SELECT|PRAGMA|WITH|EXPLAIN)\b/i.test(sql);

const sqlite: SqliteExecutor = {
  query: (sql, args) => {
    const stmt = db.prepare(sql);
    if (isQuery(sql)) {
      const rows = stmt.all(...((args ?? []) as BindValue[])) as Record<string, unknown>[];
      return { rows, rowCount: rows.length };
    }
    stmt.run(...((args ?? []) as BindValue[]));
    return { rows: [], rowCount: db.changes };
  },
  transaction: (fn) => { db.exec("BEGIN"); try { const r = fn(sqlite); db.exec("COMMIT"); return r; } catch (e) { db.exec("ROLLBACK"); throw e; } },
};

const store = new SqliteStore("myapp", sqlite);
```

### Command handlers — thin wrappers over the verbs

```ts
// `node` is the SaveClient from openStore(...). Commands never touch the backend.
const enc = new TextEncoder();
const dec = new TextDecoder();

// write: `myapp add <id> <text>`  → receive
async function add(node, id: string, text: string) {
  const [r] = await node.receive([[`mutable://notes/${id}`, enc.encode(text)]]);
  if (!r.accepted) throw new Error(r.error);
}

// query one: `myapp get <id>`  → read (bare URI, no ?fn=)
async function get(node, id: string) {
  const [hit] = await node.read([`mutable://notes/${id}`]); // read is 1:1 — tuple always present
  return hit?.[1] != null ? dec.decode(hit[1] as Uint8Array) : undefined; // check payload, not tuple
}

// list: `myapp ls`  → read with the ls grammar (wildcards REQUIRE explicit ?fn=)
async function ls(node) {
  const [[, uris]] = await node.read([`mutable://notes/*?fn=ls&format=uris`]);
  return uris as string[]; // deep listing → `**?fn=find`; tally → `?fn=count`
}

// delete: payload null is delete-by-convention
async function rm(node, id: string) {
  await node.receive([[`mutable://notes/${id}`, null]]);
}
```

### Watch — `observe` a pattern, `read` each fired URI

```ts
// `myapp watch` — long-running; Ctrl+C aborts.
async function watch(node) {
  const abort = new AbortController();
  Deno.addSignalListener("SIGINT", () => abort.abort());
  for await (const uris of node.observe(["mutable://notes/**"], abort.signal))
    for (const [uri, payload] of await node.read([...uris])) render(uri, payload); // render(): your output
}
```

### Pluggable — swap the store, command code is untouched

```ts
import { HttpClient } from "@bandeira-tech/b3nd-move/http/client";
import { httpOutputsFrame } from "@bandeira-tech/b3nd-move/codecs/http";

// One factory picks the backend; handlers only ever see a PIN.
const dir = `${Deno.env.get("HOME")}/.myapp/data`;
async function backend(kind: "fs" | "sqlite" | "remote") {
  switch (kind) {
    case "fs":     return openStore(new FsStore(dir, denoFs));
    case "sqlite": return openStore(new SqliteStore("myapp", sqlite));
    // codec must match the server's (see build-web-app.md); already a PIN, no provision
    case "remote": return new HttpClient({ url: myUrl, codec: httpOutputsFrame() });
  }
}
const node = await backend(Deno.env.get("MYAPP_STORE") ?? "fs");
```

### Or skip the argv plumbing — host the store as a `bnd` rig module

```ts
// b3nd.rig.ts — default-export a Rig (or a function returning one). `bnd` drives every verb.
import { connection, Rig } from "jsr:@bandeira-tech/b3nd-core@^0.24.0/rig";

export default async () => {
  const node = await openStore(new FsStore(`${Deno.env.get("HOME")}/.myapp/data`, denoFs));
  const all = connection(node, ["mutable://**"]);
  return new Rig({ routes: { receive: [all], read: [all], observe: [all] } });
};
```

```bash
# The rig module is the whole app; bnd is the terminal driver.
echo '["mutable://notes/1", "hello"]' | bnd receive -   # write
bnd read 'mutable://notes/1'                             # query one
bnd read 'mutable://notes/*?fn=ls&format=uris'           # list
bnd observe 'mutable://notes/**'                         # watch
bnd node --http --mcp-http                               # same rig as HTTP + MCP-over-HTTP endpoints
```
