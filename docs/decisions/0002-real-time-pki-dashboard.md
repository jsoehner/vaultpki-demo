# ADR-002: Real-time PKI and Certificate Rotation Dashboard

## Status
Accepted

## Date
2026-07-11

## Context
In a PKI setup with very short-lived certificates (e.g. 1-minute TTLs) and automated rotation, it is difficult for developers to observe and verify that rotation is happening correctly in real-time. Checking log outputs or manual openssl queries is cumbersome and lacks visual clarity for demonstrating trust chain propagation and automatic reload behaviors.

## Decision
Create a lightweight real-time Node.js dashboard application (under `dashboard/`) containing:
1. A backend server (`server.js`) that uses the standard Node.js `fs.watch` API to monitor updates to the leaf certificate file (`test.example.com.crt`).
2. An API endpoint (`/api/status`) returning parsed X509 certificate trust chain details (Root, Intermediate, Leaf) using Node's native `crypto.X509Certificate` class.
3. A Server-Sent Events (SSE) stream (`/api/stream`) to broadcast instant rotation notifications to connected browser clients.
4. A static frontend web interface utilizing modern CSS (gradients, custom progress indicators, log streaming) to visualize the countdown timer (TTL) and rotation history list.

This dashboard is run inside a lightweight container service `dashboard` in `docker-compose.yml`.

## Alternatives Considered
### Polling the Vault API from Frontend
- **Pros**: Direct integration with Vault.
- **Cons**: Requires exposing the Vault API to the host network / browser, bypassing Vault Agent caching, and complicating credential access.

### Static File Web Server with Client-side Polling
- **Pros**: Very simple.
- **Cons**: High latency, unnecessary I/O, poor developer experience due to lack of immediate feedback on rotation events.

## Consequences
- Developers get immediate visual feedback when Vault Agent rotates certificates and NGINX reloads them.
- Simple, secure architecture: Frontend communicates only with the local dashboard server, which reads certificates from a local mount.
