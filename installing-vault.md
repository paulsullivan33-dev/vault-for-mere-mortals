# Installing Vault

Outcome: a `vault` command on your
machine whose version you have seen
with your own eyes, obtained the same
way the lab obtained it — the official
release file, verified against the
publisher's checksums.

## What you are installing

One binary. Vault's server, its
command-line client, and its operator
commands are all the same program,
`vault`; the arguments decide which
hat it wears. There is nothing else to
install for this guide: no database, no
runtime, no agent.

## The route the lab used: the official release zip

HashiCorp publishes every release at
`releases.hashicorp.com/vault/`, one
folder per version, with a zip per
operating system and architecture and a
`SHA256SUMS` file of checksums. The lab
used:

- Version: **Vault 2.2.1**
- File: `vault_2.2.1_linux_amd64.zip`
- SHA-256 of the zip:
  `079435de8ff146bdec4cdbe3be71d672ef4e59e4df6af0f2dba672e71be21a68`

The checksum was checked two ways: the
local `sha256sum` of the downloaded zip
and the line for the same file in the
release's own `SHA256SUMS`. They
agreed. Do the same check with whatever
version is current when you read this —
the point of the exercise is the habit,
not the number.

```bash
curl -O https://releases.hashicorp.com/vault/2.2.1/vault_2.2.1_linux_amd64.zip
curl -O https://releases.hashicorp.com/vault/2.2.1/vault_2.2.1_SHA256SUMS
grep linux_amd64 vault_2.2.1_SHA256SUMS
sha256sum vault_2.2.1_linux_amd64.zip   # must match the line above
unzip vault_2.2.1_linux_amd64.zip
./vault version
```

The lab kept the binary in its own
folder and ran it from there rather
than installing it system-wide. Copying
it into a folder on your `PATH` (such
as `/usr/local/bin`) is the ordinary
next step on a machine that is yours.

## The version check every install must pass

```bash
vault version
```

The lab's answer, captured before
anything else was trusted (transcript
`vault-lab/transcripts/t00-version.txt`):

```
Vault v2.2.1 (0e7c41b936218bd2401ab0f891c93bec10e2e8e4), built 2026-10-22T16:27:49Z
```

One honest wrinkle: the lab also ran
`vault version -format=json`, and
2.2.1 printed the same plain banner
rather than JSON (transcript t00 keeps
both lines). The version command is a
banner, not a data endpoint; scripts
that need machine-readable facts
should read them from the API's
`sys/health` or `sys/seal-status`
endpoints instead, as chapter 4 does.
If your first command answers with a
version line, the install is real. If
it answers with "command not found",
the binary is not on your `PATH` — the
fix is the path, not a reinstall.

## Other routes, labelled honestly

HashiCorp also publishes packages for
common Linux distributions, a Homebrew
formula for macOS, and container
images. The lab did not use them and
this guide does not claim to have
tested them; they are documented-only
here. Whichever route you take, finish
with the same `vault version` check —
the guide's chapters assume a binary
that passes it.

One habit worth forming now: Vault
upgrades are frequent and the release
notes matter, because a server upgrade
touches the thing that guards every
other secret you own. Read them before
you replace a production binary. The
lab, being disposable, never faces
this; your real server will.

Check: run `vault version`, then find
your release's checksum in its
`SHA256SUMS` file and confirm your
download matches it. Both done means
you are installed the way the lab was.
