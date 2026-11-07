# Certificates from Vault

Outcome: a working certificate
authority inside Vault — a root
certificate, a role that constrains
what may be issued, and a certificate
for the Inkwell orders service that
**openssl** itself verifies against
that root.

All evidence is transcript
`vault-lab/transcripts/t06-pki.txt`;
the root and issued certificates are
kept in `vault-lab/fixtures/` so you
can re-run the verification yourself.

## Why a private CA, and why in Vault

Internal services need TLS
certificates too, and public
certificate authorities will not issue
for names like
`orders.inkwell.example.test`, which
exist only inside your own network.
So organisations run a **private
certificate authority (CA)** — and
then face chapter 1's problem at its
sharpest: a CA's private key is the
secret from which all trust in the
building flows, and it must be usable
every day without ever being copied
anywhere.

The **PKI engine** is Vault acting as
that CA. The root key lives behind the
barrier. Callers ask for certificates;
Vault signs them; the key never
leaves. Certificates are also loans:
each is issued with a lifetime, under
a policy, and recorded — and a
certificate's short lifetime does the
work that revocation lists struggle
to do, because a certificate that
expires in 30 days needs no recall
for most of its misuse window.

## Mount, tune, and grow a root

```bash
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
```

The tune matters: a mount's maximum
lease caps everything issued under it,
and the default (30 days) is far too
small for a root that should live for
years. The lab raised the ceiling to
87600 hours — ten years — then
generated the root:

```bash
vault write -field=certificate pki/root/generate/internal \
  common_name="Inkwell Print Co. Internal CA" ttl=87600h
```

The answer is a PEM certificate
beginning `-----BEGIN CERTIFICATE-----`
(the transcript keeps its head; the
full certificate is
`vault-lab/fixtures/root-ca.pem`).
Everything else about the root — above
all its private key — stays in Vault.

## Roles: what may be issued

A **role** is to certificate issuance
what a policy is to reading: the
written constraint. The lab's role
allows one shape of certificate:

```bash
vault write pki/roles/inkwell-orders \
  allowed_domains=example.test allow_subdomains=true max_ttl=720h
```

Reading the role back shows the
constraints in force: `allowed_domains:
[example.test]`, `allow_subdomains:
true`, `max_ttl: 720h` (30 days),
`key_type: rsa`, `key_bits: 2048`,
`server_flag` and `client_flag` true.
A request for a name outside
`example.test`, or a lifetime beyond
30 days, is refused by the role before
any signing happens.

## Issue, decode, verify

```bash
vault write -format=json pki/issue/inkwell-orders \
  common_name="orders.inkwell.example.test" ttl=720h
```

The answer carries the certificate,
its private key, the issuing CA, a
**serial number**, and an expiration.
The lab's issue recorded serial
`55:ce:65:fb:bb:fe:b8:56:f1:f1:f4:cc:0f:91:12:d3:af:0d:06:f1`
and an expiry 30 days out. Two warnings
belong here, in the open. The issued
**private key is returned once, in
this response** — the caller must
store it as carefully as any secret in
this guide (into KV, for instance, is
a reasonable pattern). And Vault, by
default, also **stores** issued
certificates so they can be listed and
revoked by serial; the certificate
itself is public material, so that
storage is bookkeeping, not exposure.

Trust, however, should be verified by
somebody other than the issuer. The
lab decoded the certificate with
**openssl**, a tool that owes Vault
nothing:

```
subject=CN = orders.inkwell.example.test
issuer=CN = Inkwell Print Co. Internal CA
notBefore=Nov  7 21:48:59 2026 GMT
notAfter=Dec  7 21:49:29 2026 GMT
```

and then asked openssl the only
question that matters:

```bash
openssl verify -CAfile root-ca.pem issued-cert.pem
# issued-cert.pem: OK
```

`OK` from an independent tool is the
chapter's evidence: the chain is real,
the signature is valid, and a client
configured to trust the Inkwell root
will trust this service certificate —
for exactly its 30 days, and not a
day longer.

## What this chapter did not do

Real PKI deployments usually add an
**intermediate CA** between root and
leaves (the root signs one
intermediate, then goes quiet),
publish revocation information, and
renew service certificates
automatically. Those steps are
documented-only here (see
`criteria.md`); the single-tier root
above is the honest minimum that
demonstrates the engine end to end.

Check: mount PKI, generate a root,
write a role for your own test domain,
issue a certificate, and make
`openssl verify` say `OK` — then try
issuing for a name outside the role's
domains and watch the role refuse.
Success and refusal together are the
engine understood.
