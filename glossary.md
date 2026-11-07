# Glossary

Outcome: every term the guide uses,
in one place, in the guide's own
words.

**Audit device** — a destination
(file, socket, system log) to which
Vault writes a structured record of
every request and response. Secret
values inside the records are
HMAC-hashed, never stored in clear.

**Auth method** — a way for a caller
to prove its identity to Vault:
tokens, usernames and passwords,
cloud identities, Kubernetes service
accounts, and others. Every method,
on success, issues a token.

**Barrier** — the boundary inside
Vault across which stored data is
always encrypted. Nothing is written
outside the barrier in clear text.

**Capability** — one permission named
in a policy rule: `create`, `read`,
`update`, `delete`, `list`, `deny`,
`sudo`. A request needs the
capability that matches its operation
and path.

**Ciphertext** — data after
encryption: safe to store anywhere,
meaningless without decryption. In
the transit engine it carries a
`vault:vN:` prefix naming the key
version that made it.

**Cubbyhole** — a built-in engine
giving each token a small private
store that no other token can read.

**Destroy** — in KV v2, the permanent
removal of one version's data. The
metadata remains, marked destroyed.
There is no undelete for a destroy.

**Dev server** — `vault server -dev`:
an in-memory, single-key, plain-HTTP
Vault for learning and testing.
Everything in it is lost when it
stops.

**Dynamic secret** — a credential
Vault creates on demand in another
system (for example, a database
account) and deletes when its lease
ends.

**HCL** — HashiCorp Configuration
Language, the syntax Vault policies
are written in.

**HMAC** — a keyed fingerprint of a
value. Audit logs store HMACs of
secrets and tokens so equal values
can be recognised without being
revealed.

**Initialise** — the one-time setup
of a real Vault server, which creates
the unseal keys and the first root
token.

**KV engine** — the key-value secrets
engine. Version 2 keeps a versioned
history and metadata per secret, at
`data/` and `metadata/` paths under
its mount.

**Lease** — the record tying
something Vault issued (a token, a
dynamic credential) to a lifetime and
to the token that requested it.
Expiry or revocation undoes the
issued thing.

**Mount** — an engine enabled at a
path, or that path itself. `secret/`,
`transit/`, and `pki/` are the mounts
this guide enables.

**PKI engine** — the engine that runs
a certificate authority: a root (or
intermediate) certificate held in
Vault, and certificates issued under
roles.

**Policy** — a named HCL document of
path rules stating what a token may
do. Anything unmentioned is denied.

**Rekey** — replacing the unseal key
shares with a fresh set, without
changing the master key they protect.

**Renew** — extending a lease (for
example, a token's TTL) before it
expires, up to its maximum.

**Revoke** — ending a lease at once.
A revoked token stops working
immediately; revoking a parent token
revokes its children.

**Role** — in the PKI engine, the
written constraint on what
certificates may be issued: allowed
domains, maximum lifetime, key type.

**Rollback** — in KV v2, copying an
old version's data into a new latest
version.

**Root token** — a token carrying the
built-in `root` policy, able to do
everything. Created at initialisation
for setup, and meant to be revoked
afterwards.

**Seal / unseal** — the lock on
Vault's store. A sealed server holds
only encrypted data and refuses all
requests. Unsealing presents enough
key shares to rebuild the master key.

**Secrets engine** — a component that
handles one kind of secret work: KV
(storage), transit (encryption),
PKI (certificates), database
credential generation, and others.

**Soft delete** — in KV v2, marking a
version deleted (with a
`deletion_time`) while keeping it
recoverable by `kv undelete`.

**Token** — the credential a caller
presents with each request. It
carries policies and a TTL, can be
renewed and revoked, and may have
child tokens.

**Transit engine** — the engine that
encrypts and decrypts data sent to
it, keeping its keys inside Vault and
never releasing them.

**TTL (time to live)** — how long a
token, lease, or certificate lasts
before it expires.

**Unseal key** — one share of the
master key, presented at unseal time.
The lab's dev server used one share
with a threshold of one; production
servers use several of each.

Check: pick three terms you met in a
chapter and explain each to an
imaginary colleague without looking —
then check yourself here. The
vocabulary *is* the map of the tool.
