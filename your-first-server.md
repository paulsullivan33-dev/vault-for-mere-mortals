# Your first server

Outcome: a Vault server running on
your own machine, started the way the
lab started it, whose status you can
read in both the CLI and the HTTP API
— plus a real seal and unseal, done by
hand, so the scariest words in Vault
are ones you have already used.

## The development server, and what it switches off

Real Vault servers are started from a
configuration file, against durable
storage, and must be **initialised**
(a one-time ceremony that creates the
unseal keys and the first root token)
and **unsealed** after every restart.
That ceremony matters, and chapter 15
returns to it — but it is a poor first
five minutes. So Vault ships a
**development server** that collapses
all of it into one command:

```bash
vault server -dev -dev-listen-address=127.0.0.1:18081
```

The lab added one flag of its own,
`-dev-root-token-id=lab-root-token`,
which fixes the root token to a known,
obviously-throwaway value so the lab
scripts could be re-run. **Never do
this outside a throwaway lab.** A
guessed root token is total control;
the flag exists for tests, and the
transcripts say so wherever the token
appears.

Dev mode switches off, plainly:

- **Durable storage.** Everything is
  kept in memory (`Storage Type:
  inmem`). Stop the process and every
  secret, policy, and key is gone.
  There is nothing to back up because
  there is nothing that survives.
- **The unseal ceremony.** The server
  starts initialised and unsealed,
  with **one** unseal key and a
  threshold of one (a real setup splits
  the master key into several shares,
  typically five, and requires several,
  typically three).
- **TLS.** The lab server speaks plain
  HTTP on the loopback address only. A
  real server is reached over HTTPS;
  secrets must never cross a network
  unencrypted.
- **High availability.** One process,
  no cluster, no standby.

What dev mode does *not* switch off is
everything this guide teaches: the
engines, the policies, the tokens, the
leases, and the audit log all behave
as they do in production. It is a
flight simulator with a real engine.

## Starting it, and reading its first words

The server prints its own summary as
it starts (full log in transcript
`vault-lab/transcripts/t01b-dev-server-startup-log.txt`):

```
==> Vault server started! Log data will stream in below:
[INFO]  core: vault is unsealed
WARNING! dev mode is enabled! In this mode, Vault runs entirely in-memory
Unseal Key: RWxruvWj4gC6ZcvIcoqgUGZtdrGWw+rwSgyqFF6de1E=
Root Token: lab-root-token
```

Three facts to take from that block.
The warning is Vault being honest
about everything the previous section
said. The **unseal key** is the single
share this dev server needs; the lab
will use it for real later in this
chapter. The **root token** is the
all-powerful setup credential of
chapter 2 — here, a fixed lab
throwaway.

Two environment variables tell the CLI
where to go and who it is:

```bash
export VAULT_ADDR=http://127.0.0.1:18081
export VAULT_TOKEN=lab-root-token
```

## Status, twice

```bash
vault status
```

```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         2.2.1
Storage Type    inmem
HA Enabled      false
```

The same facts live on the API. Two
endpoints matter already:
`/v1/sys/health` answers without any
token (load balancers need it too) and
reports `"sealed": false` and
`"initialized": true`;
`/v1/sys/seal-status` reports the same
in seal vocabulary. Both responses are
in transcript
`vault-lab/transcripts/t01-dev-server-and-status.txt`.
A fresh dev server also mounts a few
engines for you — `vault secrets list`
shows `secret/` (a KV version 2 mount,
the subject of the next two chapters),
`cubbyhole/` (a private store per
token), and the internal `sys/` and
`identity/` mounts.

## Seal and unseal, for real

Sealing is not a metaphor in Vault: a
sealed server discards its keys and
refuses everything. The lab sealed its
running server, with all its data
inside, and brought it back
(transcript
`vault-lab/transcripts/t09-seal-unseal.txt`):

```bash
vault operator seal
# Success! Vault is sealed.

vault status        # Sealed: true, Unseal Progress 0/1
curl http://127.0.0.1:18081/v1/secret/data/inkwell/orders \
  -H "X-Vault-Token: lab-root-token"
# {"errors":["Vault is sealed"]}   HTTP 503

vault operator unseal RWxruvWj4gC6ZcvIcoqgUGZtdrGWw+rwSgyqFF6de1E=
# Sealed: false — and the lab's secrets were still there,
# because in dev mode they never left memory.
```

Read what this proves and what it does
not. It proves the commands work as
described: sealed means locked, the
API answers **503**, health reports
`"sealed": true`, and one key unseals
a dev server because its threshold is
one. It does *not* rehearse the real
ceremony — several key holders, a
durable store, a server that was
initialised by hand. That ceremony is
documented-only in this guide (see
`criteria.md`), and chapter 15 says
why it is a human problem, not a
software one.

Stop the server with Ctrl-C when you
are done. In dev mode, stopping is
also destroying; the next start is a
brand-new, empty Vault.

Check: start the dev server, run
`vault status`, and read `Sealed`,
`Total Shares`, and `Storage Type` out
of the answer. Then seal it, watch the
API answer 503, unseal it, and read a
secret you stored before sealing. All
of that, done by your own hands, is
this chapter.
