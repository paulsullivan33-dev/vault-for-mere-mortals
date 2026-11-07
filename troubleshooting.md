# Troubleshooting

Outcome: the failures a new Vault user
actually meets — a sealed server, a
403, an empty read, a dead token, a
missing version — each matched to the
check that separates its causes.

Work from the outside in: is the
server reachable, is it unsealed, is
the token alive, does the policy
allow the path, does the thing exist?

## "Vault is sealed" / HTTP 503

**Symptom:** every request answers
`{"errors":["Vault is sealed"]}`, or
`vault status` reports `Sealed: true`.

**Cause:** the server restarted (a
real server seals on every start) or
someone sealed it.

**Fix:** unseal it — `vault operator
unseal` once per required key share —
or find out who sealed it and why
before unsealing, if the seal was
deliberate. The lab's seal/unseal
round trip is transcript t09. If a
dev server has "lost" its data after
a restart, that is dev mode working
as designed: its storage was memory,
and the fix is to re-run the setup,
not to look for the data.

## Code 403: permission denied

The most common answer in Vault, and
the most informative. Separate its
three causes in order:

1. **Invalid token.** The error body
   adds `invalid token` (the lab's
   post-revocation reads show both
   phrases together). The token is
   expired, revoked, or was never
   real. `vault token lookup` on it
   says which.
2. **Policy does not grant the path.**
   Check the exact API path —
   `secret/data/...`, not the CLI's
   short form — against the token's
   policies with `vault policy read`.
   Remember the KV split: grants for
   `data/` do not cover `metadata/`.
3. **Policy grants the wrong
   capability.** Reading needs `read`;
   `kv put` needs `create` or
   `update`; listing needs `list`. The
   lab's token could read its one
   path but not write it (transcript
   t04b) — same 403, third cause.

## A read returns nothing, or "no value found"

- **Soft-deleted version.** The read
  returns metadata with a
  `deletion_time` and no data. Read an
  older version by number, or
  `kv undelete` (chapter 6).
- **Destroyed version.** Metadata
  says `destroyed: true`. Permanent
  by design; restore from your own
  records or rotate in a new value.
- **Wrong mount or version flag.**
  KV v1 and v2 mounts answer at
  different path shapes; and
  `-version=N` reads history, not
  "the current value, approximately".

## The token died sooner than expected

Look it up early, while it lives:
`vault token lookup` shows `ttl`,
`expire_time`, and `explicit_max_ttl`.
The usual stories: the TTL was short
and nothing renewed it; a renewal hit
the explicit max TTL, which renewal
cannot cross; or a **parent was
revoked** — children die with parents
(chapter 8), including in bulk
cleanups nobody aimed at your token.

## `vault` talks to the wrong server, or none

`VAULT_ADDR` names the server. An
unset or stale one sends the CLI to
the default `https://127.0.0.1:8200` —
right for a stock production install,
wrong for this guide's lab
(`http://127.0.0.1:18081`). Connection
refused means the server is not
running (or not on that port);
certificate errors against a real
server mean TLS is doing its job and
your client's trust store is the
conversation to have — never silence
them with an insecure flag outside a
throwaway test.

## CLI arguments in the wrong order

Vault's CLI reads words after the
positional argument as more arguments,
not as flags. The lab's example:
`vault token renew -increment=120s
<token> -format=json` failed with
"Too many arguments (expected 1, got
2)". Put flags before the thing they
act on.

## Audit device will not enable, or requests stop

Enabling a file audit device fails if
Vault cannot write the path — check
ownership and the folder, not Vault.
And remember chapter 12's rule: if
**every** audit device fails at
request time, Vault refuses requests
rather than answer unrecorded. A
server that suddenly 5xxs everything
with a full disk is often this rule,
firing exactly as designed.

Check: the next time Vault refuses
you, name which of the five outer-in
questions — reachable, unsealed,
token alive, policy allows, thing
exists — your first command answers.
Refusals in Vault are precise; one
precise question at a time finds them.
