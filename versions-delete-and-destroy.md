# Versions, delete, and destroy

Outcome: the full life of a KV secret's
versions — history, metadata, soft
delete, undelete, permanent destroy,
total removal, and rollback — each one
run by the lab on a scratch secret
built for the purpose.

All of this chapter happens on
`secret/inkwell/scratch`, a secret with
one field (`note`) written three times,
so its history is easy to read.
Everything quoted is from transcript
`vault-lab/transcripts/t03-kv-versions-delete-destroy.txt`.

## Reading the history

```bash
vault kv metadata get secret/inkwell/scratch
```

The metadata answer has two halves.
The header names `current_version: 3`,
`created_time`, and `oldest_version`.
Below it, one block per version lists
when it was created and two flags this
chapter is about: `deletion_time` and
`destroyed`. Right now all three
versions read `deletion_time: n/a` and
`destroyed: false`. The metadata path
is also where limits live — a mount
can cap how many versions are kept
(`max_versions`) — though the lab left
those at their defaults.

## Delete is a curtain, not a fire

```bash
vault kv delete secret/inkwell/scratch
# Success! Data deleted (if it existed) at: secret/data/inkwell/scratch
```

A plain delete in KV v2 is a **soft
delete** of the latest version. Read
the secret now and Vault returns the
version's metadata — `version: 3`, with
a `deletion_time` now set — and **no
Data section at all**. The value is out
of view, and the version is marked, but
nothing has been erased. Old versions
are untouched: version 2 still reads
normally.

The curtain lifts as easily:

```bash
vault kv undelete -versions=3 secret/inkwell/scratch
vault kv get secret/inkwell/scratch   # note: third, deletion_time: n/a
```

Soft delete exists for the ordinary
accident — the wrong secret deleted at
the wrong moment — and it behaves like
one expects a recycle bin to behave.
Treat it accordingly: a soft-deleted
secret is *hidden*, not *gone*, and
anyone whose policy allows the
undelete path can bring it back.

## Destroy is the fire

```bash
vault kv destroy -versions=1 secret/inkwell/scratch
# Success! Data written to: secret/destroy/inkwell/scratch
```

**Destroy** removes a version's data
permanently. Read version 1 now and the
answer is metadata only, again with no
Data section — but this time the flag
says `destroyed: true`, and there is no
undelete for it. The metadata block
keeps the scar on purpose: version 1
still appears in the history, marked
destroyed, so the record admits that
something existed and was ended
deliberately.

This is the operation the chapter 1
rule points at. A leaked password
version is not handled by overwriting
it (the old version would still be
readable) or by soft-deleting it (it
can be undeleted). It is handled by
destroying that version, everywhere,
in the one place the secret actually
lives.

## Removing a secret entirely

```bash
vault kv metadata delete secret/inkwell/scratch2
```

Deleting the **metadata** removes the
secret whole: every version and the
history with it. The lab ran it on a
second scratch secret, and the
follow-up `kv metadata get` answered
`No value found`. This is the end of
the road — there is no undelete for a
metadata delete — so it is the rarest
of the three operations in real use.

## Rollback: a new version wearing old clothes

Chapter 5 ended with two versions of
the orders secret. Suppose version 2's
password breaks the service.
**Rollback** copies an old version
into a *new* latest version — it does
not rewind the counter:

```bash
vault kv rollback -version=1 secret/inkwell/orders
vault kv get secret/inkwell/orders
# version: 3, db_password: inkwell-db-pass-v1
```

The history stays honest (version 2
still exists; version 3 records the
retreat), and anything that pinned
version 2 explicitly is unaffected.
Rollback is the versioning system's
real dividend: rotation stops being a
one-way door.

## The four endings, side by side

| Operation | Latest data readable | Old versions | Recoverable |
|---|---|---|---|
| `kv delete` | no (marked deleted) | untouched | yes, `kv undelete` |
| `kv destroy -versions=N` | version N gone for good | only N affected | no |
| `kv metadata delete` | secret and history gone | all gone | no |
| `kv rollback -version=N` | yes — as a new version | untouched | n/a (nothing lost) |

Check: create a three-version scratch
secret, soft-delete the latest and
confirm the read returns metadata with
a `deletion_time` and no data; undelete
it; destroy version 1 and confirm its
metadata says `destroyed: true` while
versions 2 and 3 still read. That
sequence, matching the lab's, is the
whole chapter in your hands.
