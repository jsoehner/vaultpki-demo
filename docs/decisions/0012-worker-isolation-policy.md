# ADR-012: Worker Isolation Policy

## Status
Accepted

## Date
2026-09-05

## Context
The project requires the ability to perform privileged operations, such as restarting the `vault-agent` container or interacting with the Docker socket. Directly exposing the Docker socket (`/var/run/docker.sock`) to the main application or the dashboard poses a significant security risk, as it provides full root access to the host.

## Decision
Implement a "Worker Pattern" for privileged operations.

1.  **Isolation**: The main application and the dashboard run in restricted containers with no direct access to the Docker socket.
2.  **Worker Service**: A dedicated, minimal worker container (the "Worker") is the only component with access to the Docker socket.
3.  **Signaling**: The application communicates with the Worker via a secure local signal file (`signal.txt`).
4.  **Restricted Scope**: The Worker's only capability is to execute a pre-defined set of commands (e.g., container restart) in response to the signal.

## Security Improvements
- **Reduced Attack Surface**: Even if the dashboard or main app is compromised, the attacker cannot gain host-level access through the Docker socket.
- **Least Privilege**: The Worker only has the permissions necessary to perform specific, hardcoded actions.
- **Auditability**: Signal file writes provide a clear audit trail of requests for privileged actions.

## Alternatives Considered
### Direct Socket Mounting
- **Pros**: Simpler implementation.
- **Cons**: Massive security risk; provides full host control to any container with the mount.

### API-based Remote Execution
- **Pros**: More flexible than a signal file.
- **Cons**: Requires a full API server with authentication, adding complexity and a new attack surface.

## Consequences
- **Security**: Significantly hardens the system against container escape and privilege escalation.
- **Maintenance**: Requires managing a separate worker container and coordinating signal file permissions.
- **Scalability**: The signal-file-based approach is local to a single host but can be adapted to a message queue (e.g., Redis) for distributed environments.
