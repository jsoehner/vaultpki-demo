# Project Memory

## 📖 Project Context
HashiCorp Vault PKI Demonstration project. A setup using Docker Compose to spin up a local Vault instance and automatically configure a secure, tiered PKI system for generating and rotating certificates via Vault Agent.
**Tech Stack:**
- HashiCorp Vault
- Docker / Docker Compose
- NGINX
- Bash Scripts

## 🎯 Current Objectives
- [x] Initialize `MEMORY.md` using `memory-skill.md` instructions.
- [ ] (Add future objectives here)

## 🧠 Key Decisions & Architecture
- **[2026-07-02] - GitHub Actions Updates:** Bumped major versions of GitHub Actions in workflow files to fix Node 20 deprecation warnings and ensure Node 24 support.
- **[2026-07-02] - Project Documentation:** Updated MEMORY.md to correctly reflect the Vault PKI demo context instead of an older Java/Spring Boot project.
- **[2026-08-11] - Post-Quantum Cryptography Migration**: Transitioned PKI CA trust hierarchy and mock generators to FIPS 204 post-quantum ML-DSA-65 algorithms and updated dashboard to display parsed signature types. Added ADR-006.

## 👤 User Preferences
- Prefers CLI-only workflows for configuration activities; avoid UI-login-updated steps.
- Values retroactive documentation of completed activities and lessons learned in project docs.

## 📝 Unresolved Issues / Gotchas
- Vault Enterprise or specialized OpenSSL 3.5+ installation is required to generate/verify native ML-DSA certificates. When running locally without Docker or running classical open-source Vault, mock OpenSSL-based generation fallback is executed during tests.
