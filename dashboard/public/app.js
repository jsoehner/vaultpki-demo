let certsData = [];
let rotationHistory = [];
let expirationTime = null;
let timerInterval = null;

// Progress circle configurations
const circle = document.getElementById('progress-circle');
const radius = circle.r.baseVal.value;
const circumference = radius * 2 * Math.PI;

circle.style.strokeDasharray = `${circumference} ${circumference}`;
circle.style.strokeDashoffset = `${circumference}`;

function setProgress(percent) {
  const offset = circumference - (percent / 100) * circumference;
  circle.style.strokeDashoffset = offset;
}

// Format date to local readable format
function formatDate(dateStr) {
  if (!dateStr) return '--';
  const d = new Date(dateStr);
  return d.toLocaleTimeString() + ' ' + d.toLocaleDateString();
}

// Shorten serial number
function formatSerial(serial) {
  if (!serial) return '--';
  return serial.substring(0, 8) + '...' + serial.substring(serial.length - 8);
}

// Render dynamic elements
function renderDashboard() {
  if (!certsData || certsData.length === 0) return;

  // Find certs
  const leaf = certsData.find(c => c.type === 'Leaf (NGINX)');
  const intCA = certsData.find(c => c.type === 'Intermediate CA');
  const rootCA = certsData.find(c => c.type === 'Root CA');

  // Root CA Card
  if (rootCA) {
    document.getElementById('root-cn').textContent = rootCA.subject.replace('CN=', '');
    document.getElementById('root-serial').textContent = formatSerial(rootCA.serialNumber);
    document.getElementById('root-serial').title = rootCA.serialNumber;
  }

  // Intermediate CA Card
  if (intCA) {
    document.getElementById('int-cn').textContent = intCA.subject.replace('CN=', '');
    document.getElementById('int-serial').textContent = formatSerial(intCA.serialNumber);
    document.getElementById('int-serial').title = intCA.serialNumber;
  }

  // Leaf Cert Card
  if (leaf) {
    document.getElementById('leaf-cn').textContent = leaf.subject.replace('CN=', '');
    document.getElementById('leaf-serial').textContent = formatSerial(leaf.serialNumber);
    document.getElementById('leaf-serial').title = leaf.serialNumber;
    document.getElementById('leaf-issuer').textContent = leaf.issuer.replace('CN=', '');
    
    document.getElementById('valid-from').textContent = formatDate(leaf.validFrom);
    document.getElementById('valid-to').textContent = formatDate(leaf.validTo);

    // Update Expiration Target
    expirationTime = new Date(leaf.validTo).getTime();
    startCountdown();
  }

  // Rotation Log History
  const logList = document.getElementById('log-list');
  const countSpan = document.getElementById('rotation-count');
  
  if (rotationHistory.length === 0) {
    logList.innerHTML = '<div class="log-placeholder">Waiting for rotation events...</div>';
    countSpan.textContent = '0 rotations tracked';
  } else {
    countSpan.textContent = `${rotationHistory.length} rotation${rotationHistory.length > 1 ? 's' : ''} tracked`;
    logList.innerHTML = rotationHistory.map(log => {
      const time = new Date(log.timestamp).toLocaleTimeString();
      return `
        <div class="log-item">
          <div class="log-left">
            <span class="log-icon-badge">ROTATE</span>
            <span class="log-time">${time}</span>
          </div>
          <div class="log-serial">Serial: ${formatSerial(log.serialNumber)}</div>
        </div>
      `;
    }).join('');
  }
}

// Countdown timer loop (updates every 100ms for smooth UI)
function startCountdown() {
  if (timerInterval) clearInterval(timerInterval);

  timerInterval = setInterval(() => {
    if (!expirationTime) return;

    const now = Date.now();
    const timeLeftMs = expirationTime - now;
    const timeLeftSec = Math.max(0, timeLeftMs / 1000);

    // Assume certificate TTL is 60 seconds (1 minute)
    const totalTTL = 60; 
    const percentage = Math.min(100, (timeLeftSec / totalTTL) * 100);

    // Update progress circle
    setProgress(percentage);

    // Update text
    const textVal = document.getElementById('countdown-val');
    if (timeLeftSec <= 0) {
      textVal.textContent = '0.00';
      textVal.style.color = 'var(--accent-red)';
      document.querySelector('.time-unit').textContent = 'ROTATING...';
    } else {
      textVal.textContent = timeLeftSec.toFixed(1);
      textVal.style.color = '';
      document.querySelector('.time-unit').textContent = 'sec remaining';
    }
  }, 100);
}

// Load initial status
async function loadStatus() {
  try {
    const res = await fetch('/api/status');
    const data = await res.json();
    certsData = data.certs;
    rotationHistory = data.history;
    renderDashboard();
    
    // Set status to active/connected
    document.querySelector('.status-indicator').classList.add('active');
    document.querySelector('.status-text').textContent = 'Connected to Live Stream';
  } catch (err) {
    console.error('Error loading initial status:', err);
    document.querySelector('.status-indicator').classList.remove('active');
    document.querySelector('.status-text').textContent = 'API Connection Error';
  }
}

// Subscribe to Live Events (SSE)
function connectSSE() {
  const eventSource = new EventSource('/api/stream');

  eventSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      if (data.type === 'rotation') {
        certsData = data.certs;
        rotationHistory = data.history;
        renderDashboard();
        
        // Brief visual flash on rotation
        const leafCard = document.getElementById('leaf-cert-card');
        leafCard.style.transform = 'scale(1.02)';
        leafCard.style.borderColor = 'var(--accent-green)';
        setTimeout(() => {
          leafCard.style.transform = '';
          leafCard.style.borderColor = '';
        }, 1000);
      }
    } catch (e) {
      console.error('Error parsing SSE event:', e);
    }
  };

  eventSource.onerror = (err) => {
    console.error('SSE connection failed. Retrying...', err);
    eventSource.close();
    setTimeout(connectSSE, 3000);
  };
}

// App Bootstrap
window.addEventListener('DOMContentLoaded', () => {
  loadStatus();
  connectSSE();
});
