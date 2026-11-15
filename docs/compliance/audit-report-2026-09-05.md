# Compliance Audit Report: vaultpki-demo
**Date**: 2026-09-05
**Status**: Partial Compliance (Initial Assessment)
**Auditor**: Hermes Agent (Security & Compliance Specialist)

## 1. Executive Summary
The `vaultpki-demo` project demonstrates a strong foundation for secure PKI management through the use of a Worker Isolation Pattern (ADR-012) and automated Vault initialization. However, to achieve full SOC2 or PCI-DSS compliance, the system requires more robust audit persistence, automated key rotation, and formalized privacy documentation.

## 2. Compliance Framework Mapping

### GDPR (General Data Protection Regulation)
- **Data Minimization**: ✅ Pass. The system only collects minimal metadata (IP, timestamps, request IDs).
- **Privacy Notice**: ❌ Fail. No formal Privacy Policy or Consent mechanism is displayed to the dashboard user.
- **Right to Erasure**: ⚠️ Partial. Audit logs are currently persistent but lack a mechanism to purge specific user-related entries.

### SOC2 (Trust Services Criteria)
- **Security**: ✅ Pass. Implemented Bearer token authentication, worker isolation, and signal whitelisting.
- **Availability**: ✅ Pass. Service separation (Dashboard vs. Worker) prevents a dashboard crash from halting the worker.
- **Confidentiality**: ⚠️ Partial. API keys are passed via environment variables but lack a rotation policy.
- **Processing Integrity**: ✅ Pass. The rotation logic is strictly governed by the backend and signed by the Worker.

### PCI-DSS (Payment Card Industry Data Security Standard)
- **Requirement 3 (Protect Stored Cardholder Data)**: ⚠️ Partial. Certificate keys are stored on-disk. Requires encryption-at-rest of the volume.
- **Requirement 7 (Restrict Access)**: ✅ Pass. RBAC-style separation between the Dashboard (UI) and Worker (privileged operations).
- **Requirement 10 (Track and Monitor Access)**: ⚠️ Partial. Audit logs exist but are local to the container and lack centralized alerting.

## 3. Gap Analysis & Remediation Roadmap

| Priority | Gap | Remediation Action | Target Date |
| :--- | :--- | :--- | :--- |
| **High** | API Key Rotation | Implement a mechanism to rotate `DASHBOARD_API_KEY` without restarting the service. | 30 Days |
| **Medium** | Audit Persistence | Move `audit.log` to a persistent, centralized logging volume or service. | 30 Days |
| **Medium** | Cert Integrity | Ensure `certs/` directory is mounted as `ro` (Read-Only) in `docker-compose.yml`. | 30 Days |
| **Low** | Privacy Notice | Create and display a basic Privacy Notice and ToS on the dashboard frontend. | 60 Days |

## 4. Technical Controls Implemented
- **Worker Isolation**: ADR-012 ensures the Docker socket is never exposed to the dashboard.
- **Signal Whitelisting**: Worker only responds to the `"RESTART"` string.
- **Auth Middleware**: All `/api/*` routes require a `Bearer` token.
- **CORS Hardening**: Whitelisted specific origins to prevent cross-site requests.

## 5. Conclusion
The system is **audit-ready for internal review**. To move toward external certification, the focus must shift from "Security Logic" (which is well-implemented) to "Operational Compliance" (rotation, logging, and documentation).
