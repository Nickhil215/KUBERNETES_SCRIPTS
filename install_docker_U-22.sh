#!/bin/bash
set -e

echo "=== Updating system packages ==="
sudo apt update -y
sudo apt upgrade -y

echo "=== Removing old Docker versions if any ==="
sudo apt remove -y docker docker-engine docker.io containerd runc || true

echo "=== Installing required dependencies ==="
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

echo "=== Adding Docker’s official GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "=== Setting up Docker repository ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Updating package index again ==="
sudo apt update -y

echo "=== Installing Docker Engine, CLI, Buildx, and Compose ==="
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Enabling and starting Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Adding current user to docker group ==="
sudo usermod -aG docker $USER

echo "=== Installation complete! ==="
echo ">>> You may need to log out and back in for group changes to take effect."
echo ">>> Verify Docker by running: docker run hello-world"
