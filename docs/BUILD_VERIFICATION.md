# Build & Functional Verification Report

- **Date:** `2026-11-20`
- **Verified By:** Jeffs' Automated build and deploy agent
- **Repository:** `jsoehner/vaultpki-demo`
- **Version:** `v1.1.0`
- **Status:** ✅ **VERIFIED**

---

## 1. Trusted OSS Split-Horizon Configuration & OSS Risk Remediation

- **GitHub Actions Variables & Secrets:** Configured `TRUSTED_OSS_CACHE_URL` (`https://jsigroup-oss.duckdns.org`), `TRUSTED_OSS_MODE=virtual`, `TRUSTED_OSS_GPG_EMAIL`, and mTLS client certificate/key secrets (`OSS_MTLS_CLIENT_CERT`, `OSS_MTLS_CLIENT_KEY`).
- **Local Development:** Local `.env` and `.npmrc` configured for LAN cache (`TRUSTED_OSS_CACHE_URL`) and excluded via `.gitignore`, `.git/info/exclude`, and `.dockerignore` (alongside `uv.toml`, `.mvn/settings.xml`, and `.mvn/maven.config`).
- **OSS Risk & Dependabot Alert Remediation (9/9 Resolved):**
  - Untracked LAN-only `.npmrc` and regenerated `package-lock.json` against `https://registry.npmjs.org` (`0` internal `.local` references; `npm audit`: `0 vulnerabilities`).
  - Upgraded `vitest` (`^5.1.1`) → resolved `@vitest/mocker@5.1.1` (patches `CVE-2026-112949`, `CVE-2026-112950`), `vite@8.3.8` (patches `CVE-2026-112942`–`CVE-2026-112947`), and `source-map-js@1.2.4` (patches `CVE-2026-93749`).
- **Registry Findings:**
  - **PyPI (`virtual`):** Reachable and verified (`pytest` and dependencies resolved cleanly via `uv run --index-url .../pypi/virtual/simple`).
  - **npm:** Public `https://registry.npmjs.org` used for lockfile & CI `npm ci` (`0` vulnerabilities); `.npmrc` stays strictly local/untracked so Dependabot and GitHub Actions succeed cleanly.
  - **Docker Images:** Upstream Docker Hub fallback (`hashicorp/vault:latest`, `nginx:latest`, `node:alpine`, `alpine:latest`) functioned as designed.

---

## 2. Build & Runtime Commands

```bash
# 1. Build the demo utility Docker image
docker build -t vaultpki-demo:verify .
docker run --rm vaultpki-demo:verify bash -c 'bash --version | head -n 1 && jq --version && curl --version | head -n 1 && docker --version'

# 2. Install Node.js dev dependencies (skipping bundled Chromium download)
PUPPETEER_SKIP_DOWNLOAD=true npm install --no-package-lock --registry=https://registry.npmjs.org

# 3. Run unit & integration test suites
npx vitest run --root tests/unit
npx vitest run --root src
npx vitest run --root tests/integration
uv run --index-url http://oss.jsigroup.local:8080/pypi/virtual/simple --with pytest pytest tests/unit -v
uv run --index-url http://oss.jsigroup.local:8080/pypi/virtual/simple --with pytest pytest tests/integration -v

# 4. Launch isolated 6-service Docker Compose stack (with SELinux :z volume labels on Enforcing hosts)
docker compose -p vaultpki-verify -f docker-compose.yml -f /tmp/vaultpki-verify/override.yml up -d
```

> **SELinux Note:** On hosts with SELinux `Enforcing`, bind-mounted volumes (`./config`, `./data`, `./certs`, `./agent`, `./dashboard`, `./nginx.conf`) require `:z` relabeling (applied via an isolated temporary override during verification so pre-existing local state remained untouched).

---

## 3. Functional Verification Results

### 3.1 Unit & Integration Tests

| Suite | Command | Result |
| :--- | :--- | :--- |
| Vitest Unit (`tests/unit`) | `npx vitest run --root tests/unit` | ✅ **2 passed** (`test_dashboard_backend.test.js`) |
| Vitest Source (`src`) | `npx vitest run --root src` | ✅ **3 passed** (`sample.test.ts`, `dashboard.test.ts`) |
| Vitest Integration (`tests/integration`) | `npx vitest run --root tests/integration` | ✅ **2 passed** (`test_vault_api.test.js`) |
| Pytest Unit (`tests/unit`) | `pytest tests/unit -v` | ✅ **12 passed, 1 skipped** (PowerShell syntax skipped on Linux) |
| Pytest Integration (`tests/integration`) | `pytest tests/integration -v` | ✅ **4 passed** (`test_vault_init.py`, `test_worker_signal.py`) |
| Docker Image Smoke Test | `docker build` + `docker run --rm` | ✅ **Passed** (Alpine + bash 5.3.9, jq 1.8.2, curl 8.23.0, docker-cli 29.9.3) |

### 3.2 Live 6-Service Vault PKI Stack & Certificate Rotation

- **`vault-init`:** Exited `0` — initialized and unsealed Vault `2.2.2`, provisioned Root CA (`My Organization Root CA`), Intermediate CA (`My Organization Intermediate CA`), `web-server` PKI role (with graceful ML-DSA-65 -> RSA 4096/2048 fallback), and `web-server-role` AppRole credentials.
- **`vault-agent`:** Authenticated via AppRole and rendered `/certs/test.example.com.crt` and `.key`. Observed live automatic certificate rotation from serial `132795E996A960F3B73E55B435A4E2E5A5AB6999` to `34396774EE0A146F6ADC9D209E753BF181B1468C` with zero downtime.
- **`demo-nginx`:** Served HTTPS on `https://127.0.0.1:8443/` using the Vault-issued leaf certificate.

### 3.3 Guided Headless Chrome Browser Verification (`browser_verify.py`)

| Target URL | HTTP Status | Page Title | Expected Heading | Interactive Click | Console Errors | JS Exceptions |
| :--- | :---: | :--- | :---: | :---: | :---: | :---: |
| `http://127.0.0.1:8080/` | `200` | `Vault PKI Real-Time Dashboard` | `"Vault PKI Live Monitor"` (`true`) | `#leaf-cert-card` (`CLICKED`) | `0` | `0` |

### 3.4 `curl` API & Security Verification (`api_verify.py` + authenticated probes)

| Endpoint | Method | Auth | HTTP Status | Result |
| :--- | :---: | :---: | :---: | :--- |
| `http://127.0.0.1:8200/v1/sys/health` | `GET` | None | `200` | ✅ Vault initialized & unsealed (`v2.2.2`) |
| `http://127.0.0.1:8080/` | `GET` | None | `200` | ✅ Dashboard HTML (`8,280 bytes`) |
| `http://127.0.0.1:8080/api/status` | `GET` | None | `401` | ✅ Auth-enforced (`{"success":false,"error":"Unauthorized"}`) |
| `http://127.0.0.1:8080/api/status` | `GET` | `X-API-KEY` | `200` | ✅ Live 3-tier trust chain JSON (`Leaf`, `Intermediate CA`, `Root CA`) |
| `http://127.0.0.1:8080/api/rotate` | `POST` | None | `401` | ✅ Auth-enforced (`{"success":false,"error":"Unauthorized"}`) |
| `http://127.0.0.1:8080/api/rotate` | `POST` | `X-API-KEY` | `200` | ✅ Worker rotation signal accepted (`{"success":true,...}`) |
| `https://127.0.0.1:8443/` | `GET` | None (TLS) | `200` | ✅ NGINX HTTPS response (`Hello from securely running NGINX using Vault PKI and Vault Agent!`) |
