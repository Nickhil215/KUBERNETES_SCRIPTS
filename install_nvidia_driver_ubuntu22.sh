#!/bin/bash

set -e

echo "🔍 Detecting NVIDIA GPU..."
GPU_INFO=$(lspci | grep -i nvidia || true)

if [[ -z "$GPU_INFO" ]]; then
    echo "❌ No NVIDIA GPU detected. Exiting."
    exit 1
fi

echo "✅ NVIDIA GPU detected: $GPU_INFO"

# Choose driver version based on best general compatibility for data center GPUs on Ubuntu 22.04
# You can change this default to suit specific GPU models
DRIVER_VERSION="550-server"

# Optional: Match specific models to safer versions
if echo "$GPU_INFO" | grep -iq "H100"; then
    DRIVER_VERSION="550-server"
elif echo "$GPU_INFO" | grep -iq "A16"; then
    DRIVER_VERSION="535-server"
elif echo "$GPU_INFO" | grep -iq "L40"; then
    DRIVER_VERSION="550-server"
fi

echo "📦 Installing NVIDIA driver and utils: $DRIVER_VERSION"

sudo apt update
sudo apt install -y "nvidia-driver-$DRIVER_VERSION" "nvidia-utils-$DRIVER_VERSION"

echo "✅ Driver installation complete."

# Optional: Install CUDA toolkit (remove if not needed)
read -p "💡 Do you want to install CUDA Toolkit as well? [y/N]: " install_cuda
if [[ "$install_cuda" =~ ^[Yy]$ ]]; then
    echo "📦 Installing CUDA toolkit..."
    sudo apt install -y nvidia-cuda-toolkit
    echo "✅ CUDA toolkit installed."
fi

echo "🔁 Rebooting in 10 seconds to activate the driver. Press Ctrl+C to cancel."
sleep 10
sudo reboot
