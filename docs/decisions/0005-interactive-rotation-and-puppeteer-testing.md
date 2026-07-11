# ADR-005: Interactive Certificate Rotation and Puppeteer UI Testing

## Status
Accepted

## Date
2026-07-11

## Context
To make the Vault PKI demo more visually engaging and interactive, we needed a way to:
1. Instantly trigger a manual certificate rotation from the browser UI (rather than waiting for the short TTL to expire naturally).
2. Inspect the detailed certificate metadata (Validity bounds, full issuer subject, SHA-1 fingerprint) directly from the UI without cluttering the main dashboard hierarchy.
3. Verify that these new UI features and the underlying Server-Sent Events (SSE) stream reload correctly using automated tests.

## Decision
1. **Docker Socket Mount**: Mount `/var/run/docker.sock` from the host into the `dashboard` container. Add a POST `/api/rotate` route to the Node.js server that writes to the socket path (`/var/run/docker.sock`) requesting a restart of the `vault-agent` container.
2. **Interactive UI Elements**:
   - **Trigger Button**: Add a "⚡ Force Instant Rotation" button that initiates the POST request, displays a loading spinner, and locks state until the rotation completes.
   - **Expandable Accordion Drawer**: Clicking on Root/Int/Leaf certificate cards triggers a CSS-animated transition displaying structural fields.
   - **Toast Notifications**: An animated, glowing toast slides in when the SSE stream broadcasts a new certificate rotation event.
3. **Puppeteer UI Integration Testing**: Standardize on **Puppeteer** for automated browser testing. Write a test suite `dashboard_test.js` that navigates the headless browser, interacts with the cards, simulates rotation clicks, checks console logs, and saves visual screenshots.

## Alternatives Considered
### SSH/Exec shell runner inside container
- **Pros**: Doesn't require mounting the docker socket.
- **Cons**: Requires configuring keys and credentials inside the node container, exposing ssh keys, or bundling docker cli. Extremely insecure.

### Manual Polling Tests
- **Pros**: Simple to verify without tools.
- **Cons**: High latency, error-prone, doesn't verify the CSS transitions, dynamic elements, or actual DOM content.

## Consequences
- The dashboard is highly interactive and allows instant, visual verification of Vault/NGINX PKI rotations.
- Puppeteer introduces a node dependency, but guarantees browser-runtime validation.
- Mounting the docker socket grants the dashboard container root-level Docker access. This is acceptable for local development/demonstration, but security warnings are documented.
