# ADR-010: Cross-Platform Windows PowerShell Orchestration

## Status
Accepted

## Date
2026-11-15

## Context
The Vault PKI demonstration environment previously depended exclusively on Bash shell scripts (`run_demo.sh`, `watch-rotation.sh`, `check-cert.sh`, and `setup-pki.sh`) for stack lifecycle management, TLS certificate verification, and real-time rotation monitoring.

While effective on Linux and macOS, this introduced friction for developers operating on Windows workstations:
1. Windows developers required WSL2 or Git Bash just to trigger the demo, view container statuses, or run health checks.
2. Tooling dependencies such as `openssl s_client` and `jq` are not natively available in standard Windows Command Prompt or Windows PowerShell environments.
3. Automated integration and testing pipelines running on Windows runners could not trigger or validate the demo without non-standard shell emulation.
4. Git on Windows checks out shell scripts with CRLF line endings by default, which causes Linux container runtimes (like `vault-init.sh`) to crash with `set: line 2: illegal option -`.
5. Hardcoded internal trusted registry URLs (`oss.jsigroup.local:8080`) failed to launch when the registry did not host the required container images or was unreachable.

To make the demonstration accessible, ergonomic, and fully cross-platform, native Windows PowerShell support and robust self-healing orchestration are required.

## Decision
We implement first-class Windows PowerShell equivalents for all orchestrator and diagnostic workflows:

1. **`run_demo.ps1` (Unified Stack Orchestrator)**:
   - Detects the Docker runtime and dynamically resolves modern `docker compose` or legacy standalone `docker-compose`.
   - Cleans up existing containers and anonymous volumes via `down -v`.
   - Launches the stack in detached mode (`up -d`).
   - Polls the `vault-init` container status up to a configurable timeout (`-MaxWaitSeconds 30`).
   - Validates exit code parity and captures initialization logs if failure occurs.
   - Formats running container statuses and outputs interactive instructions for Web and CLI endpoints.

2. **`watch-rotation.ps1` & `check-cert.ps1` (Zero-Dependency TLS Inspection)**:
   - Utilizes .NET's native `System.Net.Sockets.TcpClient` and `System.Net.Security.SslStream` APIs.
   - Eliminates host-level dependencies on `openssl` binaries or external utilities on Windows.
   - Securely parses leaf certificate serial numbers, thumbprints, validity windows, and extensions via `System.Security.Cryptography.X509Certificates.X509Certificate2`.

3. **`setup-pki.ps1` (Self-Contained PKI Setup)**:
   - Implements native JSON parsing via PowerShell's built-in `ConvertFrom-Json`, eliminating the external `jq` dependency required by `setup-pki.sh`.
   - Implements the exact same cryptographic logic as `vault-init.sh` and `setup-pki.sh`, attempting post-quantum `ml-dsa-65` CA generation and falling back gracefully to classical `rsa` (4096-bit CA / 2048-bit issuing roles).

4. **Dynamic Registry Resolution with Upstream Fallback**:
   - Parameterized `docker-compose.yml` with `${REGISTRY_PREFIX:-}` across all services.
   - Configured `run_demo.ps1` and `run_demo.sh` to probe local cache and remote manifests for `oss.jsigroup.local:8080/`. If the trusted registry does not host the images, the orchestrators gracefully fall back to Docker Hub upstream images (`hashicorp/vault:latest`, `nginx:latest`, `node:alpine`).

5. **Cross-Platform Line Ending Enforcement**:
   - Added `.gitattributes` enforcing `eol=lf` for all `*.sh` scripts to guarantee Linux container execution reliability regardless of the host developer OS.

6. **Automated Testing & Documentation**:
   - Implements `tests/unit/test_powershell_scripts.py` to validate script existence, content constraints, and syntax integrity using PowerShell's Abstract Syntax Tree (`System.Management.Automation.Language.Parser`).
   - Updates `README.md` and `MEMORY.md` with dual-platform invocation instructions and gotchas.

## Consequences

### Positive
- **Native Windows Developer Experience**: Developers on Windows can clone the repository and run `.\run_demo.ps1` in any standard PowerShell console without installing WSL or Bash emulators.
- **Zero Third-Party Binary Dependencies**: PowerShell scripts leverage built-in .NET TLS/X.509 libraries and PowerShell JSON cmdlets, removing the need for `jq` and `openssl` on Windows.
- **Resilient Registry Resolution**: Demo works out-of-the-box whether running in an enterprise network with populated internal mirrors or on workstations relying on Docker Hub.
- **Continuous Quality Assurance**: Syntax validation is codified into the test harness (`npm run test:all` / `pytest tests/unit`), ensuring changes to PowerShell scripts are validated on all systems.

### Negative / Trade-offs
- **Maintenance Overhead**: Requires dual maintenance of shell scripts (`*.sh`) and PowerShell scripts (`*.ps1`) whenever container lifecycle flags or PKI configurations change.

### Mitigation
- Shared Docker Compose configuration (`docker-compose.yml`) and containerized initialization (`config/vault-init.sh`) remain the single source of truth for the runtime stack; host scripts serve solely as thin orchestrators and monitors.
