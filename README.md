# Vault for Mere Mortals

Every system you run is held together
by small secrets: a database password
here, an API key there, a certificate
key somewhere else. Ask where they all
live and the honest answer is a
scatter — config files, environment
variables, a shared note, a shell
history — and a scatter has three
costs. Nobody can list every copy.
Nobody can take one back everywhere
at once. And nobody can say who used
one. **HashiCorp Vault** takes the
scatter over: one guarded server
holds the secrets, checks **who is
asking** and **what a written policy
allows**, and hands out secrets as
**loans** — timed, recorded, and
recallable.

One rule governs everything it does,
and this guide states it in chapter 1
and keeps pointing back to it:
**Vault never hands out standing
secrets — every access is
authenticated, authorised by a
policy, and recorded, because a
secret you cannot revoke or rotate is
a secret you do not control. Vault
lends secrets, with leases, lifetimes,
and versions, instead of giving them
away.** Watch it work everywhere: a
token expires unless renewed and dies
the instant it is revoked — children
and all; a stored secret keeps every
version, so a rotation can be rolled
back and a leaked version destroyed;
a policy lends one caller exactly one
path, and the lab watches Vault answer
**403** when that caller reaches for
the neighbouring secret; even
encryption is a loan of a service,
never of the key.

The lab behind this guide ran the real
thing: **Vault 2.2.1**, the official
release zip from HashiCorp's release
server, its SHA-256 checked against
the publisher's sums, as a
**development server** — in-memory,
single-key, loopback-only on
127.0.0.1 port 18081 — against a
fictional business, the Inkwell Print
Co., and its orders service. Against
that server the lab wrote and read
KV secrets and walked their versions
through soft delete, undelete,
destroy, and rollback; wrote a
one-path policy, minted a token under
it, and recorded the denial when the
token reached outside it, by CLI and
by HTTP API alike; encrypted and
decrypted a password with the transit
engine, the key never leaving Vault;
stood up the PKI engine as a private
certificate authority and had
**openssl** — a tool that owes Vault
nothing — verify the certificate it
issued; enabled a file audit device
and read a denied request back out of
the log, HMACs and all; and lived a
token's whole life: TTL, lookup,
renewal, instant revocation, and a
child token dying with its revoked
parent. Finally it sealed the running
server, watched the API answer 503,
and unsealed it with the dev server's
single key.

What the lab could not do, it did not
fake. A production deployment —
durable storage, TLS, the multi-share
unseal ceremony, high availability,
cloud auto-unseal — and the dynamic
database credentials engine are
described and labelled documented-only;
`criteria.md` keeps the full ledger.
Dev mode is a classroom, not a
deployment, and the guide says so
wherever the difference matters.

## What this guide covers

- [**What Vault is**](what-vault-is.md) —
  the scatter of secrets, its three
  costs, and the one rule
- [**The moving parts**](the-moving-parts.md) —
  the barrier, the seal, engines, auth,
  policies, tokens, leases, and the
  audit log, and one request end to end
- [**Installing Vault**](installing-vault.md) —
  the official release zip, the
  checksum habit, and the version check
- [**Your first server**](your-first-server.md) —
  the dev server, what it switches off,
  status by CLI and API, and a real
  seal and unseal
- [**Secrets and the KV engine**](secrets-and-the-kv-engine.md) —
  writing and reading versioned
  secrets, and the `data/` path inside
  the path
- [**Versions, delete, and destroy**](versions-delete-and-destroy.md) —
  soft delete, undelete, destroy,
  metadata delete, and rollback
- [**Policies**](policies.md) — one
  path, read only, a token under it,
  and the recorded 403 denials
- [**Tokens and leases**](tokens-and-leases.md) —
  TTL, lookup, renewal, revocation,
  and the token tree
- [**The HTTP API**](the-http-api.md) —
  the same Vault through `curl` alone:
  reads, errors, and the token header
- [**Encryption as a service**](encryption-as-a-service.md) —
  the transit engine: ciphertext your
  application may store, keys it never
  sees
- [**Certificates from Vault**](certificates-from-vault.md) —
  the PKI engine as a private CA, a
  role, an issued certificate, and
  openssl saying OK
- [**Audit logging**](audit-logging.md) —
  the file audit device, denied
  requests on record, and HMACs in
  place of secrets
- [**Real jobs**](real-jobs.md) — a
  service that holds nothing at rest,
  a rotation without downtime, and a
  four-command incident response
- [**The neighbours**](the-neighbours.md) —
  config files and environment
  variables, cloud secret managers,
  SOPS, password managers, and
  platform secrets
- [**Limits**](limits.md) — careless
  clients, bearer tokens, the human
  unseal ceremony, and why dev mode
  is not a deployment
- [**Troubleshooting**](troubleshooting.md) —
  sealed servers, the three causes of
  a 403, empty reads, and early token
  deaths
- [**Glossary**](glossary.md) — the
  terms, collected in one place

## What it doesn't cover

Running Vault in production: cluster
setup, storage backends, TLS
termination, backup and restore, and
the unseal ceremony are operational
topics this guide describes honestly
but does not rehearse. The database
engine's dynamic credentials, the
cloud and Kubernetes auth methods,
and the enterprise edition's features
are likewise named where they belong
and left documented-only. Nothing
here stores a real secret: every
example belongs to a fictional print
shop, and every token in the
transcripts is a throwaway from a
server that no longer exists.

## How to use this guide

Read chapter 1 for the rule and
chapter 2 for the map of parts;
chapter 4 gets a real server running,
and chapters 5 to 8 are the core
craft — store, constrain, lend,
revoke. Chapter 7's denial transcript
is the guide's centre of evidence:
read it before you trust any policy
you write, including the guide's.
The lab lives in `vault-lab/`: its
driver is `vault-lab/run-lab.sh`, its
fixtures (the policies, the root and
issued certificates, an audit
excerpt) in `vault-lab/fixtures/`,
and every claim's evidence in
`vault-lab/transcripts/`; its
distilled commands are
`examples/commands.txt` and its notes
`examples/lab-notes.txt`.

---

## Part of the series

This guide is one of the [For Mere Mortals](https://paulsullivan33-dev.github.io/mere-mortals/) guides: plain-language guides to the tools programmers and makers use.

Related guides:

- [Text Processing for Mere Mortals](https://paulsullivan33-dev.github.io/text-processing-for-mere-mortals/)
- [Vim for Mere Mortals](https://paulsullivan33-dev.github.io/vim-for-mere-mortals/)
- [Markdown for Mere Mortals](https://paulsullivan33-dev.github.io/markdown-for-mere-mortals/)

## License

The writing in this guide is licensed under [CC BY 4.0](https://github.com/paulsullivan33-dev/vault-for-mere-mortals/blob/main/LICENSE). Code examples and lab scripts are licensed under the [MIT License](https://github.com/paulsullivan33-dev/vault-for-mere-mortals/blob/main/LICENSE-CODE).
