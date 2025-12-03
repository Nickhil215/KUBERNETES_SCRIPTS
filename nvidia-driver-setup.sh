#!/bin/bash

set -e

echo "🔍 Detecting NVIDIA GPU..."
GPU_INFO=$(lspci | grep -i nvidia || true)S

if [[ -z "$GPU_INFO" ]]; then
    echo "❌ No NVIDIA GPU detected. Exiting."
    exit 1
fi

echo "✅ NVIDIA GPU detected: $GPU_INFO"

# Default safe version
DRIVER_VERSION="550-server"

# GPU-specific overrides
if echo "$GPU_INFO" | grep -iqE "H100|H800"; then
    DRIVER_VERSION="550-server"
elif echo "$GPU_INFO" | grep -iqE "H200|2335"; then
    # 2335 = H200 PCI ID
    DRIVER_VERSION="550-server"
elif echo "$GPU_INFO" | grep -iq "A16"; then
    DRIVER_VERSION="535-server"
elif echo "$GPU_INFO" | grep -iq "L40"; then
    DRIVER_VERSION="550-server"
elif echo "$GPU_INFO" | grep -iq "L4"; then
    DRIVER_VERSION="550-server"
fi

echo "📦 Installing NVIDIA driver: nvidia-driver-$DRIVER_VERSION"

sudo apt update
sudo apt install -y "nvidia-driver-$DRIVER_VERSION"

echo "⏳ Checking installation..."
if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "⚠️ nvidia-smi will work after reboot."
else
    echo "✅ nvidia-smi is available now."
fi

# Optional CUDA
read -p "💡 Install CUDA Toolkit too? [y/N]: " install_cuda
if [[ "$install_cuda" =~ ^[Yy]$ ]]; then
    echo "📦 Installing CUDA toolkit..."
    sudo apt install -y nvidia-cuda-toolkit
    echo "✅ CUDA toolkit installed."
fi

echo "🔁 Rebooting in 10 seconds. Press Ctrl+C to cancel."
sleep 10
sudo reboot
