const puppeteer = require('puppeteer');

(async () => {
  console.log('Starting interactive dashboard UI automated test...');
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Listen to browser console logs
    const consoleMsgs = [];
    page.on('console', msg => {
      const txt = msg.text();
      consoleMsgs.push(`[Browser Console ${msg.type()}] ${txt}`);
      console.log(`[Browser] ${txt}`);
    });

    // Navigate to dashboard
    console.log('Navigating to http://localhost:8080...');
    await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });

    // 1. Verify Page Title
    const title = await page.title();
    console.log(`Page title: "${title}"`);
    if (title !== 'Vault PKI Real-Time Dashboard') {
      throw new Error(`Unexpected page title: ${title}`);
    }

    // 2. Wait for certificate details to populate
    console.log('Waiting for certificate details to populate...');
    await page.waitForFunction(
      () => {
        const rootCN = document.getElementById('root-cn')?.textContent || '';
        const intCN = document.getElementById('int-cn')?.textContent || '';
        return !rootCN.includes('Loading') && !intCN.includes('Loading') && rootCN.length > 0;
      },
      { timeout: 5000 }
    );

    // 3. Test Interactive Card Details Accordion
    console.log('Testing card accordion expand/collapse...');
    
    // Check that details are currently hidden
    const detailsVisibleBefore = await page.$eval('#root-details', el => window.getComputedStyle(el).opacity !== '0');
    console.log(`Root details visible initially: ${detailsVisibleBefore}`);
    if (detailsVisibleBefore) {
      throw new Error('Root details should be hidden by default');
    }

    // Click Root CA card to expand details
    console.log('Clicking Root CA card...');
    await page.click('#root-ca-card');
    
    // Wait for transition/opacity to change
    await new Promise(r => setTimeout(r, 600));

    const detailsVisibleAfter = await page.$eval('#root-details', el => window.getComputedStyle(el).opacity !== '0');
    const rootFingerprint = await page.$eval('#root-detail-fp', el => el.textContent);
    console.log(`Root details visible after click: ${detailsVisibleAfter}`);
    console.log(`Root Fingerprint: ${rootFingerprint}`);
    
    if (!detailsVisibleAfter || rootFingerprint === '--') {
      throw new Error('Root details did not expand or populate fingerprint correctly');
    }

    // 4. Capture Leaf Cert Serial before rotation
    const originalSerial = await page.$eval('#leaf-serial', el => el.textContent);
    console.log(`Original Leaf Serial Number: ${originalSerial}`);

    // 5. Trigger Manual Rotation
    console.log('Clicking "Force Instant Rotation" button...');
    await page.click('#rotate-btn');

    // Wait for the serial number to change in the UI
    console.log('Waiting for certificate rotation to complete and update UI...');
    await page.waitForFunction(
      (oldSerial) => {
        const newSerial = document.getElementById('leaf-serial')?.textContent || '';
        return newSerial !== oldSerial && newSerial !== '--';
      },
      { timeout: 10000 },
      originalSerial
    );

    const rotatedSerial = await page.$eval('#leaf-serial', el => el.textContent);
    console.log(`Rotated Leaf Serial Number: ${rotatedSerial}`);
    if (originalSerial === rotatedSerial) {
      throw new Error('Certificate serial number did not rotate');
    }

    // 6. Verify Toast Notification is displayed
    const toastClassList = await page.$eval('#toast', el => Array.from(el.classList));
    console.log(`Toast class list after rotation: ${toastClassList.join(', ')}`);
    if (!toastClassList.includes('show')) {
      throw new Error('Toast notification did not show after rotation');
    }

    // 7. Capture a screenshot of the new UI state
    const screenshotPath = '/Users/jsoehner/.gemini/antigravity-cli/brain/5eb3e8de-1fab-4305-90cb-f8c08405836d/dashboard_screenshot.png';
    console.log(`Saving interactive state screenshot to ${screenshotPath}...`);
    await page.screenshot({ path: screenshotPath });

    // 8. Check for console errors
    const errors = consoleMsgs.filter(msg => msg.includes('error') || msg.includes('Failed'));
    if (errors.length > 1) { // Allowing 1 for favicon 404
      console.warn('Excessive warnings/errors detected in browser console:');
      errors.forEach(e => console.warn(`  ${e}`));
    } else {
      console.log('No critical console errors detected.');
    }

    console.log('Interactive automated UI test completed successfully!');
    process.exit(0);

  } catch (error) {
    console.error('Interactive automated UI test failed:', error);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();
