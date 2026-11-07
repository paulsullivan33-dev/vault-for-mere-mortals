# Encryption as a service

Outcome: a value encrypted and
decrypted by Vault's transit engine,
with the key never leaving Vault —
and proof, in the transcript, that
what your application stores is not
the secret.

All evidence is transcript
`vault-lab/transcripts/t05-transit.txt`.

## The problem transit solves

Applications need to encrypt data —
a stored card reference, a private
note, a backup. The usual arrangement
puts an encryption key in the
application's config, which recreates
chapter 1's scatter in a worse
costume: now the secret that protects
all the other secrets is itself copied
everywhere the application runs.

The **transit engine** inverts it. The
key lives in Vault. The application
sends **plaintext** to Vault and
receives **ciphertext**; it stores the
ciphertext wherever it likes — a
database, a file, a log — because the
ciphertext alone is useless. To read
the value back, the application sends
the ciphertext to Vault and receives
the plaintext. The key is never in the
application's memory, config, or
repository. Vault lends the *use* of
the key; the key itself is never given
away. Chapter 1's rule, wearing a
different hat.

## Setting it up

```bash
vault secrets enable transit
vault write -f transit/keys/inkwell-orders
vault read transit/keys/inkwell-orders
```

The key's record names what matters:
`type: aes256-gcm96` (the cipher),
`latest_version: 1`, `exportable:
false`, `deletion_allowed: false`.
Those last two are defaults worth
pausing on: a transit key cannot be
exported and cannot be deleted
without an operator deliberately
changing the key's configuration
first. Accidents and casual misuse are
designed out.

## Encrypt, decrypt

Plaintext travels **base64-encoded** —
the API carries bytes, and base64 is
how bytes ride in JSON. The lab
encrypted the orders database password:

```bash
printf 'inkwell-db-pass-v2' | base64
# aW5rd2VsbC1kYi1wYXNzLXYy

vault write transit/encrypt/inkwell-orders \
  plaintext=aW5rd2VsbC1kYi1wYXNzLXYy
```

```json
{"data": {"ciphertext": "vault:v1:DAStIcGHpvIfDK4/APcNKKGaUcLTBzSumLq6bbdO6tXor4zrby/vOsx+mgJPQQ==",
          "key_version": 1}}
```

Decrypting is the mirror:

```bash
vault write transit/decrypt/inkwell-orders \
  ciphertext='vault:v1:DAStI...'
# plaintext: aW5rd2VsbC1kYi1wYXNzLXYy → decoded: inkwell-db-pass-v2
```

Three observations the transcript
makes concrete:

1. **The ciphertext is not the
   plaintext.** It carries a `vault:v1:`
   prefix — Vault's own label, naming
   the key **version** that produced
   it — followed by data that shows no
   trace of the password. Anyone who
   steals the application's database
   steals these strings, and nothing
   else.
2. **Encrypting twice gives two
   different ciphertexts.** The lab's
   follow-up encrypt over curl returned
   a different `vault:v1:...` string
   for the same plaintext, because each
   encryption uses a fresh random
   **nonce** (a one-time number folded
   into the cipher). Both decrypt to
   the same password. Do not compare
   ciphertexts to test equality of
   plaintexts; decrypt, or do not
   compare.
3. **Policy applies here too.** A
   token needs a rule for
   `transit/encrypt/inkwell-orders` and
   a separate one for
   `transit/decrypt/...`. The
   decrypt capability is the powerful
   one, and a careful deployment grants
   encrypt widely and decrypt narrowly.

## Rotation, briefly

Transit keys are versioned like KV
secrets. Rotating
(`transit/keys/<name>/rotate`) makes
new encryptions use a new version;
old ciphertext still decrypts, because
the `v1:` label in it tells Vault
which key version to use, and a
**rewrap** operation upgrades stored
ciphertext to the current version
without exposing plaintext to the
application. The lab created version 1
and used it; rotation itself is
documented-only in this guide (see
`criteria.md`), described here from
the key record's own fields
(`latest_version`, `min_decryption_version`),
which exist precisely for it.

Check: create a key, encrypt a word,
and decrypt the result; confirm the
decoded plaintext is your word and
that the ciphertext contains no part
of it. Then encrypt the same word
again and confirm the ciphertext
differs while the decryption does
not. Both behaviours, seen once, are
the chapter.
