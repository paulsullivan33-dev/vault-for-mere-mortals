# Audit logging

Outcome: an audit device switched on,
requests appearing in its log as
structured lines — including a denied
request, recorded with its refusal —
and a clear view of what the log
deliberately never contains.

All evidence is transcript
`vault-lab/transcripts/t07-audit.txt`.

## Why the log is half the product

Chapter 1 promised that every access
is *recorded*. This chapter keeps the
promise visibly. Without an audit log,
Vault's other guarantees are claims:
with one, "who read the billing
secret, and when, and were they
allowed?" is a question with an
answer you can grep. In a real
deployment the audit log is often the
reason Vault was adopted at all.

Know this before you switch one on:
**Vault will not run blind.** If every
enabled audit device fails to write
(a full disk, a dead socket), Vault
stops answering requests rather than
answer them unrecorded. The log is not
an accessory bolted to the side of the
system; it is in the request path,
chapter 2's step 6, by design.

## Switching one on

An **audit device** is a destination:
a file, a socket, or the system log.
The lab used a file inside the lab
folder:

```bash
vault audit enable file file_path=<lab>/work/audit.log
# Success! Enabled the file audit device at: file/

vault audit list
# Path   Type   Description
# file/  file   n/a
```

From that moment, every request and
its response are appended to the file
as **one JSON object per line**. An
excerpt of real lines is kept at
`vault-lab/fixtures/audit-log-excerpt.jsonl`.

## Reading the log

The lab made two distinctive requests
after enabling the device — a root
read of `secret/inkwell/billing`, and
the same read attempted with the
limited `inkwell-reader` token — then
searched the log for that path. The
last two matching lines are the denied
request and its response:

```json
{"type":"request",  "time":"2026-11-07T21:49:31.463360039Z",
 "path":"secret/data/inkwell/billing", "operation":"read",
 "error":"1 error occurred:\n\t* permission denied\n\n"}
{"type":"response", "time":"2026-11-07T21:49:31.463641511Z",
 "path":"secret/data/inkwell/billing", "operation":"read",
 "error":"1 error occurred:\n\t* permission denied\n\n"}
```

Four facts to take from two lines:

1. **Denials are logged, with the
   reason.** A refused request is
   exactly the event an audit exists
   to catch; the `error` field carries
   the refusal.
2. **Requests and responses are
   separate lines**, sharing a request
   ID, so a slow or failed operation
   can be followed as a pair.
3. **Ten lines existed** in the lab's
   log at that point — five requests,
   each leaving its pair.
4. **Timestamps are precise** (UTC,
   nanosecond field) and the clock is
   the server's; chapter 15's advice
   about keeping server time honest
   starts here.

## What the log refuses to contain

Look for a secret value, or a usable
token, in the audit log and you will
not find one. Values are replaced by
**HMAC hashes** — keyed fingerprints
in the form `hmac-sha256:<hex>` — as
the transcript's own excerpt shows
for the caller's token
(`auth_token_hmac`). An HMAC proves
that two lines concern the *same*
value (the fingerprints match) without
revealing the value, and the key that
makes the fingerprints lives in Vault,
so a stolen log cannot be
dictionary-attacked the way plain
hashes of weak passwords can. The log
can therefore be shipped to a logging
system and read by people who are not
trusted with the secrets themselves —
while still answering "was it the same
token both times?"

## Operating habits worth forming

- Enable audit **before** anything
  else in a real setup, so the first
  real secret's first read is already
  on record. (The lab enabled it
  mid-run, which is why its log holds
  only the tail of the story — fine for
  a lesson, wrong for a deployment.)
- Send the file somewhere else.
  A log that lives only on the Vault
  server is evidence kept by the
  suspect; real setups forward it.
- Watch its health. Given Vault's
  refuse-to-run-blind rule, a filling
  disk is an outage announcement, not
  a logging detail.

Check: enable a file audit device,
make one allowed read and one denied
read, and find both in the log with
their outcomes. Then search the whole
log for a secret value you know was
read, and confirm it is absent while
its HMAC fingerprints are present.
Both searches are this chapter.
