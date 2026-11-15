const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

/**
 * Parses certificates from a PEM bundle.
 * @param {string} certPath - Path to the certificate file.
 * @returns {Array<Object>} - Array of certificate objects.
 */
function getCertDetails(certPath, deps = {}) {
  const _fs = deps.fs || fs;
  const _crypto = deps.crypto || crypto;
  try {
    if (!_fs.existsSync(certPath)) {
      return null;
    }
    const content = _fs.readFileSync(certPath, 'utf8');
    const pemBlocks = content.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g);
    if (!pemBlocks) {
      return [];
    }

    return pemBlocks.map((pem, index) => {
      try {
        const cert = new _crypto.X509Certificate(pem);
        return {
          type: index === 0 ? 'Leaf (NGINX)' : index === 1 ? 'Intermediate CA' : 'Root CA',
          subject: cert.subject,
          issuer: cert.issuer,
          serialNumber: cert.serialNumber,
          validFrom: cert.validFrom,
          validTo: cert.validTo,
          fingerprint: cert.fingerprint,
          algorithm: cert.publicKey ? cert.publicKey.asymmetricKeyType : 'unknown'
        };
      } catch (e) {
        return null;
      }
    }).filter(Boolean);
  } catch (error) {
    return null;
  }
}

module.exports = { getCertDetails };
