# Secrets and the KV engine

Outcome: your first stored secret,
written and read with both the CLI and
the HTTP API, in a fictional print
shop's service — and a clear picture
of where a KV path really points.

## The fixture: Inkwell Print Co.

Every example in this guide belongs to
a small fictional business, the
**Inkwell Print Co.**, and its orders
web service, which needs two secrets:
a database password and an API key.
Nothing about Inkwell is real; that is
the point of a fixture.

## KV version 2, and the path inside the path

The dev server mounts the **KV engine**
at `secret/`, in its **version 2**
form. KV v2 stores, for each secret, a
set of named **versions** plus
**metadata** about them. That split
shows up in the paths, and it is the
one thing newcomers trip on:

- Data lives at `secret/data/<name>`.
- Metadata lives at `secret/metadata/<name>`.

The CLI hides the split for ordinary
work: you say `secret/inkwell/orders`
and it talks to the `data/` path for
you. The HTTP API does not hide it —
chapter 9 uses the full paths. Policy
documents (next-but-one chapter) are
written against the *real* paths,
`data/` included, which is why the
lab's policy names
`secret/data/inkwell/orders`.

## Write, then read

```bash
vault kv put secret/inkwell/orders \
  db_password='inkwell-db-pass-v1' api_key='ink-1111-orders'
```

Vault answers with the metadata of
what it just made (transcript
`vault-lab/transcripts/t02-kv-write-read.txt`):
the secret path `secret/data/inkwell/orders`,
a `created_time`, `destroyed: false`,
and `version: 1`. The values themselves
are not echoed by `put`; read them
back:

```bash
vault kv get secret/inkwell/orders
```

```
======= Data =======
Key            Value
---            -----
api_key        ink-1111-orders
db_password    inkwell-db-pass-v1
```

Two smaller forms earn their keep
quickly: `vault kv get -field=db_password
secret/inkwell/orders` prints one value
and nothing else, which is how scripts
consume secrets; and `-format=json`
prints the whole answer as JSON.

The same read over the API — the CLI
is a client of it, never forget — is:

```bash
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://127.0.0.1:18081/v1/secret/data/inkwell/orders
```

whose answer wraps the values in
`data.data` and the bookkeeping in
`data.metadata`, with `"version": 1`.
That wrapping is KV v2's shape, and
chapter 9 dwells on it.

## Writing again makes a version, not a mess

Write the same path with a changed
password:

```bash
vault kv put secret/inkwell/orders \
  db_password='inkwell-db-pass-v2' api_key='ink-1111-orders'
```

Vault does not overwrite and pray. It
stores **version 2** and leaves
version 1 intact:

```bash
vault kv get -version=1 secret/inkwell/orders   # db_password ...-v1
vault kv get secret/inkwell/orders              # db_password ...-v2
```

Both answers are in transcript t02,
with their metadata side by side: same
path, same API key, two passwords, two
`created_time` values about a second
apart. This is the chapter 1 rule in
its gentlest form: the secret is on
loan from a system that remembers
every edition of it, so a rotation
that breaks a service can be undone by
reading the previous version — and
chapter 6 shows the rollback command
that makes that official, plus the
delete and destroy operations that end
a version's life two different ways.

A note on what a `kv put` replaces:
each version holds the **complete** set
of fields you give it. A `put` that
mentions only `db_password` creates a
version whose only field is
`db_password` — KV does not merge with
the previous version. The lab's second
write repeated `api_key` on purpose,
for exactly this reason.

Check: write a two-field secret, read
it back, write it again with one field
changed, then read `-version=1` and
the latest version and confirm the old
value survives in the old version. If
both reads match the lab's pattern,
you hold the KV engine's core idea.
