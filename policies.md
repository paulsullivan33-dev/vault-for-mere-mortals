# Policies

Outcome: a policy that permits exactly
one path, a token created under it,
and — the heart of this guide — the
recorded moment Vault refuses that
token everywhere else.

## What a policy is

A **policy** is a named document in
**HCL**, HashiCorp's configuration
language, made of **path rules**. Each
rule names a path and the
**capabilities** allowed on it. The
capabilities are `create`, `read`,
`update`, `delete`, `list`, plus
`deny` (an explicit refusal that wins
over other grants) and `sudo` (for a
small set of protected system paths).

The default is the important part:
**a path no rule mentions is denied.**
A policy is not a list of bans with
everything else open; it is a list of
permissions with everything else shut.
Every token also carries the built-in
`default` policy, which grants a few
self-service abilities (looking up and
renewing its own token, for example) —
the lab's token listings show
`[default inkwell-reader]`, and the
`default` half explains itself there.

## The lab's policy: one path, read only

The Inkwell orders service needs to
read one secret and nothing else in
the world. The whole policy
(`vault-lab/fixtures/inkwell-reader.hcl`)
is:

```hcl
# Inkwell Print Co. — the orders service may READ exactly one secret.
path "secret/data/inkwell/orders" {
  capabilities = ["read"]
}
```

Note the path: `secret/data/...`, the
real KV v2 data path from chapter 5,
not the CLI's shortened spelling.
Policies are written against the API's
paths, because the API is where they
are enforced.

Install and inspect it:

```bash
vault policy write inkwell-reader vault-lab/fixtures/inkwell-reader.hcl
# Success! Uploaded policy: inkwell-reader

vault policy read inkwell-reader
# prints the document back, word for word
```

## A token under the policy

```bash
vault token create -policy=inkwell-reader \
  -display-name=inkwell-orders-service -format=json
```

The answer (transcript
`vault-lab/transcripts/t04-policy-and-token.txt`)
carries a `client_token` — a string
beginning `hvs.`, the token itself —
the `policies` list
`["default", "inkwell-reader"]`, and a
`lease_duration` of 2764800 seconds:
768 hours, the dev mount's default
token lifetime. Tokens created at a
terminal like this are how a lab (and
a small deployment) hands a service
its credentials; chapter 8 takes the
token's own life apart. The token
*value* printed in the transcript is a
lab throwaway from a server that no
longer exists — printed because a
reader should see what a token looks
like, and worthless anywhere else.

## The denial, which is the point

First, the allowed thing, both ways
(transcript
`vault-lab/transcripts/t04b-policy-denial.txt`).
With the limited token in `VAULT_TOKEN`,
`vault kv get secret/inkwell/orders`
returns the secret, and the same read
over curl returns its data. The policy
is not a wall around the service; it
is a door cut to exactly its size.

Then the same token reaches for the
neighbouring secret,
`secret/inkwell/billing`, which root
wrote earlier in the run:

```
Error reading secret/data/inkwell/billing: Error making API request.

URL: GET http://127.0.0.1:18081/v1/secret/data/inkwell/billing
Code: 403. Errors:

* 1 error occurred:
	* permission denied
```

Over curl the refusal is the same fact
in API clothing: the body
`{"errors":["1 error occurred:\n\t* permission denied\n\n"]}`
with **HTTP_STATUS=403**.

Two more refusals complete the shape
of "read exactly one path". The token
cannot **write** to its own allowed
path — the rule grants `read`, not
`create` or `update` — and it cannot
even **list the mounts** (`sys/mounts`),
because seeing the system's shape is
also a permission it was never given.
Both attempts answer 403 in the same
transcript. Last, the control check:
the **root** token reads
`secret/inkwell/billing` without
trouble, which proves the secret was
there all along and the 403s were the
policy working — not missing data, not
a broken server.

This is what least privilege looks
like when it is enforced by the store
instead of by convention. If the
orders service is compromised, the
attacker inherits a token that can
read one secret, cannot write
anything, cannot explore, and — chapter
8 — can be revoked in one command,
after which it is a string that opens
nothing.

## Writing policies that stay small

- One policy per kind of caller, named
  for the caller (`inkwell-reader`),
  not for the secret.
- Grant capabilities one at a time.
  `read` is not implied by `list`, and
  neither implies `update`.
- Prefer exact paths. Vault supports
  globs (`secret/data/inkwell/*`) and
  they are sometimes right; every glob
  is a decision to trust future secrets
  under that prefix with today's
  policy.
- Remember the `data/` and `metadata/`
  split: reading a KV v2 secret's
  metadata is a separate path and a
  separate grant.

Check: write the one-path policy,
create a token under it, and run the
four attempts yourself — allowed read,
neighbouring read, write to the
allowed path, mount list. One success
and three 403s, matching the lab's
transcript, means the policy — and
this chapter — did its work.
