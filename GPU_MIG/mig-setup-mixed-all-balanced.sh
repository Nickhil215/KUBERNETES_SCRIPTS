#!/bin/bash

# mig-setup-mixed.sh
# Setup NVIDIA GPU Operator with MIG Mixed Strategy on Kubernetes

set -e

NAMESPACE="gpu-operator"
HELM_RELEASE_NAME="gpu-operator"
GPU_OPERATOR_VERSION="v25.3.0"
NODE_NAME="$1"
MIG_PROFILE="$2"
GPU_OPERATOR_CHART="nvidia/gpu-operator"

if [ -z "$NODE_NAME" ] || [ -z "$MIG_PROFILE" ]; then
  echo "Usage: $0 <node-name> <mig-profile>"
  echo "Example: $0 gpu-node-01 all-balanced"
  exit 1
fi

echo "🚀 Adding NVIDIA container toolkit repo..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update

echo "🚀 Installing NVIDIA container toolkit..."
apt-get install -y nvidia-container-toolkit

echo "🚀 Verifying NVIDIA container CLI installation..."
nvidia-container-cli --version

echo "🚀 Adding NVIDIA Helm repo..."
helm repo add nvidia https://nvidia.github.io/gpu-operator

echo "🚀 Updating Helm repo..."
helm repo update

echo "🚀 Enabling the MIG Mode..."
nvidia-smi -mig 1

echo "🚀 Installing/upgrading NVIDIA GPU Operator with MIG single strategy..."
helm upgrade --install "$HELM_RELEASE_NAME" "$GPU_OPERATOR_CHART" \
  -n "$NAMESPACE" --create-namespace \
  --wait \
  --set mig.strategy=mixed

echo "⏳ Waiting for pods to initialize..."
sleep 60  # Adjust as needed for your environment

echo "📦 Pods in the $NAMESPACE namespace:"
kubectl get pods -n "$NAMESPACE"

echo "🧩 Patching cluster policy to enforce MIG strategy: mixed"
kubectl patch clusterpolicies.nvidia.com/cluster-policy \
    --type='json' \
    -p='[{"op":"replace", "path":"/spec/mig/strategy", "value":"mixed"}]'

echo "🏷️  Labeling node '$NODE_NAME' with MIG config: $MIG_PROFILE"
kubectl label nodes "$NODE_NAME" "nvidia.com/mig.config=$MIG_PROFILE" --overwrite

echo "⏳ Waiting for MIG Manager to apply configuration..."
while true; do
  state=$(kubectl get node "$NODE_NAME" -o=jsonpath="{.metadata.labels['nvidia\.com/mig\.config\.state']}")
  echo "Current MIG config state: $state"
  if [[ "$state" == "success" ]]; then
    echo "✅ MIG configuration successful!"
    break
  elif [[ "$state" == "failed" ]]; then
    echo "❌ MIG configuration failed!"
    exit 1
  fi
  sleep 10
done

echo "🔍 Node labels after MIG setup:"
kubectl get node "$NODE_NAME" -o=jsonpath='{.metadata.labels}' | jq .

echo "🧠 Validating MIG profiles via nvidia-smi:"
nvidia-smi -L

echo "🎉 MIG Mixed Strategy setup complete and validated!"



# ✅ Usage:
# chmod +x mig-setup-mixed.sh
# ./mig-setup-mixed.sh <your-node-name> <mig-profile>

# Example:
# ./mig-setup-mixed.sh gpu-node-01 all-balanced
