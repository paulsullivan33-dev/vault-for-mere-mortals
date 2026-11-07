# Tokens and leases

Outcome: the life of a token lived in
full — created with a lifetime,
looked up, renewed, used, and revoked
mid-life — plus the token tree:
children, and what happens to them
when a parent dies.

Everything in this chapter is from
transcript
`vault-lab/transcripts/t08-token-leases.txt`,
run against the lab's dev server.

## A token is a lease

Chapter 2 called a token a loan; here
is the paperwork. Create one
deliberately short-lived:

```bash
vault token create -policy=inkwell-reader \
  -ttl=120s -explicit-max-ttl=600s -format=json
# { "lease_duration": 120, "renewable": true }
```

Three numbers describe its life:

- **TTL** (`lease_duration`): how long
  it lives from now — 120 seconds here.
- **Renewable**: whether it may ask for
  more time.
- **Explicit max TTL**: the ceiling no
  renewal can cross — 600 seconds, so
  this token can be kept alive in
  120-second steps but is dead for
  certain ten minutes after birth.

`vault token lookup <token>` shows the
clock running: the lab's lookup
reported `ttl: 1m59s`, an
`expire_time` two minutes out, and the
policy list `[default inkwell-reader]`.
A token's holder never has to guess
how much life is left.

## Renewal: asking for more time

```bash
vault token renew -increment=120s -format=json <token>
# { "lease_duration": 120, "renewable": true }
```

Renewal extends the current lease by
the increment, up to the max TTL. It
is how a long-running service holds a
short-lived credential: the token
stays small and revocable, and the
service proves, every couple of
minutes, that it is still itself and
still welcome. A practical note the
lab paid for: put the flags **before**
the token value. Written after it,
`-format=json` was read as a second
argument and the command failed with
"Too many arguments" — the transcript
of the corrected run keeps the lesson
in its heading.

While the token lives, it works:
`vault kv get -field=db_password`
under it returned the orders password.

## Revocation: now, not at expiry

```bash
vault token revoke <token>
# Success! Revoked token (if it existed)
```

Revocation does not wait for the TTL.
The lab used the token one breath
after revoking it, and the answer —
CLI and curl alike — was **403**, with
the error body naming both halves of
the truth: `permission denied` and
**`invalid token`**. A revoked token
is not a token with fewer rights; it
is not a token at all. This is the
incident-response move the whole
design exists for: a leaked token is
killed in one command, and whatever
it could reach stops being reachable
through it, instantly.

## The tree: parents, children, and inherited death

Tokens created by a token are its
children, and the lab's transcript
teaches the tree in two attempts,
because the first one failed
instructively.

**Attempt 1.** A plain `inkwell-reader`
token tried to create a child:

```
Error creating token: ... Code: 403 ... permission denied
```

Creating a token is itself an
operation on a path — `auth/token/create`
— and the reader policy does not grant
it. Least privilege applies to making
tokens exactly as it applies to
reading secrets.

**Attempt 2.** The lab wrote a second,
small policy (`vault-lab/fixtures/token-maker.hcl`)
granting `update` on `auth/token/create`,
and made a parent holding both
policies. That parent created a child
holding only `inkwell-reader` —
children may hold only a **subset** of
the parent's policies; a token cannot
mint a stronger token than itself.
The child read the orders secret
successfully. Then:

```bash
vault token revoke <parent>
# the child now answers 403, "invalid token",
# to both the CLI and the API
```

Revoking a parent revokes the whole
branch. Operationally, this is how you
retire a whole subsystem: revoke the
token at its root and every credential
it ever handed out dies in the same
stroke, without a list of them
anywhere.

## Where leases go from here

Tokens are the leases you can see most
clearly, but the mechanism is general:
anything Vault issues dynamically — a
generated database account is the
canonical case — is born with a lease
ID, a TTL, and a link to the token
that asked for it, and dies by expiry
or revocation the same way. This guide
did not stand up a database to
demonstrate that half, and says so in
`criteria.md`; the token half above is
the same machinery, run for real.

Check: create a 120-second token,
look it up and watch the TTL, renew
it, read a secret with it, revoke it,
and read again — your transcript
should match the lab's shape at every
step, ending in a 403 that says
`invalid token`. Then make a parent
with the `token-maker` policy, a child
under it, revoke the parent, and
confirm the child is dead too.
