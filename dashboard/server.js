const http = require('http');
const fs = require('fs');
const path = require('path');
const { getCertDetails } = require('./lib/cert_manager');

const PORT = process.env.PORT || 8080;
const CERT_PATH = process.env.CERT_PATH || path.join(__dirname, 'certs', 'test.example.com.crt');
const SIGNAL_FILE = path.join(__dirname, 'signal.txt');
const API_KEY = process.env.DASHBOARD_API_KEY || 'default_secret_key_change_me';

let rotationHistory = [];
let lastSerial = null;
let sseClients = [];

function isAuthorized(req) {
  if (!API_KEY) return true;
  const authHeader = req.headers['authorization'];
  const xApiKey = req.headers['x-api-key'];
  if (authHeader && authHeader.startsWith('Bearer ') && authHeader.substring(7) === API_KEY) {
    return true;
  }
  if (xApiKey && xApiKey === API_KEY) {
    return true;
  }
  return false;
}

// Initialize history
function initTracker() {
  const certs = getCertDetails(CERT_PATH);
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
const certDir = path.dirname(CERT_PATH);
if (!fs.existsSync(certDir)) {
  fs.mkdirSync(certDir, { recursive: true });
}

fs.watch(certDir, (eventType, filename) => {
  if (filename === path.basename(CERT_PATH)) {
    setTimeout(() => {
      const certs = getCertDetails(CERT_PATH);
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
  const origin = req.headers.origin;
  if (origin && (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:') || origin === 'http://localhost' || origin === 'http://127.0.0.1')) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-KEY');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // API Rotate Endpoint - signals the worker
  if (req.url === '/api/rotate' && req.method === 'POST') {
    if (!isAuthorized(req)) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'Unauthorized' }));
      return;
    }
    try {
      fs.writeFileSync(SIGNAL_FILE, 'RESTART');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'Restart signal sent to worker' }));
    } catch (err) {
      console.error('[Dashboard Backend] Failed to write signal file:', err);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'Failed to signal worker' }));
    }
    return;
  }

  // API Status Endpoint
  if (req.url === '/api/status') {
    if (!isAuthorized(req)) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'Unauthorized' }));
      return;
    }
    const certs = getCertDetails(CERT_PATH);
    rotationHistory.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
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
