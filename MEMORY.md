# Project Memory

## 📖 Project Context
HashiCorp Vault PKI Demonstration project. A setup using Docker Compose to spin up a local Vault instance and automatically configure a secure, tiered PKI system for generating and rotating certificates via Vault Agent.
**Tech Stack:**
- HashiCorp Vault
- Docker / Docker Compose
- NGINX
- Bash Scripts
- PowerShell Scripts
- Node.js / TypeScript
- Python 3

## 🎯 Current Objectives
- [x] Initialize `MEMORY.md` using `memory-skill.md` instructions.
- [x] Create a unified orchestration script `run_demo.sh` to start and monitor the Vault PKI stack.
- [x] Implement a graceful fallback to RSA when `ml-dsa-65` is unsupported by the Vault PKI secrets engine.
- [x] Enable native Windows PowerShell orchestration and diagnostics (`run_demo.ps1`, `watch-rotation.ps1`, `check-cert.ps1`, `setup-pki.ps1`).
- [x] Enable dynamic trusted registry fallback and cross-platform LF line ending governance.

## 🧠 Key Decisions & Architecture
- **[2026-07-02] - GitHub Actions Updates:** Bumped major versions of GitHub Actions in workflow files to fix Node 20 deprecation warnings and ensure Node 24 support.
- **[2026-07-02] - Project Documentation:** Updated MEMORY.md to correctly reflect the Vault PKI demo context instead of an older Java/Spring Boot project.
- **[2026-08-11] - Post-Quantum Cryptography Migration**: Transitioned PKI CA trust hierarchy and mock generators to FIPS 204 post-quantum ML-DSA-65 algorithms and updated dashboard to display parsed signature types. Added ADR-006.
- **[2026-08-11] - Graceful Fallback and Orchestration**: Added a unified orchestration script `run_demo.sh` to run the stack, and updated script engine configs with automated RSA-4096 fallback to bypass local community Vault PQC limitations. Added ADR-007.
- **[2026-11-15] - Cross-Platform Windows PowerShell Orchestration**: Added native Windows PowerShell orchestration and tooling scripts (`run_demo.ps1`, `watch-rotation.ps1`, `check-cert.ps1`, `setup-pki.ps1`) with zero external binary dependencies and an automated test suite. Added ADR-010.
- **[2026-11-15] - Trusted Registry Dynamic Fallback & LF Enforcement**: Parameterized Docker Compose with `${REGISTRY_PREFIX:-}` to dynamically resolve or fall back to Docker Hub when internal registries are unpopulated. Added `.gitattributes` to strictly enforce LF endings on shell scripts across Windows environments.

## 👤 User Preferences
- Prefers CLI-only workflows for configuration activities; avoid UI-login-updated steps.
- Values retroactive documentation of completed activities and lessons learned in project docs.

## 📝 Unresolved Issues / Gotchas
- Vault Enterprise or specialized OpenSSL 3.5+ installation is required to generate/verify native ML-DSA certificates. When running locally without Docker or running classical open-source Vault, mock OpenSSL-based generation fallback is executed during tests.
- When cloning on Windows, Git may convert line endings to CRLF. Shell scripts mounted into Linux containers must enforce LF via `.gitattributes` to avoid shell execution errors (`illegal option -`).
