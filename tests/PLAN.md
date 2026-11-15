# Test Suite Plan

## Overview
The goal is to provide comprehensive test coverage for the Vault PKI demonstration, ensuring reliability of the automated certificate rotation, the monitoring dashboard, and the underlying cryptographic utilities.

## Test Suites

### 1. Unit Tests (`tests/unit/`)
- **Python Utility Tests**:
    - `hamming_distance.py`: Test various string inputs, edge cases (empty strings, different lengths), and expected distance calculations.
- **Dashboard Logic Tests**:
    - Certificate parsing logic.
    - Rotation history management.
    - SSE message formatting.

### 2. Integration Tests (`tests/integration/`)
- **Vault API Integration**:
    - Verify that the `vault-init.sh` script correctly sets up the PKI engine and roles.
    - Verify that the `vault-agent` successfully fetches new certificates and updates the local file.
- **Dashboard Backend**:
    - Verify that the `/api/rotate` endpoint correctly signals the worker.
    - Verify that the `/api/status` endpoint returns the correct history and current cert details.
    - Verify that the `/api/stream` endpoint correctly broadcasts events to multiple clients.
- **Worker Service**:
    - Verify the worker correctly interprets the signal file and executes the Docker restart command.

### 3. End-to-End (E2E) Tests (`tests/e2e/`)
- **Dashboard UI Flow**:
    - Verify the user can see the live trust chain.
    - Verify that clicking "Rotate" triggers a real rotation in Vault and updates the UI.
    - Verify that the SSE stream correctly shows rotation events.
- **Full Rotation Loop**:
    - Verify that a certificate nearing expiration is automatically rotated by the Vault Agent and reflected in the dashboard.

## Tools
- **Python**: `pytest`
- **JavaScript/TypeScript**: `vitest`
- **E2E**: `Playwright`
