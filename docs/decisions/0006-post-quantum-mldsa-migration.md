# ADR-006: Post-Quantum Cryptography Migration to ML-DSA Certificates

## Status
Accepted

## Date
2026-08-11

## Context
As quantum computing technology advances, classical asymmetric encryption and signature algorithms (such as RSA and ECDSA) are increasingly vulnerable to future cryptanalytic threats. To secure the Public Key Infrastructure (PKI) demonstration against future quantum capabilities, we need to transition the certificate authority (CA) hierarchy and end-entity (leaf) certificates to NIST-standardized Post-Quantum Cryptography (PQC).

The primary standards for post-quantum algorithms are defined by NIST:
1. **ML-DSA** (Module-Lattice-Based Digital Signature Algorithm - FIPS 204) for digital signatures and certificate trust chain signing.
2. **ML-KEM** (Module-Lattice-Based Key-Encapsulation Mechanism - FIPS 203) for post-quantum key exchange (TLS hybrid handshakes).

Since key exchange (ML-KEM) is not a signature algorithm, it cannot sign certificates. The certificate hierarchy must be signed using a signature algorithm like **ML-DSA**.

## Decision
1. **Configure Vault PKI with ML-DSA**:
   - Update both the automated initialization scripting (`config/vault-init.sh`) and the manual setup guide (`setup-pki.sh`) to request `ml-dsa-65` (Security Level 3) key types for the Root CA, Intermediate CA, and issuing PKI roles.
2. **Extend Dashboard Metadata**:
   - Update the Node.js backend parsing logic (`dashboard/server.js`) to read the public key structure (`cert.publicKey.asymmetricKeyType`) and bubble this algorithm value up to the status API.
   - Update the HTML frontend layout (`dashboard/public/index.html` and `dashboard/public/app.js`) to display an "Algorithm" badge for every certificate node in the trust hierarchy chain.
3. **PQC Testing Fallback**:
   - Update the mock certificate generation loop in the backend test suite to use OpenSSL 3.5+ native commands (`openssl genpkey -algorithm ML-DSA-65` and `openssl req -x509`) to generate valid post-quantum test certificates, ensuring that `npm test` remains passing in environments without a running Vault container.

## Consequences
- The trust chain is now secured using NIST FIPS 204-compliant Post-Quantum Cryptography.
- The UI exposes real-time verification of the active key algorithms (e.g. `ml-dsa-65`).
- The project demonstrates state-of-the-art crypto-agility by transitioning from classical RSA/ECDSA keying models to ML-DSA signatures.
