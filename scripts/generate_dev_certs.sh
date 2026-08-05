#!/usr/bin/env bash
# Generates a throwaway self-signed CA + server certificate so you can
# test DB_SSL=true locally before wiring up real certificates in
# production. NEVER use output from this script outside local dev —
# it is not audited, not rotated, and the private key sits unencrypted
# on disk next to it.
set -euo pipefail

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/certs"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

echo "Generating dev-only CA + MySQL server certificate in $OUT_DIR ..."

openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -nodes -days 365 -key ca-key.pem -out ca.pem \
  -subj "/CN=functional-mysql-db-dev-CA"

openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -out server-req.pem \
  -subj "/CN=mysql"
openssl x509 -req -in server-req.pem -days 365 \
  -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem

rm -f server-req.pem
chmod 600 ./*-key.pem

cat <<'EOF'

Done. Files written to ./certs (already in .gitignore — never commit these):
  ca.pem           — CA certificate. Point your client's ssl.ca at this.
  server-cert.pem  — MySQL server certificate
  server-key.pem   — MySQL server private key

To actually enable TLS on the bundled container, mount these into
/etc/mysql/certs and add --ssl-ca/--ssl-cert/--ssl-key to the `command:`
list in docker-compose.yml, then set DB_SSL=true in your app's .env.
This is deliberately a manual, opt-in step rather than always-on in
docker-compose.yml — see docs/CONNECTING.md for the full walkthrough.
EOF
