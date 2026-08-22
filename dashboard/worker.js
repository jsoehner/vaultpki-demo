const http = require('http');
const fs = require('fs');
const path = require('path');

const SIGNAL_FILE = path.join(__dirname, 'signal.txt');

// Worker Logic: Listen for signal file
fs.watchFile(SIGNAL_FILE, (curr, prev) => {
  if (curr.mtime !== prev.mtime) {
    console.log('[Worker] Signal received, restarting vault-agent...');
    
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
          console.log('[Worker] Vault Agent restarted successfully');
          // Clear signal file
          fs.writeFileSync(SIGNAL_FILE, '');
        } else {
          console.warn(`[Worker] Docker API returned status ${dockerRes.statusCode}`);
        }
      });
    });

    dockerReq.on('error', (err) => {
      console.error('[Worker] Docker socket connection failed:', err.message);
      fs.writeFileSync(SIGNAL_FILE, '');
    });

    dockerReq.end();
  }
});

console.log('[Worker] Started watching for signals...');
