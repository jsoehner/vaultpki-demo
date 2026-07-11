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

// Expand/Collapse Details
function toggleDetails(id) {
  const details = document.getElementById(id);
  details.classList.toggle('expanded');
}

// Show toast notification
function showToast() {
  const toast = document.getElementById('toast');
  toast.classList.add('show');
  setTimeout(() => {
    toast.classList.remove('show');
  }, 4000);
}

// Force a manual certificate rotation
async function triggerRotation() {
  const btn = document.getElementById('rotate-btn');
  const spinner = document.getElementById('btn-spinner');
  const text = document.getElementById('btn-text');

  btn.disabled = true;
  spinner.style.display = 'inline-block';
  text.textContent = ' Rotating...';

  try {
    const res = await fetch('/api/rotate', { method: 'POST' });
    const data = await res.json();
    if (!data.success) {
      console.error('Rotation trigger failed:', data.error);
      alert('Rotation failed: ' + data.error);
      btn.disabled = false;
      spinner.style.display = 'none';
      text.textContent = '⚡ Force Instant Rotation';
    }
  } catch (err) {
    console.error('Error triggering rotation:', err);
    alert('Error connecting to backend: ' + err.message);
    btn.disabled = false;
    spinner.style.display = 'none';
    text.textContent = '⚡ Force Instant Rotation';
  }
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
    
    document.getElementById('root-detail-issuer').textContent = rootCA.issuer;
    document.getElementById('root-detail-from').textContent = formatDate(rootCA.validFrom);
    document.getElementById('root-detail-to').textContent = formatDate(rootCA.validTo);
    document.getElementById('root-detail-fp').textContent = rootCA.fingerprint;
  }

  // Intermediate CA Card
  if (intCA) {
    document.getElementById('int-cn').textContent = intCA.subject.replace('CN=', '');
    document.getElementById('int-serial').textContent = formatSerial(intCA.serialNumber);
    document.getElementById('int-serial').title = intCA.serialNumber;

    document.getElementById('int-detail-issuer').textContent = intCA.issuer;
    document.getElementById('int-detail-from').textContent = formatDate(intCA.validFrom);
    document.getElementById('int-detail-to').textContent = formatDate(intCA.validTo);
    document.getElementById('int-detail-fp').textContent = intCA.fingerprint;
  }

  // Leaf Cert Card
  if (leaf) {
    document.getElementById('leaf-cn').textContent = leaf.subject.replace('CN=', '');
    document.getElementById('leaf-serial').textContent = formatSerial(leaf.serialNumber);
    document.getElementById('leaf-serial').title = leaf.serialNumber;
    document.getElementById('leaf-issuer').textContent = leaf.issuer.replace('CN=', '');
    
    document.getElementById('valid-from').textContent = formatDate(leaf.validFrom);
    document.getElementById('valid-to').textContent = formatDate(leaf.validTo);

    document.getElementById('leaf-detail-from').textContent = formatDate(leaf.validFrom);
    document.getElementById('leaf-detail-to').textContent = formatDate(leaf.validTo);
    document.getElementById('leaf-detail-fp').textContent = leaf.fingerprint;

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
        showToast();

        // Visual feedback on rotate button loading reset
        const btn = document.getElementById('rotate-btn');
        const spinner = document.getElementById('btn-spinner');
        const text = document.getElementById('btn-text');
        btn.disabled = false;
        spinner.style.display = 'none';
        text.textContent = '⚡ Force Instant Rotation';
        
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
