# HashiCorp Vault PKI Demonstration

## The Problem
Managing TLS/SSL certificates for internal infrastructure (microservices, internal web apps, databases) is notoriously difficult. Common anti-patterns include:
1. **Self-signed certificates everywhere**: Hard to manage trust across systems.
2. **Long-lived certificates**: Increases the risk of compromise if a private key is leaked, and manual rotation is often forgotten until an outage occurs.
3. **Manual OpenSSL commands**: Requires administrators to manually generate CSRs, sign them, and distribute them securely, which does not scale.

## The Solution
This demonstration sets up a robust, scalable **Public Key Infrastructure (PKI)** using **HashiCorp Vault**. Vault acts as your own private Certificate Authority (CA), enabling automated, API-driven generation of short-lived certificates.

### What this Demo Does
Using `docker-compose` and a setup script (`setup-pki.sh`), this project spins up a local Vault instance and automatically configures a secure, tiered PKI system:

1. **Root CA Initialization**: Generates an internal Root Certificate Authority. In a production environment, this root CA is typically kept completely offline.
2. **Intermediate CA Provisioning**: Generates an Intermediate Certificate Authority signed by the Root CA. This is the active CA used to issue actual endpoint certificates.
3. **Role Configuration**: Defines a strict role (`web-server`) that dictates the rules for issued certificates (e.g., restricting issuance to the `example.com` domain and its subdomains, with maximum TTLs).

By providing an API to issue certificates dynamically, you can easily integrate Vault into your CI/CD pipelines, configuration management tools (like Ansible, Chef, Terraform), or directly into your application startup scripts.

## How to Run

1. Start the Vault server:
   ```bash
   docker-compose up -d
   ```

2. Run the automated setup script to initialize, unseal, and configure the PKI structure:
   ```bash
   ./setup-pki.sh
   ```

3. Once setup is complete, you can issue a certificate for your domain using the Vault API/CLI!
