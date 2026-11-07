# Real jobs

Outcome: the pieces assembled into
three jobs a small organisation
actually runs — a service that reads
its own secret at startup, a rotation
that does not break the service, and
an incident response in four commands.

Each job names the chapters it is
built from; every step in them was
run in the lab, in the transcripts
those chapters cite.

## Job 1: a service that holds nothing at rest

The Inkwell orders service used to
keep its database password in a config
file on the server. Now it keeps
nothing. At startup it is handed a
token — created under the
`inkwell-reader` policy (chapter 7) —
and its first act is:

```bash
vault kv get -field=db_password secret/inkwell/orders
# inkwell-db-pass-v1
```

or the same read over the API
(chapter 9), which is the form a real
program uses. The password exists in
the service's memory while it runs
and nowhere on its disk. The service's
token is short-lived and renewed
(chapter 8), so the credential a
crashed or copied service leaves
behind is a dead string. What changed,
in total: where the password lives
(one place, chapter 5), who may read
it (one policy, chapter 7), and for
how long a stolen copy works (until
the token's TTL or its revocation,
chapter 8).

## Job 2: rotate the password without downtime

Rotation is the job scattered secrets
make miserable and Vault makes
routine:

1. Change the password at the
   database. (Outside Vault — Vault is
   the messenger here, not the
   database.)
2. Store the new value:
   `vault kv put secret/inkwell/orders
   db_password=<new> api_key=...`
   — version 2 appears; version 1
   remains (chapter 5).
3. Restart or signal the service; it
   reads the latest version and runs
   on the new password.
4. If anything breaks, roll back:
   `vault kv rollback -version=1
   secret/inkwell/orders` (chapter 6),
   fix the database side, and repeat.

The lab executed steps 2–4's Vault
half exactly: two versions written,
version 1 read back by number, and a
rollback that created version 3
carrying version 1's password
(transcripts t02 and t03). The same
shape rotates an API key, a
certificate (chapter 11, with the
bonus that the old certificate simply
expires), or an encryption key
(chapter 10).

## Job 3: a token leaks — the four-command incident

A token appears somewhere it should
not: a log file, a screenshot, a
paste site. With scattered secrets
this is a day of hunting. Here it is:

1. **Revoke it.**
   `vault token revoke <token>` —
   immediate, total (chapter 8).
2. **Read the audit log.** Search for
   the token's HMAC fingerprint
   (chapter 12) and list every path it
   touched and whether it was allowed.
   That list is the blast radius,
   stated by the system itself.
3. **Rotate what it could read.**
   Everything in step 2's list that
   succeeded gets a new version
   (Job 2's shape), because a read
   that succeeded must be assumed
   copied.
4. **Issue a fresh token** under the
   same policy (chapter 7) to the
   legitimate holder, and only to
   them.

What makes this short is not cleverness;
it is that the system's design kept the
three lists an incident needs — what
exists (one store), who could touch
it (policies), who did (audit) — as
by-products of normal use.

## What "real" adds that the lab does not

A production version of these jobs
adds: a durable, backed-up Vault with
TLS (chapter 15's documented-only
territory); an auth method suited to
the caller — cloud or Kubernetes
identity instead of a token handed
over by a person — so Job 1 needs no
human courier; audit forwarded off
the box; and more than one person
holding unseal keys. The jobs do not
change shape. The lab is the jobs,
with the operational armour removed
so the shape is visible.

Check: pick one secret a real service
of yours uses and walk it through
Job 1 on paper — where the token
comes from, which policy, what TTL —
then through Job 3. If any step has
no answer, that gap, named, is your
deployment plan's first item.
