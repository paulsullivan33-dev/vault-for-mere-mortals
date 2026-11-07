#!/usr/bin/env bash
# Lab driver for the Vault guide. Runs a DEV server on 127.0.0.1:18081
# (in-memory, throwaway) and captures every exercise into transcripts/.
# The root token below is a fixed, lab-only, throwaway dev credential
# chosen by this script for reproducibility. It is NOT a real secret
# and must never be used outside this lab.
set -u
LAB="$(cd "$(dirname "$0")" && pwd)"
SCRATCH="${SCRATCH:-$HOME/workspace/.batch-351-363/scratch-vault}"
VAULT_BIN="$SCRATCH/bin/vault"
T="$LAB/transcripts"
mkdir -p "$T" "$LAB/work"
export VAULT_ADDR="http://127.0.0.1:18081"
export VAULT_TOKEN="lab-root-token"
ROOT_TOKEN="lab-root-token"
cd "$LAB/work" || exit 1

say() { echo; echo "### $*"; }

# ---------- t00: version ----------
{
  say "vault version (plain)"
  "$VAULT_BIN" version
  say "vault version -format=json"
  "$VAULT_BIN" version -format=json
  say "binary and checksum evidence (recorded at download time)"
  echo "file: vault_2.2.1_linux_amd64.zip from https://releases.hashicorp.com/vault/2.2.1/"
  echo "sha256 (official SHA256SUMS and local sha256sum agree):"
  echo "079435de8ff146bdec4cdbe3be71d672ef4e59e4df6af0f2dba672e71be21a68  vault_2.2.1_linux_amd64.zip"
} > "$T/t00-version.txt" 2>&1

# ---------- start dev server ----------
"$VAULT_BIN" server -dev -dev-listen-address=127.0.0.1:18081 \
  -dev-root-token-id="$ROOT_TOKEN" > "$LAB/work/dev-server.log" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$LAB/work/server.pid"
# wait for health
for i in $(seq 1 60); do
  if curl -s -o /dev/null "$VAULT_ADDR/v1/sys/health"; then break; fi
  sleep 2
done

# ---------- t01: server start + status ----------
{
  say "dev server start command"
  echo "vault server -dev -dev-listen-address=127.0.0.1:18081 -dev-root-token-id=lab-root-token"
  echo "(root token is a fixed lab-only throwaway chosen by run-lab.sh; dev mode only)"
  say "excerpt of the server's own startup log (dev-server.log)"
  grep -E "Unseal Key|Root Token|Vault server started|core: vault is unsealed|WARNING" "$LAB/work/dev-server.log" | head -20
  say "vault status (CLI)"
  "$VAULT_BIN" status
  say "GET /v1/sys/health (HTTP API, no token needed for health)"
  curl -s "$VAULT_ADDR/v1/sys/health" | jq .
  say "GET /v1/sys/seal-status (HTTP API)"
  curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/seal-status" | jq .
  say "vault secrets list (what a fresh dev server mounts for you)"
  "$VAULT_BIN" secrets list
} > "$T/t01-dev-server-and-status.txt" 2>&1

# ---------- t02: KV v2 write/read ----------
{
  say "the dev server mounts KV v2 at secret/ — confirm"
  "$VAULT_BIN" secrets list -detailed | grep -E "Path|secret/"
  say "write v1: vault kv put secret/inkwell/orders db_password=... api_key=..."
  "$VAULT_BIN" kv put secret/inkwell/orders db_password='inkwell-db-pass-v1' api_key='ink-1111-orders'
  say "read it back: vault kv get secret/inkwell/orders"
  "$VAULT_BIN" kv get secret/inkwell/orders
  say "read just one field as JSON (HTTP API parity)"
  curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/inkwell/orders" | jq '.data.data, .data.metadata | {created_time, version}'
  say "overwrite with v2 (changed db_password)"
  "$VAULT_BIN" kv put secret/inkwell/orders db_password='inkwell-db-pass-v2' api_key='ink-1111-orders'
  say "read version 1 explicitly"
  "$VAULT_BIN" kv get -version=1 secret/inkwell/orders
  say "read latest (version 2)"
  "$VAULT_BIN" kv get secret/inkwell/orders
} > "$T/t02-kv-write-read.txt" 2>&1

# ---------- t03: KV versions, delete vs destroy ----------
{
  say "a scratch secret with three versions"
  "$VAULT_BIN" kv put secret/inkwell/scratch note='first'
  "$VAULT_BIN" kv put secret/inkwell/scratch note='second'
  "$VAULT_BIN" kv put secret/inkwell/scratch note='third'
  say "version history: vault kv metadata get"
  "$VAULT_BIN" kv metadata get secret/inkwell/scratch
  say "SOFT DELETE the latest version (v3): vault kv delete"
  "$VAULT_BIN" kv delete secret/inkwell/scratch
  say "read after soft delete — data is gone from view, deletion_time is set"
  "$VAULT_BIN" kv get secret/inkwell/scratch || true
  "$VAULT_BIN" kv get -version=3 secret/inkwell/scratch || true
  say "UNDELETE v3: vault kv undelete -versions=3"
  "$VAULT_BIN" kv undelete -versions=3 secret/inkwell/scratch
  "$VAULT_BIN" kv get secret/inkwell/scratch
  say "DESTROY v1 permanently: vault kv destroy -versions=1"
  "$VAULT_BIN" kv destroy -versions=1 secret/inkwell/scratch
  say "read v1 after destroy — it does not come back"
  "$VAULT_BIN" kv get -version=1 secret/inkwell/scratch || true
  say "metadata after destroy (v1 marked destroyed)"
  "$VAULT_BIN" kv metadata get secret/inkwell/scratch
  say "DELETE ALL metadata and versions: vault kv metadata delete (on a second scratch secret)"
  "$VAULT_BIN" kv put secret/inkwell/scratch2 note='gone soon'
  "$VAULT_BIN" kv metadata delete secret/inkwell/scratch2
  "$VAULT_BIN" kv metadata get secret/inkwell/scratch2 || true
  say "rollback demo: roll the orders secret back to version 1"
  "$VAULT_BIN" kv rollback -version=1 secret/inkwell/orders
  "$VAULT_BIN" kv get secret/inkwell/orders
} > "$T/t03-kv-versions-delete-destroy.txt" 2>&1

# ---------- t04: policy + denial ----------
cat > "$LAB/work/inkwell-reader.hcl" <<'EOF'
# Inkwell Print Co. — the orders service may READ exactly one secret.
path "secret/data/inkwell/orders" {
  capabilities = ["read"]
}
EOF
cp "$LAB/work/inkwell-reader.hcl" "$LAB/fixtures/inkwell-reader.hcl"
{
  say "write a second secret the policy does NOT cover"
  "$VAULT_BIN" kv put secret/inkwell/billing card_token='billing-secret-not-for-orders'
  say "the policy file (fixtures/inkwell-reader.hcl)"
  cat "$LAB/work/inkwell-reader.hcl"
  say "install it: vault policy write inkwell-reader"
  "$VAULT_BIN" policy write inkwell-reader "$LAB/work/inkwell-reader.hcl"
  say "read it back: vault policy read inkwell-reader"
  "$VAULT_BIN" policy read inkwell-reader
  say "create a token under the policy"
  "$VAULT_BIN" token create -policy=inkwell-reader -display-name=inkwell-orders-service -format=json > token-inkwell.json
  jq '{client_token: .auth.client_token, policies: .auth.policies, lease_duration: .auth.lease_duration}' token-inkwell.json
} > "$T/t04-policy-and-token.txt" 2>&1

INK_TOKEN=$(jq -r .auth.client_token token-inkwell.json)
{
  say "with the inkwell-reader token: read the ONE allowed path (CLI)"
  VAULT_TOKEN="$INK_TOKEN" "$VAULT_BIN" kv get secret/inkwell/orders
  say "with the inkwell-reader token: read the SAME path over the HTTP API"
  curl -s -H "X-Vault-Token: $INK_TOKEN" "$VAULT_ADDR/v1/secret/data/inkwell/orders" | jq -c .data.data
  say "DENIAL 1 (CLI): the same token reaches for secret/inkwell/billing"
  VAULT_TOKEN="$INK_TOKEN" "$VAULT_BIN" kv get secret/inkwell/billing || true
  say "DENIAL 2 (HTTP API): same request with curl — note HTTP 403 and the error body"
  curl -s -w "\nHTTP_STATUS=%{http_code}\n" -H "X-Vault-Token: $INK_TOKEN" "$VAULT_ADDR/v1/secret/data/inkwell/billing"
  say "DENIAL 3 (CLI): the same token tries to WRITE to its own allowed path (policy is read-only)"
  VAULT_TOKEN="$INK_TOKEN" "$VAULT_BIN" kv put secret/inkwell/orders db_password='should-fail' || true
  say "DENIAL 4 (CLI): the same token tries to list mounts"
  VAULT_TOKEN="$INK_TOKEN" "$VAULT_BIN" secrets list || true
  say "control check: the root token reads billing fine — the denial is the policy, not the data"
  "$VAULT_BIN" kv get secret/inkwell/billing
} > "$T/t04b-policy-denial.txt" 2>&1

# ---------- t05: transit ----------
{
  say "enable the transit engine at transit/"
  "$VAULT_BIN" secrets enable transit || true
  "$VAULT_BIN" secrets list | grep transit
  say "create a key named inkwell-orders"
  "$VAULT_BIN" write -f transit/keys/inkwell-orders
  "$VAULT_BIN" read transit/keys/inkwell-orders
  say "encrypt a plaintext (the plaintext travels base64-encoded, as the API requires)"
  PT_B64=$(printf 'inkwell-db-pass-v2' | base64)
  echo "plaintext base64: $PT_B64"
  "$VAULT_BIN" write transit/encrypt/inkwell-orders plaintext="$PT_B64" -format=json > encrypt.json
  jq . encrypt.json
  CT=$(jq -r .data.ciphertext encrypt.json)
  echo "ciphertext: $CT"
  say "decrypt it back with the same key"
  "$VAULT_BIN" write transit/decrypt/inkwell-orders ciphertext="$CT" -format=json > decrypt.json
  jq . decrypt.json
  echo "decoded plaintext: $(jq -r .data.plaintext decrypt.json | base64 -d)"
  say "the same encrypt over the HTTP API (curl)"
  curl -s -H "X-Vault-Token: $VAULT_TOKEN" -X POST -d "{\"plaintext\":\"$PT_B64\"}" "$VAULT_ADDR/v1/transit/encrypt/inkwell-orders" | jq -c .data
  say "proof the ciphertext is not the plaintext"
  echo "plaintext was: inkwell-db-pass-v2"
  echo "ciphertext is: $CT"
} > "$T/t05-transit.txt" 2>&1

# ---------- t06: PKI ----------
{
  say "enable the PKI engine at pki/ and tune its maximum lease"
  "$VAULT_BIN" secrets enable pki || true
  "$VAULT_BIN" secrets tune -max-lease-ttl=87600h pki
  say "create the root CA (Inkwell Print Co. Internal CA, TTL 10 years)"
  "$VAULT_BIN" write -field=certificate pki/root/generate/internal \
    common_name="Inkwell Print Co. Internal CA" ttl=87600h > root-ca.pem
  head -3 root-ca.pem
  say "create a role for the orders service (inkwell.example.test, 30-day certs)"
  "$VAULT_BIN" write pki/roles/inkwell-orders allowed_domains=example.test allow_subdomains=true max_ttl=720h
  "$VAULT_BIN" read pki/roles/inkwell-orders
  say "issue a certificate for orders.inkwell.example.test"
  "$VAULT_BIN" write -format=json pki/issue/inkwell-orders \
    common_name="orders.inkwell.example.test" ttl=720h > issued.json
  jq '{serial: .data.serial_number, expiration: .data.expiration}' issued.json
  jq -r .data.certificate issued.json > issued-cert.pem
  jq -r .data.issuing_ca issued.json > issuing-ca.pem
  say "the issued certificate, decoded by openssl"
  openssl x509 -in issued-cert.pem -noout -subject -issuer -dates -serial
  say "verify the issued certificate against the root CA with openssl"
  openssl verify -CAfile root-ca.pem issued-cert.pem
  say "also verify using the issuing_ca returned with the cert"
  openssl verify -CAfile issuing-ca.pem issued-cert.pem
} > "$T/t06-pki.txt" 2>&1
cp "$LAB/work/root-ca.pem" "$LAB/fixtures/root-ca.pem" 2>/dev/null || true
cp "$LAB/work/issued-cert.pem" "$LAB/fixtures/issued-cert.pem" 2>/dev/null || true

# ---------- t07: audit ----------
{
  say "enable a file audit device writing to the lab folder"
  "$VAULT_BIN" audit enable file file_path="$LAB/work/audit.log"
  "$VAULT_BIN" audit list
  say "make one distinctive request as root: read secret/inkwell/billing"
  "$VAULT_BIN" kv get secret/inkwell/billing > /dev/null
  say "make one distinctive DENIED request with the limited token (denials are audited too)"
  curl -s -H "X-Vault-Token: $INK_TOKEN" "$VAULT_ADDR/v1/secret/data/inkwell/billing" > /dev/null || true
  sleep 1
  say "the audit log is JSON, one object per line — the request lines for inkwell/billing"
  grep 'inkwell/billing' "$LAB/work/audit.log" | tail -2 | jq -c '{type, time, path: .request.path, operation: .request.operation, error: (.error // null)}'
  say "note: secret VALUES and token strings are HMAC-hashed in the audit log, never stored in clear"
  grep 'inkwell/billing' "$LAB/work/audit.log" | tail -1 | jq -c '{auth_token_hmac: .auth.accessor, request_id: .request.id}'
  say "how many requests the lab has audited so far"
  wc -l < "$LAB/work/audit.log"
} > "$T/t07-audit.txt" 2>&1
tail -5 "$LAB/work/audit.log" > "$LAB/fixtures/audit-log-excerpt.jsonl" 2>/dev/null || true

# ---------- t08: token leases — TTL, renew, revoke ----------
{
  say "create a renewable service token with a 120-second TTL"
  "$VAULT_BIN" token create -policy=inkwell-reader -ttl=120s -explicit-max-ttl=600s -format=json > lease-token.json
  LT=$(jq -r .auth.client_token lease-token.json)
  jq '{lease_duration: .auth.lease_duration, renewable: .auth.renewable}' lease-token.json
  say "look it up (note ttl counting down)"
  VAULT_TOKEN="$ROOT_TOKEN" "$VAULT_BIN" token lookup "$LT" | grep -E "ttl|expire_time|policies"
  say "RENEW it — the lease extends"
  "$VAULT_BIN" token renew -increment=120s "$LT" -format=json | jq '{lease_duration: .auth.lease_duration, renewable: .auth.renewable}'
  say "use it while it lives"
  VAULT_TOKEN="$LT" "$VAULT_BIN" kv get -field=db_password secret/inkwell/orders
  say "REVOKE it — revocation is immediate, not at expiry"
  "$VAULT_BIN" token revoke "$LT"
  echo "revoke exit code: $?"
  say "the revoked token can no longer read anything"
  VAULT_TOKEN="$LT" "$VAULT_BIN" kv get secret/inkwell/orders || true
  curl -s -w "\nHTTP_STATUS=%{http_code}\n" -H "X-Vault-Token: $LT" "$VAULT_ADDR/v1/secret/data/inkwell/orders"
  say "revoking a PARENT revokes its children (token tree)"
  "$VAULT_BIN" token create -policy=inkwell-reader -format=json > parent.json
  PARENT=$(jq -r .auth.client_token parent.json)
  CHILD=$(VAULT_TOKEN="$PARENT" "$VAULT_BIN" token create -policy=inkwell-reader -format=json | jq -r .auth.client_token)
  echo "child works before: $(VAULT_TOKEN="$CHILD" "$VAULT_BIN" kv get -field=db_password secret/inkwell/orders)"
  "$VAULT_BIN" token revoke "$PARENT"
  echo "child after parent revoked:"
  VAULT_TOKEN="$CHILD" "$VAULT_BIN" kv get secret/inkwell/orders || true
} > "$T/t08-token-leases.txt" 2>&1

# ---------- t09: seal / unseal (last — dev presents a single key) ----------
UNSEAL_KEY=$(grep -oE "Unseal Key: .*" "$LAB/work/dev-server.log" | head -1 | sed 's/Unseal Key: //')
{
  say "dev mode starts unsealed and prints ONE unseal key (threshold 1 of 1)"
  echo "unseal key from the startup log (lab-only, from an in-memory dev server): $UNSEAL_KEY"
  say "status before sealing"
  "$VAULT_BIN" status | grep -E "Sealed|Initialized"
  say "SEAL the server as root: vault operator seal"
  "$VAULT_BIN" operator seal
  say "status while sealed"
  "$VAULT_BIN" status || true
  say "while sealed, the API answers 503 and data is unreachable"
  curl -s -w "\nHTTP_STATUS=%{http_code}\n" "$VAULT_ADDR/v1/secret/data/inkwell/orders" -H "X-Vault-Token: $VAULT_TOKEN"
  curl -s "$VAULT_ADDR/v1/sys/health" | jq -c '{sealed, initialized, standby}'
  say "UNSEAL with the single key: vault operator unseal (key hidden from this transcript on purpose in real life — shown here because it is a throwaway dev key)"
  "$VAULT_BIN" operator unseal "$UNSEAL_KEY"
  say "status after unsealing — and the lab data is still there (it never left memory)"
  "$VAULT_BIN" status | grep -E "Sealed|Initialized"
  "$VAULT_BIN" kv get -field=db_password secret/inkwell/orders
} > "$T/t09-seal-unseal.txt" 2>&1

cp "$LAB/work/dev-server.log" "$T/t01b-dev-server-startup-log.txt"
echo "LAB DONE" > "$LAB/work/lab-done.txt"
kill "$SERVER_PID" 2>/dev/null
sleep 2
echo "server stopped" >> "$LAB/work/lab-done.txt"
