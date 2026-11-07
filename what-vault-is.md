# What Vault is

By the end of this chapter you can say,
in one sentence, what problem Vault
takes off your hands — and state the
one rule that explains everything it
does with a secret.

## The secrets you already have, scattered

Every working system runs on small
pieces of private information:
**secrets**. A database password. An
API key for a payment provider. The
private key of a TLS certificate. A
token that lets one service call
another.

Ask a small team where those secrets
live and the honest answer is usually
a list: a line in a config file on the
server, an environment variable set by
hand, a note in a shared document, a
line in someone's shell history, a copy
in the deployment script, another copy
in the backup of the deployment script.
Nobody decided this. It grew.

That scatter has three costs, and they
are the whole reason this tool exists:

1. **Nobody can list them.** If you
   cannot say where every copy of a
   password lives, you cannot answer the
   simplest question in an incident:
   *what do we need to change?*
2. **Nobody can take one back.** A
   password pasted into five places
   stays valid in all five until someone
   hunts down every copy. Leaving staff,
   a leaked laptop, a committed config
   file — each one needs a revocation
   that scattered secrets cannot give
   you.
3. **Nobody can say who used one.**
   A shared password leaves no trail.
   After something goes wrong there is
   nothing to read.

**HashiCorp Vault** is a server that
holds secrets in one guarded place and
hands them out only on its own terms.
Programs and people **authenticate**
(prove who they are), Vault checks a
**policy** (a written list of what that
caller may touch), and only then does
it release a secret — while writing the
whole exchange to an **audit log**. The
secret itself never stops belonging to
Vault: it comes with a lifetime, it can
be **revoked** (made invalid at once),
and it can be **rotated** (replaced
with a new value) without hunting
through config files.

## The rule: Vault lends secrets, it does not give them away

Everything in this guide follows from
one idea, stated here and in the
README, before any procedure depends
on it:

> **Vault never hands out standing
> secrets. Every access is
> authenticated, authorised by a
> policy, and recorded — because a
> secret you cannot revoke or rotate
> is a secret you do not control.
> Vault lends secrets, with leases,
> lifetimes, and versions, instead of
> giving them away.**

Watch how often the later chapters are
just this rule, applied. A **token**
( chapter 8) is a loan with an expiry
time printed on it: it can be renewed
while it is welcome and revoked the
moment it is not, and revoking a parent
token revokes everything it lent on.
A stored secret in the KV engine
(chapters 5 and 6) keeps every
**version**, so a bad change can be
rolled back and a leaked version can be
**destroyed** — not merely deleted, but
made unrecoverable on purpose. A
**policy** (chapter 7) lends exactly
one path to one caller and nothing
else; this guide's lab gives a service
a token that can read one secret, then
watches Vault refuse it — HTTP 403 —
when it reaches for the neighbouring
secret. Even encryption (chapter 10)
is a loan of a *service*, not of a key:
your program sends Vault plaintext and
gets ciphertext back, and the key
itself never leaves the building.

The rule also names Vault's price, and
the guide will not hide it. A lender
has to be open for business: if Vault
is down or **sealed** (locked, chapter
4), nobody's loan is approved, so the
tool that guards everything becomes a
thing everything depends on. Chapter
15 is honest about what that costs.

## Where it comes from

Vault is made by HashiCorp. The open
source edition is free, written in Go,
and runs as a single binary on Linux,
macOS, and Windows; a paid enterprise
edition adds features this guide does
not need. This guide's lab ran **Vault
2.2.1**, the official release taken
straight from HashiCorp's release
server, checksummed against the
published sums (transcript
`vault-lab/transcripts/t00-version.txt`).
Everything the lab did, it did against
a **development server** — a
single-command, in-memory Vault meant
for learning — on the loopback address
of one machine. Chapter 4 says plainly
what that mode switches off, and
chapter 15 repeats it: dev mode is a
classroom, not a deployment.

Check: name the three costs of
scattered secrets, then say the rule
out loud once — *Vault lends secrets;
it does not give them away* — and name
one thing a loan has that a gift does
not (an expiry, a recall, or a record).
If you can do both, you have this
chapter.
