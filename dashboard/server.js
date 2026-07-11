const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const CERT_PATH = process.env.CERT_PATH || path.join(__dirname, 'certs', 'test.example.com.crt');

let sseClients = [];
let rotationHistory = [];
let lastSerial = null;

// Helper to parse certificates from PEM bundle
function getCertDetails() {
  try {
    if (!fs.existsSync(CERT_PATH)) {
      return null;
    }
    const content = fs.readFileSync(CERT_PATH, 'utf8');
    const pemBlocks = content
      .split('-----END CERTIFICATE-----')
      .map(x => x.trim() + '\n-----END CERTIFICATE-----')
      .filter(x => x.includes('BEGIN CERTIFICATE'));

    const parsedCerts = pemBlocks.map((pem, index) => {
      try {
        const cert = new crypto.X509Certificate(pem);
        return {
          type: index === 0 ? 'Leaf (NGINX)' : index === 1 ? 'Intermediate CA' : 'Root CA',
          subject: cert.subject,
          issuer: cert.issuer,
          serialNumber: cert.serialNumber,
          validFrom: cert.validFrom,
          validTo: cert.validTo,
          fingerprint: cert.fingerprint,
        };
      } catch (e) {
        return null;
      }
    }).filter(Boolean);

    return parsedCerts;
  } catch (error) {
    console.error('Error parsing certificates:', error);
    return null;
  }
}

// Initialize history
function initTracker() {
  const certs = getCertDetails();
  if (certs && certs.length > 0) {
    lastSerial = certs[0].serialNumber;
    rotationHistory.push({
      timestamp: new Date().toISOString(),
      serialNumber: lastSerial,
      validFrom: certs[0].validFrom,
      validTo: certs[0].validTo,
    });
  }
}

// Watch cert file for changes
fs.watch(path.dirname(CERT_PATH), (eventType, filename) => {
  if (filename === path.basename(CERT_PATH)) {
    // Small delay to ensure write is complete
    setTimeout(() => {
      const certs = getCertDetails();
      if (certs && certs.length > 0) {
        const leaf = certs[0];
        if (leaf.serialNumber !== lastSerial) {
          lastSerial = leaf.serialNumber;
          const entry = {
            timestamp: new Date().toISOString(),
            serialNumber: lastSerial,
            validFrom: leaf.validFrom,
            validTo: leaf.validTo,
          };
          rotationHistory.unshift(entry);
          if (rotationHistory.length > 50) {
            rotationHistory.pop();
          }
          
          // Broadcast to SSE clients
          const data = JSON.stringify({ type: 'rotation', certs, history: rotationHistory });
          sseClients.forEach(client => {
            client.write(`data: ${data}\n\n`);
          });
          console.log(`[Dashboard Backend] Certificate rotated! New Serial: ${lastSerial}`);
        }
      }
    }, 100);
  }
});

// Create HTTP server
const server = http.createServer((req, res) => {
  // CORS Headers
  const origin = req.headers.origin;
  if (origin && (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:') || origin === 'http://localhost' || origin === 'http://127.0.0.1')) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // API Rotate Endpoint
  if (req.url === '/api/rotate' && req.method === 'POST') {
    const options = {
      socketPath: '/var/run/docker.sock',
      path: '/v1.41/containers/vault-agent/restart',
      method: 'POST'
    };

    const dockerReq = http.request(options, (dockerRes) => {
      let data = '';
      dockerRes.on('data', chunk => data += chunk);
      dockerRes.on('end', () => {
        if (dockerRes.statusCode >= 200 && dockerRes.statusCode < 300) {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: true, message: 'Vault Agent restarted successfully' }));
        } else {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, error: `Docker API returned status: ${dockerRes.statusCode}`, details: data }));
        }
      });
    });

    dockerReq.on('error', (err) => {
      console.error('Docker socket connection error:', err);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: err.message }));
    });

    dockerReq.end();
    return;
  }

  // API Status Endpoint
  if (req.url === '/api/status') {
    const certs = getCertDetails();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      certs: certs || [],
      history: rotationHistory,
      systemTime: new Date().toISOString()
    }));
    return;
  }

  // SSE Stream Endpoint
  if (req.url === '/api/stream') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    });
    res.write('\n');
    sseClients.push(res);

    req.on('close', () => {
      sseClients = sseClients.filter(c => c !== res);
    });
    return;
  }

  // Serve Static Frontend Files
  const safeBase = path.resolve(__dirname, 'public');
  const targetPath = req.url === '/' ? 'index.html' : (req.url.startsWith('/') ? req.url.substring(1) : req.url);
  const filePath = path.resolve(safeBase, targetPath);
  // Prevent directory traversal
  if (!filePath.startsWith(safeBase)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  const ext = path.extname(filePath);
  let contentType = 'text/html';
  if (ext === '.css') contentType = 'text/css';
  else if (ext === '.js') contentType = 'application/javascript';
  else if (ext === '.json') contentType = 'application/json';
  else if (ext === '.svg') contentType = 'image/svg+xml';
  else if (ext === '.png') contentType = 'image/png';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Internal Server Error');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

initTracker();
server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Dashboard Backend] Running on http://0.0.0.0:${PORT}`);
  console.log(`[Dashboard Backend] Monitoring path: ${CERT_PATH}`);
});
