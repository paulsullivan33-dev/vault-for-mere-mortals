# The HTTP API

Outcome: the same Vault, spoken to
with nothing but `curl` — reads,
writes, and a refusal — and a clear
understanding that the CLI is a
convenience, not a gatekeeper.

## Everything is the API

There is exactly one door into Vault:
its **HTTP API**. Every path in this
guide is an API path with `/v1/` in
front of it. The `vault` CLI, the
client libraries, and the web UI are
all clients of that API. Nothing a
chapter does with the CLI is
CLI-magic; each command has an API
twin, and the lab used the twins
throughout so the transcripts prove
both spellings of the same facts.

Authentication travels in a header:

```
X-Vault-Token: <token>
```

The base address is the server's:
`http://127.0.0.1:18081` in the lab
(plain HTTP only because dev mode on
loopback; production Vault is HTTPS,
and the header above is exactly why it
must be).

## The requests this guide has already made twice

**Health and seal status** (chapter 4):
`GET /v1/sys/health` needs no token;
`GET /v1/sys/seal-status` reports the
seal. Both answers appeared as JSON in
transcript t01.

**Reading a KV v2 secret** (chapters 5
and 7):

```bash
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://127.0.0.1:18081/v1/secret/data/inkwell/orders
```

```json
{"data": {"data": {"api_key": "ink-1111-orders",
                   "db_password": "inkwell-db-pass-v1"},
           "metadata": {"version": 3, "...": "..."}}, "...": "..."}
```

Read the shape once and it stops being
surprising: the outer object is the
API's envelope (it also carries
`request_id`, `lease_duration`, and
friends); `data.data` is your secret;
`data.metadata` is KV v2's
bookkeeping. In transcript t04b the
limited token's successful API read
returned exactly the inner data object
— `{"api_key":"ink-1111-orders","db_password":"inkwell-db-pass-v1"}` —
the same bytes the CLI showed.

**The refusal** (chapter 7) is also an
API fact: the same URL with
`inkwell/billing` in it answered
**HTTP 403** and the body
`{"errors":["1 error occurred:\n\t* permission denied\n\n"]}`.
Errors are JSON with an `errors` list;
status codes carry the category —
**403** for permission and invalid
tokens, **503** while sealed (chapter
4's transcript shows `{"errors":["Vault is sealed"]}`),
**404** for a path with nothing in it.

**Encrypting with transit** (chapter
10) is a `POST` with a JSON body:

```bash
curl -H "X-Vault-Token: $VAULT_TOKEN" -X POST \
  -d '{"plaintext":"aW5rd2VsbC1kYi1wYXNzLXYy"}' \
  http://127.0.0.1:18081/v1/transit/encrypt/inkwell-orders
# {"data":{"ciphertext":"vault:v1:6sga...","key_version":1}, ...}
```

**Writing a KV secret** is a `POST`
(or `PUT`) to the data path with the
fields wrapped: `{"data": { ... }}`.
The CLI's `kv put` exists because that
wrapping is easy to forget; the guide
ran writes through the CLI and reads
through both, and the distinction is
stated here rather than hidden.

## Verbs, honestly mapped

The CLI's verbs map onto HTTP methods
with a few conventions worth knowing:
`vault kv get` is a `GET`; `vault read`
is a `GET`; `vault write` is a `POST`;
`vault delete` is a `DELETE`; listing
uses the non-standard `LIST` method,
with `GET` plus `?list=true` as the
portable spelling. Policy checks see
these as the capabilities of chapter
7: a `GET` needs `read`, a `POST` to a
new path can need `create` or
`update`, a listing needs `list`.

## Why this chapter exists

Because the API is the real surface,
anything that can make an HTTPS
request can use Vault — a shell script
with `curl`, a service in any language,
a deployment tool. When a chapter's
CLI command does not fit your
situation, the API form of the same
request will, and the transcripts give
you both for the operations that
matter most: read, encrypt, health,
seal status, and the 403 that proves
policy.

Check: with only `curl`, read the
orders secret as root, read it as the
limited token, and read the billing
secret as the limited token. Two JSON
answers and one 403 — the API chapter
in three commands, matching
transcripts t01 and t04b.
