import unittest
from unittest.mock import patch, MagicMock
import subprocess
import os
import sys

class ScriptResult:
    def __init__(self, returncode, stdout):
        self.returncode = returncode
        self.stdout = stdout

def run_vault_init_step(keys_file='config/vault-keys.txt'):
    status_proc = subprocess.run(['vault', 'status', '-format=json'], capture_output=True, text=True)
    stdout = status_proc.stdout or ""
    output = []
    if '"initialized": true' in stdout:
        output.append("Vault is already initialized.")
        if '"sealed": true' in stdout:
            output.append("Vault is sealed. Attempting to unseal...")
            unseal_key = os.environ.get('UNSEAL_KEY', '')
            if not unseal_key and os.path.exists(keys_file):
                with open(keys_file) as f:
                    for line in f:
                        if line.startswith('UNSEAL_KEY='):
                            unseal_key = line.split('=', 1)[1].strip()
            if unseal_key:
                subprocess.run(['vault', 'operator', 'unseal', unseal_key], capture_output=True, text=True)
                output.append("Vault unsealed successfully.")
                return ScriptResult(0, "\n".join(output))
            else:
                output.append("Error: UNSEAL_KEY not found in environment or files.")
                return ScriptResult(1, "\n".join(output))
        else:
            output.append("Vault is already unsealed.")
            return ScriptResult(0, "\n".join(output))
    else:
        output.append("Initializing Vault...")
        subprocess.run(['vault', 'operator', 'init', '-key-shares=1', '-key-threshold=1'], capture_output=True, text=True)
        return ScriptResult(0, "\n".join(output))

class TestVaultInit(unittest.TestCase):
    def test_vault_init_already_initialized(self):
        # Mock vault status to return initialized: true, sealed: false
        with patch('subprocess.run') as mocked_run:
            mocked_run.return_value = MagicMock(returncode=0, stdout='{"initialized": true, "sealed": false}')
            
            result = run_vault_init_step()
            
            self.assertEqual(result.returncode, 0)
            self.assertIn("Vault is already initialized.", result.stdout)

    def test_vault_init_unseal_key_found(self):
        # Mock vault status to return sealed: true
        # Mock vault operator unseal to succeed
        with patch('subprocess.run') as mocked_run:
            mocked_run.side_effect = [
                MagicMock(returncode=0, stdout='{"initialized": true, "sealed": true}'),
                MagicMock(returncode=0, stdout='Unseal Key 1: secret_key')
            ]
            
            # Create a mock keys file
            with open('config/vault-keys.txt', 'w') as f:
                f.write('UNSEAL_KEY=secret_key')

            result = run_vault_init_step()
            
            if os.path.exists('config/vault-keys.txt'):
                os.remove('config/vault-keys.txt')
            
            self.assertEqual(result.returncode, 0)
            self.assertIn("Vault unsealed successfully.", result.stdout)

    def test_vault_init_initialization_flow(self):
        # Mock vault status to return initialized: false, sealed: false
        # Mock vault operator init to return a token
        with patch('subprocess.run') as mocked_run:
            mocked_run.side_effect = [
                MagicMock(returncode=0, stdout='{"initialized": false, "sealed": false}'),
                MagicMock(returncode=0, stdout='Initial Root Token: root_token\nUnseal Key 1: unseal_key')
            ]
            
            # Ensure keys file doesn't exist
            if os.path.exists('config/vault-keys.txt'):
                os.remove('config/vault-keys.txt')

            result = run_vault_init_step()
            
            self.assertEqual(result.returncode, 0)
            self.assertIn("Initializing Vault...", result.stdout)

if __name__ == '__main__':
    unittest.main()
