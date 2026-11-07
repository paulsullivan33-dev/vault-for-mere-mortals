# Limits

Outcome: the honest boundary of the
tool, in one place — what Vault
cannot do for a careless client, what
dev mode is not, and which parts of
a real deployment this guide
describes but did not run.

## Vault guards access; it does not make a careless client careful

Vault decides who may fetch a secret.
The moment a program fetches one,
Vault's control ends and the
program's habits begin. A database
password read correctly under policy
can still be:

- written into the program's own log,
- pasted into a shell command, where
  it lands in **shell history** and
  the process list,
- committed to a repository by a
  script that dumps its environment,
- held in memory forever by a service
  that fetched once at startup and so
  never notices a revocation or a
  rotation.

None of those is a Vault failure, and
Vault cannot prevent any of them.
Short TTLs and renewal narrow the
window — a service that re-fetches
notices rotations and loses access
when revoked — but the last metre of
secret handling belongs to the client.
Design clients as if the secret were
borrowed money: hold it briefly, in
memory, and never write it down.

## Tokens are bearer secrets

Whoever presents a token **is** the
token's holder, as far as Vault can
tell. A token in a shell history file,
a CI log, or a screenshot is a working
credential for anyone who finds it,
for the rest of its TTL. This is why
the guide keeps repeating the lab's
own warning: the fixed root token
`lab-root-token` exists only because
the lab server is thrown away, and a
real root token is generated for a
purpose and revoked when the purpose
ends. Policy limits what a stolen
token can do; TTL limits for how
long; neither makes theft harmless.

## The unseal keys are a human ceremony problem, not a software one

Vault's cryptography is the easy
half. The hard half is that a real
server's unseal keys are held by
people: who they are, where their
shares are written down, how they
are gathered at 3 a.m. when the
server restarts, what happens when
one holder leaves, and how the shares
are re-made (**rekeying**) without
ever assembling them casually. No
chapter of commands solves any of
that; it is runbooks, envelopes,
safes, and rehearsals. Cloud KMS
**auto-unseal** moves the problem —
the master key is unwrapped by a
cloud key service, so uptime no
longer waits on people, and trust
moves to that cloud account instead.
This guide did not run auto-unseal,
a multi-share ceremony, or rekeying;
they are documented-only here (see
`criteria.md`), and the dev server's
one printed key is not a rehearsal
for any of them.

## Dev mode is not a deployment

Chapter 4 listed what dev mode
switches off; the limit belongs here
too, in one sentence: the lab's
server kept everything in memory,
spoke plain HTTP, started unsealed
with one key, and forgot everything
when stopped — **nothing about it
survives contact with a real
network**, and a real deployment
needs durable storage, TLS,
initialisation, a seal strategy, and
backups of both the stored data and
the means to unseal it. Losing a
production Vault's storage *and* its
unseal keys is losing every secret it
holds, permanently, by design. The
barrier does not have a back door,
including for you.

## Availability is now your problem in a new place

Before Vault, a service needed its
own disk to start. After Vault, it
needs Vault: an unavailable or sealed
Vault means no fetches, no renewals,
and eventually a fleet of expired
tokens. High availability (a cluster,
standbys, durable replicated storage)
is the standard answer and is
documented-only in this guide. The
trade is usually worth it — one
system to make highly available
instead of secrets copied to every
machine "for resilience" — but it is
a trade, entered knowingly.

## Scope limits, plainly

- **Vault is not a general database.**
  KV stores secrets — small, precious
  values — not application data, not
  large payloads, not high-rate
  lookups.
- **Rotation still needs the other
  end.** Vault can store a new
  password version instantly; making
  the database accept it, and the
  service pick it up, is your
  choreography (chapter 13, Job 2).
  Engines that generate credentials
  dynamically close more of that gap
  for the systems they support.
- **The audit log records; it does
  not watch.** Alerts on suspicious
  patterns are a log system on top of
  chapter 12's lines, not a Vault
  feature.
- **Dynamic database secrets,
  cloud auth methods, HA, and the
  enterprise features** (namespaces,
  replication at scale, HSM seals) are
  outside what the lab ran; the
  criteria's documented-only list is
  the full ledger.

Check: name the limit in this chapter
that most changes how you would run
one of your own services, and the
client habit or runbook item that
answers it. If the unseal-ceremony
limit is your answer, you have
understood Vault's centre of gravity:
the software is strong, and the
ceremony is yours.
