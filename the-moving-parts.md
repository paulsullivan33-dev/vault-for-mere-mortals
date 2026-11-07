# The moving parts

Outcome: a map of the pieces every
later chapter uses — the server, the
barrier, the seal, the engines, the
auth methods, the policies, the
tokens, and the audit log — and how a
single request travels through all of
them.

## One server, one guarded core

Vault is one server process. Inside it
sits an encrypted store: every secret,
policy, and key Vault holds is
encrypted before it is written
anywhere, with an **encryption key**
that itself never rests in plain form.
The boundary between the encrypted
store and the rest of the program is
called the **barrier**. Nothing crosses
it in clear text except through a
request Vault has decided to allow.

Whether the barrier is open at all is
the **seal**. A sealed Vault holds its
store locked: it can say that it is
sealed, and nothing else. **Unsealing**
means presenting the **unseal keys** —
shares of a master key, made when the
server was first **initialised** — until
enough shares have arrived to rebuild
it. Production setups ask several
people to each hold one share, so no
single person can open the vault alone.
The lab's development server simplifies
this to one key and starts unsealed;
chapter 4 shows the real seal and
unseal commands working against it
(transcript
`vault-lab/transcripts/t09-seal-unseal.txt`),
and chapter 15 explains what dev mode
leaves out.

Where the encrypted store physically
lives is the **storage backend**.
Production servers use a durable
backend — HashiCorp's own integrated
storage (Raft) is the usual choice.
The dev server keeps everything in
memory, which is why closing it
forgets it completely.

## Secrets engines: one mount per job

A **secrets engine** is a component
that knows how to handle one kind of
secret work. Each engine is **mounted**
at a **path**, and every request to
that path belongs to that engine:

- The **KV engine** (key-value) stores
  secrets you invent — passwords, API
  keys — and versions them. Mounted for
  you at `secret/` on a dev server
  (chapters 5 and 6).
- The **transit engine** encrypts and
  decrypts data you send it, without
  storing the data and without ever
  releasing its keys (chapter 10).
- The **PKI engine** runs a certificate
  authority: it holds a root certificate
  and issues short-lived certificates
  to callers a role allows (chapter 11).
- Further engines generate credentials
  on demand — database accounts are the
  famous case. This guide covers those
  as documented-only (see
  `criteria.md`); it runs the three
  above for real.

Engines can be mounted more than once,
at different paths, with separate data:
two teams can each have a KV mount and
never see each other's paths.

## Auth methods and tokens

A caller proves its identity through an
**auth method** — a token handed out by
an operator, a cloud identity, a
Kubernetes service account, a username
and password, and others. A successful
login of any kind produces the same
thing: a **token**.

A token is Vault's unit of trust, and
it is a loan in the chapter 1 sense:

- It carries the **policies** its
  holder is allowed by.
- It has a **time to live** (TTL). It
  expires unless **renewed**, and it can
  be **revoked** at any moment.
- Tokens form a tree. A token created
  by another token is its **child**, and
  revoking a parent revokes the whole
  branch below it — the lab demonstrates
  exactly that in chapter 8 (transcript
  `vault-lab/transcripts/t08-token-leases.txt`).

The **root token** is the exception
that proves the rule: a token with the
built-in `root` policy, allowed to do
everything, created at initialisation.
It exists to set the system up, and
careful operators revoke it when setup
is done and generate a fresh one only
when needed. The lab uses a fixed,
obviously-named root token —
`lab-root-token` — because the dev
server is thrown away at the end of
every run. That is a lab convenience,
never a pattern for real use, and the
chapters say so wherever it appears.

## Policies: the written permission slip

A **policy** is a small document,
written in **HCL** (HashiCorp
Configuration Language), that lists
paths and the **capabilities** allowed
on each: `create`, `read`, `update`,
`delete`, `list`, and a few more.
Anything a policy does not mention is
denied. Chapter 7 writes a policy with
exactly one rule — read
`secret/data/inkwell/orders`, nothing
else — and the lab's denial transcript
(`vault-lab/transcripts/t04b-policy-denial.txt`)
is the evidence that "nothing else" is
enforced, not decorative.

## Leases: everything lent has a string attached

Dynamic secrets and tokens are issued
with a **lease**: a record that ties
the thing issued to a lifetime and to
the token that asked for it. When a
lease expires or is revoked, Vault
undoes the thing — the token stops
working, the generated database account
is dropped. Chapter 8 works this
machinery by hand on tokens, where
every step is visible: create with a
TTL, look up, renew, revoke, and watch
the revoked token fail.

## The audit log: the memory of the building

An **audit device** records requests
and responses as structured log lines —
who asked, for what path, when, and
whether it was allowed. Secret values
and tokens inside those lines are
replaced by **HMAC** hashes (keyed
fingerprints): the log proves a value
was the same value across two lines
without ever containing the value.
Chapter 12 turns one on and reads a
denied request back out of it
(transcript
`vault-lab/transcripts/t07-audit.txt`).

## A request, end to end

1. A program sends a request —
   `GET /v1/secret/data/inkwell/orders` —
   with its token in a header. The
   **HTTP API** is the whole surface;
   the `vault` command-line tool is a
   client of it (chapter 9).
2. Vault checks the seal. Sealed means
   the answer is *no* before anything
   else is read.
3. The token is looked up: is it alive,
   unexpired, unrevoked?
4. The token's policies are checked
   against the path and operation.
5. The secrets engine at that path does
   the work — reads a version, encrypts
   a value, issues a certificate.
6. The audit device writes the line.
7. The answer travels back, with any
   lease information attached.

Every chapter that follows is one of
these steps, opened up.

Check: sketch the seven steps from
memory and point at the step where a
policy is enforced and the step where
the record is written. If you can place
both, the map is yours.
