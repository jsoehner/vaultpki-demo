# ADR-001: Automated Vault PKI Initialization

## Status
Accepted

## Date
2026-07-11

## Context
Setting up a secure PKI structure using HashiCorp Vault normally requires multiple sequential manual CLI operations (initializing the operator, unsealing, enabling PKI secrets engines, generating root/intermediate CAs, configuring roles, policies, and AppRoles). While a shell script (`setup-pki.sh`) exists, running it manually is error-prone, hard to coordinate in CI/CD or container environments, and doesn't run automatically when spinning up the environment via `docker-compose`.

## Decision
Introduce a dedicated `vault-init` container service in `docker-compose.yml` running a helper script `config/vault-init.sh`. 

This container:
1. Waits for the Vault container to become responsive.
2. Checks if Vault is initialized and unsealed.
3. If not initialized, performs the operator init, stores the root token and unseal key under a shared volume, and unseals Vault.
4. Dynamically mounts and configures the Root CA, Intermediate CA, Certificate Roles, and AppRole credentials, writing the generated RoleID and SecretID to a shared agent directory.
5. Exit upon completion, letting the `vault-agent` start automatically afterwards.

## Alternatives Considered
### Manual Setup via setup-pki.sh
- **Pros**: Simple to write initially.
- **Cons**: Requires manual developer intervention after running `docker-compose up`. Hard to orchestrate.

### Docker Entrypoint Customization on main Vault Image
- **Pros**: Avoids extra containers.
- **Cons**: Harder to manage state and lifecycle hooks. The standard HashiCorp Vault image configuration does not easily support complex configuration steps before the service is fully online.

## Consequences
- Developers can spin up a fully configured PKI demo environment simply by running `docker-compose up -d`.
- Orchestration dependencies (`depends_on` with `condition: service_completed_successfully` for `vault-init`) ensure that `vault-agent` does not start before the role and credentials are fully provisioned.
- Credentials and keys are securely generated and shared inside container volumes.
