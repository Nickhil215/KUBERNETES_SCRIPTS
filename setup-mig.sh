#!/bin/bash

set -e

MODE=$1

if [[ "$MODE" != "single" && "$MODE" != "mixed" ]]; then
  echo "Usage: sudo $0 [single|mixed]"
  exit 1
fi

GPU_ID=0  # change if you have multiple GPUs

echo "Checking if MIG mode is enabled..."
MIG_MODE=$(nvidia-smi -i $GPU_ID -q | grep "MIG Mode" | awk '{print $3}')

if [[ "$MIG_MODE" != "Enabled" ]]; then
  echo "Enabling MIG mode on GPU $GPU_ID..."
  sudo nvidia-smi -i $GPU_ID -mig 1
  echo "Reboot is recommended after enabling MIG mode."
fi

echo "Resetting MIG configuration on GPU $GPU_ID..."
sudo nvidia-smi -i $GPU_ID -mig-reset

sleep 3

if [[ "$MODE" == "single" ]]; then
  echo "Setting up SINGLE MIG mode: all 1g.10gb slices"
  # Example: create all slices as 1g.10gb
  sudo nvidia-smi mig -i $GPU_ID -cgi 19,19,19,19,19,19,19,19
elif [[ "$MODE" == "mixed" ]]; then
  echo "Setting up MIXED MIG mode: mix of 1g.10gb and 2g.20gb slices"
  # Example mixed config: 4 x 1g.10gb + 2 x 2g.20gb + 2 x 1g.10gb (adjust as needed)
  sudo nvidia-smi mig -i $GPU_ID -cgi 19,19,20,20,19,19,19,19
fi

echo "Applying MIG configuration..."
sudo nvidia-smi mig -i $GPU_ID -cci

echo "Waiting a few seconds for configuration to apply..."
sleep 5

echo "Current MIG devices:"
sudo nvidia-smi -i $GPU_ID -L

echo "Restarting NVIDIA device plugin DaemonSet in Kubernetes..."
kubectl -n gpu-operator rollout restart daemonset nvidia-device-plugin-daemonset

echo "Done."



# ========= HOW TO RUN ========
# sudo bash setup-mig.sh single
# # or
# sudo bash setup-mig.sh mixed
