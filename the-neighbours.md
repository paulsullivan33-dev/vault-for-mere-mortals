# The neighbours

Outcome: where Vault sits among the
other ways people keep secrets, each
characterised on its own terms — so
choosing Vault, or not choosing it,
is a decision rather than a default.

These neighbours are characterised
from their own documentation, not
benchmarked; the lab did not run
them, and `criteria.md` lists them as
such.

## Config files and environment variables

The incumbent. A secret in a config
file or an environment variable costs
nothing, works everywhere, and is
understood by every program ever
written. Its limits are chapter 1's
three costs — no inventory, no
revocation, no audit — and they are
not theoretical. This remains a
reasonable choice for a single
application on a single machine owned
by one person, which is a description
of many real systems. Vault earns its
keep as the count of machines,
services, and people grows past what
one person's memory can inventory.

## Cloud secret managers

AWS Secrets Manager, Azure Key Vault,
and Google Cloud Secret Manager are
Vault's closest relatives: a central
guarded store, identity-checked
access, versioning, audit trails, and
—in the better cases — automatic
rotation. Inside one cloud, they are
the lower-effort answer: no server of
yours to run, seal, or back up, and
identity comes from the cloud itself.
Vault's counter-arguments are
portability (one system across clouds
and on-premises), its broader engines
(transit and PKI as first-class
services), and independence from a
cloud vendor's console and pricing.
The honest summary: if everything you
run lives in one cloud and its manager
covers your needs, Vault has to win
an argument, not win by default.

## Encrypted files in the repository: SOPS and age

**SOPS** (with **age** or a cloud KMS
as the key holder) encrypts secret
files so they can live in version
control beside the code that uses
them. The developer experience is
excellent and the audit trail is your
commit history. What it does not give
you is a runtime: no per-request
policy, no leases, no revocation of a
credential a running service already
holds — revoking means re-encrypting
and redeploying. It answers "how do
secrets reach the machine" better
than "how does the machine hold them
over time". The two compose well:
several deployments use SOPS for
bootstrap secrets and Vault for
everything after.

## Password managers

KeePass, Bitwarden, and 1Password
guard **human** secrets: logins a
person types, with sharing, filling,
and breach watching built for people.
Vault guards **machine** secrets:
credentials programs fetch at runtime,
at machine speed, under policy. The
boundary matters more than the
overlap. People should not paste from
a password manager into a service's
config as a permanent arrangement
(that recreates the scatter), and
services should not hold accounts in
a tool designed around a person
unlocking a vault with a master
password — though note the shared
vocabulary: both are "vaults" because
both are one guarded store instead of
a scatter.

## Platform-native secrets

Kubernetes Secrets, Docker secrets,
and a systemd unit's credential
features deliver values to workloads
on their own platform, usually as
files or environment variables at
start. They solve delivery inside
that platform and inherit its
identity model. Their limits show at
the platform's edge: the same secret
needed by two platforms, or a rotation
that must reach running workloads
without a restart. Vault commonly
sits behind them (a controller syncs
Vault values into Kubernetes Secrets)
or replaces them (workloads
authenticate to Vault directly). Both
patterns are documented-only in this
guide.

## The short version

- One machine, one person: files and
  environment variables are fine.
- One cloud, all-in: its secret
  manager first, Vault when you
  outgrow or out-port it.
- Secrets as code, deployed: SOPS.
- Humans logging in: a password
  manager.
- Many services, many machines,
  revocation and audit as daily
  needs, on any ground: Vault's home
  turf.

Check: name the neighbour closest to
how your secrets live today, and the
specific cost from chapter 1 that
would have to bite before moving
stopped being worth it. A decision
with a named trigger beats a migration
done on vibes.
