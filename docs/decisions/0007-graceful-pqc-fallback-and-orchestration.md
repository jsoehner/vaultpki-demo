# ADR-007: Graceful PQC Fallback and Unified Orchestration

## Status
Accepted

## Date
2026-08-11

## Context
Following the transition to post-quantum cryptography (PQC) using `ml-dsa-65` signatures (ADR-006), local deployments of standard community edition HashiCorp Vault containers failed to initialize. Because public community releases of Vault lack native PQC support in the PKI secrets engine, the automated setup threw errors when writing internal keys with the `ml-dsa-65` key type.

To ensure the demo runs out-of-the-box in environments running classical or community Vault, we need a fallback mechanism. Furthermore, the user experience was fragmented, requiring multiple manual Docker Compose commands and scripting steps without an automated way to verify when initialization had finished.

## Decision
1. **Graceful PQC Fallback in Setup Scripts**:
   - Update `config/vault-init.sh` and `setup-pki.sh` to try generating Root/Intermediate CAs and issuing roles with `key_type=ml-dsa-65`.
   - If Vault returns an error (such as `unsupported hash signature algorithm`), capture the error, log a warning, and fall back to classical RSA (`key_type=rsa` with 4096-bit keys for CAs and 2048-bit keys for issuing roles).
2. **Unified Orchestration Script (`run_demo.sh`)**:
   - Create a top-level `run_demo.sh` orchestrator script that cleans the Docker environment (`docker compose down -v`), starts the services in the background, polls the `vault-init` container until completion, and prints the statuses of the final running containers.
3. **Documentation Updates**:
   - Document the fallback logic and orchestrator usage instructions in the README and project history.

## Consequences
- The local demonstration stack successfully runs to completion, starting all containers (including NGINX and Vault Agent) using classical RSA keys on community Vault.
- If run in an environment with Enterprise/PQC-enabled Vault, the system will natively use post-quantum `ml-dsa-65` certificates without modification.
- Users have a single, robust entry point (`./run_demo.sh`) to start, initialize, and monitor the PKI demonstration.
