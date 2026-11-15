import { describe, it, expect, vi } from 'vitest';
import * as certManager from '../../dashboard/lib/cert_manager';

describe('certManager', () => {
  const mockCrypto = {
    X509Certificate: function() {
      return {
        subject: 'subject',
        issuer: 'issuer',
        serialNumber: '12345',
        validFrom: '2024-01-01',
        validTo: '2025-01-01',
        fingerprint: 'fingerprint',
        publicKey: { asymmetricKeyType: 'rsa' }
      };
    }
  };

  it('returns null if certificate path does not exist', () => {
    const mockFs = {
      existsSync: vi.fn().mockReturnValue(false),
      readFileSync: vi.fn()
    };
    expect(certManager.getCertDetails('non_existent_path_12345', { fs: mockFs })).toBeNull();
  });

  it('parses certificates correctly from a PEM bundle', () => {
    const mockFs = {
      existsSync: vi.fn().mockReturnValue(true),
      readFileSync: vi.fn().mockReturnValue(
        '-----BEGIN CERTIFICATE-----\nABC\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\nXYZ\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\nUVW\n-----END CERTIFICATE-----'
      )
    };

    const certs = certManager.getCertDetails('mock_path', { fs: mockFs, crypto: mockCrypto });
    expect(certs).toHaveLength(3);
    expect(certs[0].type).toBe('Leaf (NGINX)');
    expect(certs[1].type).toBe('Intermediate CA');
    expect(certs[2].type).toBe('Root CA');
    expect(certs[0].serialNumber).toBe('12345');
  });
});
