#!/bin/bash

set -e

echo "===== Step 1: Checking for NVIDIA GPU ====="
if ! command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi not found. Ensure NVIDIA drivers are installed."
    exit 1
fi

nvidia-smi

echo "===== Step 2: Disabling Swap ====="
swapoff -a
sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab
echo "Swap disabled and /etc/fstab updated."

echo "===== Step 3: Installing NVIDIA Container Toolkit ====="
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit

echo "===== Verifying NVIDIA Container CLI ====="
nvidia-container-cli --version

echo "===== Step 4: Checking and Installing Helm if Not Present ====="
if ! command -v helm &> /dev/null; then
    echo "Helm not found, installing using get_helm.sh..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
else
    echo "Helm is already installed."
fi

echo "===== Step 5: Adding NVIDIA Helm Repo and Updating ====="
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update

echo "===== Step 6: Deploying NVIDIA GPU Operator via Helm ====="
helm install --wait --generate-name nvidia/gpu-operator

echo "===== Step 7: Verifying NVIDIA Pods ====="
kubectl get pods -A | grep nvidia || echo "No NVIDIA pods found yet — they might still be initializing."

echo "🎉 GPU setup completed successfully!"

