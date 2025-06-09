#!/bin/bash

# install-vault.sh
# Installs HashiCorp Vault on Ubuntu using official APT repo

set -e

echo "🔄 Updating packages..."
sudo apt update -y && sudo apt install -y curl unzip gnupg lsb-release

echo "📥 Adding HashiCorp GPG key..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "📦 Adding HashiCorp APT repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

echo "🔄 Updating APT and installing Vault..."
sudo apt update -y && sudo apt install -y vault

echo "✅ Vault installation complete!"
vault --version
