#!/bin/bash
set -e

# Ensure dependencies are available (like jq)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq and try again." >&2
    exit 1
fi

echo "Waiting for Vault to start..."
sleep 3

# Check if initialized
STATUS=$(docker exec vault-pki-demo vault status -format=json 2>/dev/null || true)
if echo "$STATUS" | grep -q '"initialized": true'; then
    echo "Vault is already initialized."
    
    if [ -f "vault-keys.txt" ]; then
        source vault-keys.txt
        echo "Unsealing..."
        docker exec vault-pki-demo vault operator unseal "$UNSEAL_KEY" || true
    else
        echo "Please unseal manually."
    fi
    exit 0
fi

echo "Initializing Vault..."
INIT_JSON=$(docker exec vault-pki-demo vault operator init -key-shares=1 -key-threshold=1 -format=json)
UNSEAL_KEY=$(echo "$INIT_JSON" | jq -r .unseal_keys_b64[0])
ROOT_TOKEN=$(echo "$INIT_JSON" | jq -r .root_token)

echo "UNSEAL_KEY=$UNSEAL_KEY" > vault-keys.txt
echo "ROOT_TOKEN=$ROOT_TOKEN" >> vault-keys.txt

echo "Unsealing Vault..."
docker exec vault-pki-demo vault operator unseal "$UNSEAL_KEY"

echo "Logging in..."
docker exec vault-pki-demo vault login "$ROOT_TOKEN"

echo "Running PKI setup based on the guide..."

# Enable Root CA
docker exec vault-pki-demo vault secrets enable -path=pki pki
docker exec vault-pki-demo vault secrets tune -max-lease-ttl=87600h pki
docker exec vault-pki-demo vault write pki/root/generate/internal \
  common_name="My Organization Root CA" \
  issuer_name="root-2026" \
  ttl=87600h key_type=rsa key_bits=4096
docker exec vault-pki-demo vault write pki/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

# Enable Intermediate CA
docker exec vault-pki-demo vault secrets enable -path=pki_int pki || true
docker exec vault-pki-demo vault secrets tune -max-lease-ttl=43800h pki_int

docker exec vault-pki-demo vault write -format=json pki_int/intermediate/generate/internal \
  common_name="My Organization Intermediate CA" \
  issuer_name="intermediate-2026" \
  key_type=rsa key_bits=4096 | jq -r ".data.csr" > intermediate.csr

docker cp intermediate.csr vault-pki-demo:/tmp/intermediate.csr

# Sign Intermediate CA
docker exec vault-pki-demo vault write -format=json pki/root/sign-intermediate \
  csr=@/tmp/intermediate.csr \
  format=pem_bundle \
  ttl=43800h | jq -r ".data.certificate" > intermediate.cert.pem

docker cp intermediate.cert.pem vault-pki-demo:/tmp/intermediate.cert.pem

docker exec vault-pki-demo vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem

docker exec vault-pki-demo vault write pki_int/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl" \
  ocsp_servers="http://127.0.0.1:8200/v1/pki_int/ocsp"

# Create a sample role
docker exec vault-pki-demo vault write pki_int/roles/web-server \
  allowed_domains="example.com" \
  allow_subdomains=true \
  max_ttl=8760h key_type=rsa key_bits=2048 \
  require_cn=true allow_ip_sans=true \
  server_flag=true client_flag=false

echo "Configuring AppRole for Vault Agent..."
docker exec vault-pki-demo vault auth enable approle || true

docker exec vault-pki-demo sh -c 'vault policy write cert-issuer - <<EOF
path "pki_int/issue/web-server" {
  capabilities = ["create", "update"]
}
EOF'

docker exec vault-pki-demo vault write auth/approle/role/web-server-role \
    policies="cert-issuer" \
    secret_id_ttl=720h \
    token_num_uses=0 \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_num_uses=0

mkdir -p ./agent
docker exec vault-pki-demo vault read -format=json auth/approle/role/web-server-role/role-id | jq -r .data.role_id > ./agent/roleid
docker exec vault-pki-demo vault write -format=json -f auth/approle/role/web-server-role/secret-id | jq -r .data.secret_id > ./agent/secretid

echo "Setup complete! You can issue certificates now."
