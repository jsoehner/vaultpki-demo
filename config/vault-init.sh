#!/bin/sh
set -e

export VAULT_ADDR="http://vault:8200"

echo "Waiting for Vault to start..."
until vault status -format=json 2>/dev/null || [ $? -eq 2 ]; do
  echo "Vault is not ready yet. Retrying..."
  sleep 1
done

# Check if initialized
if vault status -format=json | grep -q '"initialized": true'; then
    echo "Vault is already initialized."
    # Check if sealed
    if vault status -format=json | grep -q '"sealed": true'; then
        echo "Vault is sealed. Attempting to unseal..."
        KEYS_FILE=""
        if [ -f "/vault/config/vault-keys.txt" ]; then
            KEYS_FILE="/vault/config/vault-keys.txt"
        elif [ -f "/vault/vault-keys.txt" ]; then
            KEYS_FILE="/vault/vault-keys.txt"
        fi

        if [ -n "$KEYS_FILE" ]; then
            UNSEAL_KEY=$(grep "UNSEAL_KEY=" "$KEYS_FILE" | cut -d'=' -f2- | tr -d '\r')
            if [ -n "$UNSEAL_KEY" ]; then
                vault operator unseal "$UNSEAL_KEY"
                echo "Vault unsealed successfully."
            else
                echo "Error: UNSEAL_KEY not found in $KEYS_FILE"
                exit 1
            fi
        else
            echo "Error: vault-keys.txt not found. Cannot unseal."
            exit 1
        fi
    else
        echo "Vault is already unsealed."
    fi
else
    echo "Initializing Vault..."
    INIT_OUT=$(vault operator init -key-shares=1 -key-threshold=1)
    UNSEAL_KEY=$(echo "$INIT_OUT" | grep "Unseal Key 1:" | awk '{print $NF}')
    ROOT_TOKEN=$(echo "$INIT_OUT" | grep "Initial Root Token:" | awk '{print $NF}')

    echo "UNSEAL_KEY=$UNSEAL_KEY" > /vault/config/vault-keys.txt
    echo "ROOT_TOKEN=$ROOT_TOKEN" >> /vault/config/vault-keys.txt

    echo "Unsealing Vault..."
    vault operator unseal "$UNSEAL_KEY"

    echo "Logging in..."
    vault login "$ROOT_TOKEN"

    echo "Configuring PKI..."
    # Enable Root CA
    vault secrets enable -path=pki pki
    vault secrets tune -max-lease-ttl=87600h pki
    vault write pki/root/generate/internal \
      common_name="My Organization Root CA" \
      issuer_name="root-2026" \
      ttl=87600h key_type=rsa key_bits=4096
    vault write pki/config/urls \
      issuing_certificates="http://vault:8200/v1/pki/ca" \
      crl_distribution_points="http://vault:8200/v1/pki/crl"

    # Enable Intermediate CA
    vault secrets enable -path=pki_int pki || true
    vault secrets tune -max-lease-ttl=43800h pki_int

    # Generate CSR
    vault write -field=csr pki_int/intermediate/generate/internal \
      common_name="My Organization Intermediate CA" \
      issuer_name="intermediate-2026" \
      key_type=rsa key_bits=4096 > /tmp/intermediate.csr

    # Sign Intermediate CA
    vault write -field=certificate pki/root/sign-intermediate \
      csr=@/tmp/intermediate.csr \
      format=pem_bundle \
      ttl=43800h > /tmp/intermediate.cert.pem

    # Set Signed
    vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem

    vault write pki_int/config/urls \
      issuing_certificates="http://vault:8200/v1/pki_int/ca" \
      crl_distribution_points="http://vault:8200/v1/pki_int/crl" \
      ocsp_servers="http://vault:8200/v1/pki_int/ocsp"

    # Create role
    vault write pki_int/roles/web-server \
      allowed_domains="example.com" \
      allow_subdomains=true \
      max_ttl=8760h key_type=rsa key_bits=2048 \
      require_cn=true allow_ip_sans=true \
      server_flag=true client_flag=false

    echo "Configuring AppRole for Vault Agent..."
    vault auth enable approle || true

    vault policy write cert-issuer - <<EOF
path "pki_int/issue/web-server" {
  capabilities = ["create", "update"]
}
EOF

    vault write auth/approle/role/web-server-role \
        policies="cert-issuer" \
        secret_id_ttl=720h \
        token_num_uses=0 \
        token_ttl=1h \
        token_max_ttl=4h \
        secret_id_num_uses=0

    # Write role-id and secret-id
    vault read -field=role_id auth/approle/role/web-server-role/role-id > /vault/agent/roleid
    vault write -f -field=secret_id auth/approle/role/web-server-role/secret-id > /vault/agent/secretid

    echo "PKI setup complete!"
fi
