# Writing criteria for this guide

Every "for Mere Mortals" guide is written to the same nine-point
standard, so a reader who trusts one can trust the rest. Here it
is, with the verification notes for this particular guide below.

1. **Fix it first.** Reader outcomes lead, not action items: each
   chapter opens by naming the outcome it delivers, shows a check
   the reader can run to confirm they got it, and a reasonable
   reader finishes able to state what was done, what it means,
   and what to try next.
2. **Plain language.** Short sentences, everyday vocabulary,
   technical terms defined on first use. No slang, and no
   idioms that only make sense in one country — the reader may
   be translating as they go.
3. **No dead ends.** A guide never tells the reader to do
   something it cannot show them how to verify. Every claim a
   reader relies on — an install, a command, an output — is
   something this guide demonstrates or clearly labels
   documented-only below.
4. **Live-verified where it matters.** Procedures are run for
   real in the guide's lab wherever the build machine allows it,
   and the transcripts kept in the repository are the evidence.
   What could not be run is listed honestly below, never
   presented as if it had been.
5. **General audiences.** Nothing in this guide — examples,
   fixtures, names, addresses — is modelled on any particular
   reader or author's real life, network, or organisations.
   The lab's traffic is the lab talking to itself.
6. **Standalone.** A reader needs this guide, its lab, and
   nothing else. Where another guide would genuinely help, it
   is pointed to once, by name, and the chapter still completes
   without it.
7. **Honest about limits.** Vault guards access, it does not
   make a careless client careful: a secret fetched correctly
   can still be logged by the client, pasted into a shell
   history, or held forever by a service that never re-fetches,
   and tokens are bearer credentials whose theft policy and TTL
   can only bound, not prevent. The unseal keys are a human
   ceremony problem, not a software one — who holds the shares,
   where they are kept, and how they gather at 3 a.m. is a
   runbook, not a command. Dev mode stores everything in memory,
   speaks plain HTTP, and starts unsealed with a single key; it
   is a classroom, not a deployment. And availability cuts both
   ways: a sealed or down Vault lends nothing, so the store
   everything depends on must itself be kept up.
8. **The one rule is in the text, early.** Chapter 1 and the
   README state the rule plainly — *Vault never hands out
   standing secrets: every access is authenticated, authorised
   by a policy, and recorded, because a secret you cannot
   revoke or rotate is a secret you do not control; Vault lends
   secrets, with leases, lifetimes, and versions, instead of
   giving them away* — before any procedure depends on it, and
   later chapters point back to it where the rule bites: the
   policy that lends one path and refuses the rest, the token
   whose revocation is instant and inherited by its children,
   and the encryption key that is lent as a service and never
   handed over at all.
9. **Builds clean.** The site builds with MkDocs in strict mode
   with no warnings, and a fresh reader following the chapters
   in order reaches the stated outcome of each.

## Verification notes for this guide

The build machine is an Ubuntu 24.04 sandbox. Vault **2.2.1**
was the official release zip
(`vault_2.2.1_linux_amd64.zip` from
`https://releases.hashicorp.com/vault/2.2.1/`); its SHA-256
(`079435de8ff146bdec4cdbe3be71d672ef4e59e4df6af0f2dba672e71be21a68`)
was verified against the release's own `SHA256SUMS` file
before the binary was run. The binary ran from the lab's
scratch folder, not installed system-wide. The server was the
**development server** — `vault server -dev
-dev-listen-address=127.0.0.1:18081` with
`-dev-root-token-id=lab-root-token`, a fixed, lab-only
throwaway root token chosen so the lab is reproducible; the
chapters flag it as never-for-production wherever it appears.
A dev server was the honest lab choice because it exercises
the real engines, policies, tokens, and audit machinery while
being explicit about what it switches off (in-memory storage,
single unseal key, no TLS, no cluster); the guide states
those switches wherever they matter. The lab is in
`vault-lab/`: the driver script `run-lab.sh`, fixtures for a
fictional print shop (`fixtures/`: the two policy files, the
root CA and issued certificates, an audit-log excerpt), and
`transcripts/` holding the captured evidence the chapters
cite. The lab's transient working files were removed after
the run; the transcripts are the record.

Run for real, with transcripts as evidence:

- Version capture (t00): `vault version` reported
  `Vault v2.2.1 (0e7c41b936218bd2401ab0f891c93bec10e2e8e4),
  built 2026-10-22T16:27:49Z`. The lab also ran
  `vault version -format=json`; 2.2.1 printed the same plain
  banner, and chapter 3 says so rather than claiming JSON.
- Dev server start, status, and mounts (t01, t01b): the
  startup log shows the dev-mode warning, `vault is
  unsealed`, one unseal key, and storage type `inmem`;
  `vault status` reported Initialized true, Sealed false,
  Total Shares 1, Threshold 1; `GET /v1/sys/health` and
  `GET /v1/sys/seal-status` returned the same facts as JSON;
  `vault secrets list` showed the pre-mounted `secret/` KV v2
  mount (accessor confirms `map[version:2]`).
- KV v2 (t02): `kv put` created version 1 of
  `secret/inkwell/orders` (two fields), a second `put`
  created version 2, `-version=1` read back the original
  password, and the HTTP API read returned the same data
  with `data.metadata.version` 1 then 2.
- Versions, delete vs destroy (t03): a three-version
  scratch secret's `kv metadata get` listed all versions;
  `kv delete` soft-deleted v3 (read returned metadata with
  `deletion_time` set and no data); `kv undelete
  -versions=3` restored it (`note: third`); `kv destroy
  -versions=1` marked v1 `destroyed: true` with no data on
  read, while v2/v3 stayed readable; `kv metadata delete`
  removed a second scratch secret entirely (`No value
  found` on follow-up); `kv rollback -version=1` on the
  orders secret created version 3 carrying version 1's
  password.
- Policy and denial (t04, t04b): the HCL policy
  `inkwell-reader` grants `read` on exactly
  `secret/data/inkwell/orders`. A token created under it
  read that path via CLI and via curl (identical data);
  the same token was refused **403 permission denied** for
  `secret/inkwell/billing` by CLI and by curl
  (`HTTP_STATUS=403`), refused 403 writing to its own
  allowed path, and refused 403 listing `sys/mounts`. The
  root token read billing normally, proving the denials
  were the policy.
- Transit (t05): the engine was enabled, key
  `inkwell-orders` created (`aes256-gcm96`,
  `exportable: false`, `deletion_allowed: false`).
  Encrypting base64 `inkwell-db-pass-v2` returned
  ciphertext `vault:v1:DAStIcGHpvIfDK4/...` and decrypting
  returned the original base64, decoding to the original
  password. A second encryption over curl returned a
  *different* ciphertext for the same plaintext (fresh
  nonce), as chapter 10 describes.
- PKI (t06): the engine was enabled and tuned to
  `max-lease-ttl=87600h`; a root CA
  (`Inkwell Print Co. Internal CA`, TTL 87600h) was
  generated; a role allowed `example.test` subdomains with
  `max_ttl` 720h; a certificate for
  `orders.inkwell.example.test` was issued (serial
  `55:ce:65:fb:...:06:f1`, 30-day validity **Nov 7 2026 →
  Dec 7 2026** per openssl). `openssl verify -CAfile
  root-ca.pem issued-cert.pem` answered **OK**, and also
  OK against the `issuing_ca` returned with the
  certificate. Both PEM files are kept in
  `vault-lab/fixtures/` for re-verification.
- Audit (t07): a file audit device was enabled mid-run;
  the log's JSON lines recorded an allowed billing read
  and a **denied** billing read, the denied request and
  response lines both carrying the `permission denied`
  error; tokens and values in the log appear only as
  `hmac-sha256:` fingerprints; the log held 10 lines
  (five request/response pairs) at capture time.
- Token leases (t08): a token created with `-ttl=120s
  -explicit-max-ttl=600s` reported `lease_duration: 120,
  renewable: true`; lookup showed `ttl: 1m59s`;
  `vault token renew -increment=120s` renewed it; it read
  the orders secret; after `vault token revoke` the same
  read failed **403** with `invalid token` via CLI and
  curl. Token trees: a plain `inkwell-reader` token was
  denied 403 creating a child (no `auth/token/create`
  grant); a parent holding the additional `token-maker`
  policy created a child that read the secret, and
  revoking the parent made the child's next read fail 403
  `invalid token`. An early run of this transcript had two
  faults — flags placed after the token argument
  (`Too many arguments`) and a child-creation attempt that
  could never have succeeded under the reader policy; the
  transcript was re-run corrected, and both lessons are
  kept in chapters 8 and 16.
- Seal and unseal (t09): `vault operator seal` sealed the
  running server; status reported `Sealed: true`; the API
  answered **503** `{"errors":["Vault is sealed"]}` and
  health reported `"sealed": true`; `vault operator
  unseal` with the dev server's single key unsealed it,
  and the lab's secrets were still readable (dev storage
  is memory, so nothing had moved).
- CLI and HTTP API parity was exercised throughout: reads
  (t02, t04b), health and seal-status (t01), denial status
  codes (t04b, t08), transit encrypt (t05), and the sealed
  response (t09) were each done with `curl` as well as, or
  instead of, the CLI.

Documented only — described from HashiCorp's documentation
and the binaries' own records, not run, and the text does
not claim otherwise:

- Production deployment in full: configuration-file
  servers, durable storage backends (including integrated
  storage/Raft), TLS listeners, backup and restore.
- Initialisation of a real server, the multi-share unseal
  ceremony (Shamir shares above 1-of-1), rekeying, and
  cloud KMS / HSM auto-unseal.
- High availability: clusters, standbys, and failover.
- Dynamic secrets in full — the database engine generating
  and revoking live database accounts. Leases are
  demonstrated live on tokens, which use the same
  machinery; no database server was stood up.
- Auth methods other than tokens (cloud IAM, Kubernetes,
  userpass, AppRole, TLS certificates).
- Transit key rotation and rewrap (chapter 10 describes
  them from the key record's fields), PKI intermediate
  CAs, certificate revocation lists, and automated
  certificate renewal.
- Installation routes other than the official release zip
  (distribution packages, Homebrew, container images), and
  everything Windows- or macOS-specific.
- The neighbouring tools in chapter 14 are characterised,
  not benchmarked.

Fixtures are this guide's own and deliberately generic: a
fictional print shop, its orders service, and invented
secrets, domains (`example.test`), and values. No example
is modelled on any real person, network, service, or
organisation. Every token shown in the transcripts is a
throwaway from a dev server that no longer exists; the
root token was the fixed lab value `lab-root-token`, and
the one unseal key printed in transcript t09 belongs to
that same discarded in-memory server.

## Publication note

One value in transcript t04 — a client token issued by the lab's
own throwaway dev server — was redacted before publication
(`hvs.REDACTED`). The dev server was in-memory and no longer
exists, so the token authorizes nothing; it is redacted anyway,
because a token value does not belong in a public repository.
Everything else in the transcripts is exactly as captured,
including the audit log excerpts, where Vault itself stores only
HMAC fingerprints of sensitive values.
