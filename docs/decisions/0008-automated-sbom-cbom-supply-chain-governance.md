# ADR-008: Automated SBOM and CBOM Supply Chain Governance

## Status
Accepted

## Date
2026-10-11

## Context
As the HashiCorp Vault PKI demonstration environment orchestrates dynamic certificate authorities, automated rotations, and post-quantum cryptography (PQC) transitions (ML-DSA-65 / ADR-006, ADR-007), visibility into the cryptographic assets and software supply chain dependencies is paramount. 

Classical vulnerability scanning (such as container image scans) reports known CVEs but fails to provide:
1. Complete Software Bill of Materials (SBOM) in interoperable standard formats (CycloneDX and SPDX).
2. Cryptographic Bill of Materials (CBOM) documenting algorithms, key lengths, curves, protocols, and certificate chains used within runtime dependencies and application source code.
3. Static abstract syntax tree (AST) code scanning to identify cryptographic call-sites and reconcile them against declared software bills of materials.
4. Continuous assessment of Post-Quantum Cryptography (PQC) readiness and automated CI enforcement against weak or deprecated cryptographic primitives (e.g., SHA-1, MD5, DES).

Without an automated pipeline, cryptographic inventories must be maintained manually, risking blind spots in supply chain security and compliance posture.

## Decision
We implement an automated, continuous SBOM and CBOM governance pipeline across both local development and GitHub Actions CI:

1. **Dual-Format SBOM Generation**:
   - Utilize Anchore/Syft to generate both CycloneDX JSON (`oss/sbom.cyclonedx.json`) and SPDX JSON (`oss/sbom.spdx.json`) to maximize ecosystem interoperability.

2. **Cryptographic Bill of Materials (CBOM) Generation**:
   - Integrate `cbomkit` (`cbomkit-action` / `cdxgen`) to inspect dependencies and extract structured cryptographic components into `oss/cbom.json`.

3. **Dual-Engine Semantic AST Cryptographic Analysis**:
   - Provide `scripts/scan_crypto_ast.py` to statically analyze Python and JavaScript/TypeScript source files, extracting cryptographic call-sites, hashing functions, and key exchanges, reconciling AST detections with the CBOM.

4. **PQC Readiness and Cryptographic Auditing**:
   - Provide `scripts/analyze_cbom.py` to categorize cryptographic assets into quantum-safe (e.g., ML-DSA, ML-KEM) vs. quantum-vulnerable (e.g., RSA, ECDSA), compute readiness metrics, and generate CI step summaries and reports.

5. **Automated Verification Test Harness**:
   - Implement `scripts/test_boms.sh` to validate the structural integrity, non-emptiness, and schema conformance of generated SBOMs and CBOMs in CI before artifact retention.

6. **Continuous CI Workflow**:
   - Standardize `.github/workflows/sbom-cbom.yml` running on Node 24 actions, executing the dual-generation, AST scans, test harness verification, publishing audit reports to `docs/security/CRYPTOGRAPHIC_AUDIT.md`, and retaining artifacts in `oss/` for 90 days.

7. **Developer Tooling**:
   - Provide `scripts/generate_boms.sh` for local on-demand generation and testing.

## Consequences
- **Positive**: Complete automated visibility into all third-party dependencies and cryptographic primitives utilized in the PKI demonstration.
- **Positive**: Direct alignment with ADR-006 and ADR-007 by providing quantifiable tracking of quantum-safe migration progress.
- **Positive**: Early detection in pull requests of deprecated cryptographic algorithms or unvetted cryptographic dependencies.
- **Neutral**: Added CI workflow step duration (~1-2 minutes) and local dependency prerequisites for full local scan execution (Syft, cbomkit/cdxgen, Python 3).

## Alternatives Considered
- *Status Quo / Container Vulnerability Scans Only*: Scans container layers for known CVEs but provides zero insight into internal cryptographic algorithms, key lengths, or quantum vulnerability status.
- *Manual Cryptographic Auditing*: Documenting algorithms in static markdown files quickly drifts out of sync with code changes and dependency updates.
- *Single-Format SBOM (SPDX Only or CycloneDX Only)*: SPDX is widely adopted for licensing, while CycloneDX has superior native support for CBOM extensions; adopting a dual-format pipeline satisfies both requirements without compromising fidelity.
