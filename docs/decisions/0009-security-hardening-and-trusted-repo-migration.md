# ADR-009: Security Hardening and Trusted Repository Migration

## Status
Accepted

## Date
2026-11-15

## Context
The Vault PKI demo application infrastructure and software stack required comprehensive security assessment, principle of least privilege enforcement, and trusted software supply chain provenance. Initial setups relied on public registries (Docker Hub and public npm registry), elevated container privileges (root execution and Docker socket binding in application layers), and persistent plaintext secret handling in initialization scripts.

To establish enterprise-grade defense-in-depth and meet SOC2 / PCI-DSS compliance baselines, the software supply chain must be locked to a verified private artifact repository and container runtime boundaries hardened.

## Decision
We enforce the following architectural security controls across the project:

1. **Trusted Repository Migration**:
   - All Docker images in `docker-compose.yml` and `Dockerfile` pull from internal trusted mirror: `oss.jsigroup.local:8080`.
   - All NPM package resolution is pinned to `http://oss.jsigroup.local:8080/` via `.npmrc` and lockfile integrity checks (`package-lock.json`).

2. **Privilege Reduction & Worker Isolation**:
   - `vault-agent` execution user is restricted to non-root UID/GID (`1001:1001`).
   - The Docker socket (`/var/run/docker.sock`) is removed from the web-facing dashboard service and strictly isolated according to ADR-012.

3. **Secure Secrets Management**:
   - Automated `vault-init.sh` script does not persist unseal keys or root tokens to world-readable disk files (`config/vault-keys.txt`).
   - Dashboard endpoints (`/api/status`, `/api/rotate`) enforce `Bearer` / `X-API-KEY` token authentication (`DASHBOARD_API_KEY`).

4. **TLS Hardening & Infrastructure Protection**:
   - Enforce TLS in production listener configurations for Vault communications.
   - Restrict CORS headers to explicit trusted localhost/loopback origins.
   - Enforce strict path validation on dashboard static file delivery preventing directory traversal attacks.

## Consequences
- **Positive**: Eliminates supply chain risks from untrusted external mirrors, achieves strict least-privilege container boundaries, and eliminates plaintext secret exposure.
- **Positive**: Passes static vulnerability (SAST), AST cryptographic analysis, and dependency security compliance gates.
- **Neutral**: Requires network access to `oss.jsigroup.local:8080` for package restoration and image pulling.
