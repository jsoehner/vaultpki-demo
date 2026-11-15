import os
import shutil
import subprocess
import pytest

SCRIPTS = [
    "run_demo.ps1",
    "watch-rotation.ps1",
    "check-cert.ps1",
    "setup-pki.ps1",
]

def test_powershell_scripts_exist():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    for script_name in SCRIPTS:
        script_path = os.path.join(root_dir, script_name)
        assert os.path.isfile(script_path), f"Expected script {script_name} to exist at {script_path}"

def test_powershell_scripts_syntax():
    ps_executable = shutil.which("pwsh") or shutil.which("powershell")
    if not ps_executable:
        pytest.skip("PowerShell executable not found on host.")

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    for script_name in SCRIPTS:
        script_path = os.path.join(root_dir, script_name)
        # Use AST Parser to validate syntax without executing
        cmd = [
            ps_executable,
            "-NoProfile",
            "-Command",
            f"""
            $errors = $null
            $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseFile('{script_path}', [ref]$tokens, [ref]$errors) | Out-Null
            if ($errors.Count -gt 0) {{
                $msg = ($errors | ForEach-Object {{ $_.Message }}) -join '; '
                Write-Error "Syntax errors in {script_name}: $msg"
                exit 1
            }}
            """
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, f"Syntax validation failed for {script_name}:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"

def test_run_demo_ps1_content():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    script_path = os.path.join(root_dir, "run_demo.ps1")
    with open(script_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Verify key orchestration elements
    assert "docker compose" in content
    assert "vault-init" in content
    assert "MaxWaitSeconds" in content
    assert "Invoke-Compose down -v" in content
    assert "Invoke-Compose up -d" in content
    assert "http://127.0.0.1:8080" in content
    assert "https://127.0.0.1:8443" in content
