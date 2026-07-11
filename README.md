# HashiCorp Vault PKI Demonstration

A robust, scalable demonstration of automated **Public Key Infrastructure (PKI)** using **HashiCorp Vault** as a private Certificate Authority (CA) to orchestrate real-time, zero-downtime certificate rotation for local services.

---

## Quick Start

1. **Spin up the stack**:
   ```bash
   docker-compose up -d
   ```
   This starts the Vault server, NGINX web server, the automated Vault initialization agent, and the live dashboard.

2. **Wait for automated initialization**:
   The `vault-init` container will automatically run the setup, unseal Vault, configure the PKI engines, generate CA certs, configure AppRoles, and write authorization keys.

3. **Check the Live Dashboard**:
   Open [http://127.0.0.1:8080](http://127.0.0.1:8080) to view the live trust chain and real-time rotation monitoring.

4. **Watch rotation via CLI**:
   ```bash
   ./watch-rotation.sh
   ```

---

## Commands

| Command / Run Tool | Scope | Description |
|--------------------|-------|-------------|
| `docker-compose up -d` | Docker Stack | Starts all services (Vault, NGINX, Vault Agent, Vault Init, Dashboard) |
| `docker-compose down` | Docker Stack | Stops and cleans up all active container resources |
| `./setup-pki.sh` | Shell Script | Manual wrapper for PKI configuration (fallback/alternative to `vault-init`) |
| `./watch-rotation.sh` | Shell Script | CLI monitor that outputs certificate information on file updates |
| `./check-cert.sh` | Shell Script | Checks the details of the generated leaf certificate |
| `npm install` | Local Node.js | Installs development tools and type mappings |
| `npm run dashboard` | Local Node.js | Launches the monitoring dashboard backend server locally |
| `npm test` | Local Node.js | Runs the automated Puppeteer browser integration test |
| `python3 hamming_distance.py` | Python Script | Runs local test cases for the Hamming distance utility |

---

## Architecture & Decisions

The demo environment consists of the following components:
1. **Vault (CA Host)**: Manages Root and Intermediate CAs.
2. **Vault Init**: Automatically provisions and configures engines, roles, policies, and credentials (see [ADR-001](file://docs/decisions/0001-automated-vault-initialization.md)).
3. **Vault Agent**: Securely caches credentials and automatically fetches new certificates when they are near expiration.
4. **NGINX**: Serves secure HTTPS traffic. It reloads certificates with zero-downtime upon receiving a reload signal from the Vault Agent.
5. **PKI Monitor Dashboard**: Exposes SSE stream of rotation events and includes manual triggers (see [ADR-002](file://docs/decisions/0002-real-time-pki-dashboard.md) and [ADR-005](file://docs/decisions/0005-interactive-rotation-and-puppeteer-testing.md)).
6. **TypeScript Template**: Prepared structure for compiled backend features (see [ADR-003](file://docs/decisions/0003-typescript-and-package-setup.md)).
7. **Hamming Distance Utility**: Standalone Python module for validation logic (see [ADR-004](file://docs/decisions/0004-hamming-distance-python-utility.md)).
8. **Automated UI Test Suite**: Puppeteer-based headless browser tests to verify UI responsiveness and SSE rotation triggers (see [ADR-005](file://docs/decisions/0005-interactive-rotation-and-puppeteer-testing.md)).

For in-depth architectural choices, context, and consequences, consult our Architecture Decision Records:
- [ADR-001: Automated Vault PKI Initialization](file://docs/decisions/0001-automated-vault-initialization.md)
- [ADR-002: Real-time PKI and Certificate Rotation Dashboard](file://docs/decisions/0002-real-time-pki-dashboard.md)
- [ADR-003: TypeScript and Package Configuration](file://docs/decisions/0003-typescript-and-package-setup.md)
- [ADR-004: Hamming Distance Python Utility](file://docs/decisions/0004-hamming-distance-python-utility.md)
- [ADR-005: Interactive Certificate Rotation and Puppeteer UI Testing](file://docs/decisions/0005-interactive-rotation-and-puppeteer-testing.md)

---

## Security & Workflows

This project incorporates strict security practices:
1. **AppRole Secret Management**: The Vault Agent automatically destroys its local copy of the SecretID after reading it (`remove_secret_id_file_after_reading = true`).
2. **Network Isolation**: All forwarded ports (Vault on `8200`, NGINX on `8443`) bind to `127.0.0.1` inside `docker-compose.yml` to limit exposure to the local host interface.
3. **Vulnerability Scanning**: A weekly security workflow ([scan.yml](file://.github/workflows/scan.yml)) scans the repository and the built Docker image using Trivy, with all GitHub Action steps pinned to immutable commit SHAs for supply chain security.

## Gotchas & Lessons Learned

### GitHub Actions Node 20 Deprecation
When a GitHub Action runner complains about Node 20 deprecation (`Node.js 20 is deprecated... forced to run on Node.js 24`), simply updating `setup-node` does not fix warnings from third-party actions. You **must** bump the major version of the affected actions. For example, `actions/checkout` must be bumped to `@v7`, and Docker actions (e.g., `docker/build-push-action`) often must be bumped to `@v7` as well.

### Gitleaks Action Quirks
When upgrading the Gitleaks action to `@v3` (for Node 24 support), you might encounter an `Unexpected input(s) 'args'` error. This occurs because strict input validation rejects the `args` parameter in `v3`. The solution is to remove the `with: args: ...` block entirely, as the action now automatically executes the `detect` command.

### QEMU Cache Locking in Actions
If you see a warning like `Unable to reserve cache with key ... another job may be creating this cache`, it is a race condition caused by concurrent jobs (e.g., a push and PR trigger running simultaneously) trying to save the exact same QEMU cache. This is a benign warning, safely ignored, and won't fail your pipeline.

### Setup-Trivy Action Resolution Errors
If you pin the `aquasecurity/trivy-action` to a specific version (e.g., `v0.28.0`), it may suddenly fail with `Unable to resolve action aquasecurity/setup-trivy@v0.2.1`. This happens because a security incident forced the maintainers to delete older version tags for `setup-trivy`. To fix this, update your workflow to use `aquasecurity/trivy-action@master` (or a release `>= v0.35.0`) which points to known-secure dependencies.

### Docker Build Context Permissions
If your CI workflow (or a local build) runs `docker build .` in the same directory where Vault is running, Docker will attempt to copy the `data/` directory (including `data/raft`) into the build context. Because this folder is owned by root, Docker will throw a `permission denied` error. Always use a `.dockerignore` file to exclude sensitive/system directories (like `.git`, `data`, `certs`, `agent`) from your build context.
