#!/bin/bash

set -e

echo "🟡 Updating package lists..."
sudo apt update

echo "🔵 Installing NVIDIA Server Driver (550) and utilities for H100..."
sudo apt install -y nvidia-driver-550-server nvidia-utils-550-server

echo "✅ Installation complete. Reboot required."

echo "🔁 Rebooting in 10 seconds. Press Ctrl+C to cancel."
sleep 10
sudo reboot
