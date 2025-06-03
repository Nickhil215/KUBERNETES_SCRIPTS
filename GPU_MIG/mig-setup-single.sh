#!/bin/bash

# mig-setup-single.sh
# Setup NVIDIA GPU Operator with MIG Single Strategy on Kubernetes

set -e

NAMESPACE="gpu-operator"
HELM_RELEASE_NAME="gpu-operator"
GPU_OPERATOR_VERSION="v25.3.0"
NODE_NAME="$1"
# MIG_PROFILE="all-1g.10gb"
MIG_PROFILE="$2"


if [ -z "$NODE_NAME" ] || [ -z "$MIG_PROFILE" ]; then
  echo "Usage: $0 <node-name> <mig-profile>"
  echo "Example: $0 my-gpu-node all-1g.10gb"
  exit 1
fi

echo "🚀 Installing NVIDIA GPU Operator with MIG single strategy..."
  helm install --wait --generate-name \
    -n gpu-operator --create-namespace \
    nvidia/gpu-operator \
    --set mig.strategy=single

echo "⏳ Waiting for pods to spin up..."
sleep 60  # adjust based on infra speed

echo "📦 Verifying pods in $NAMESPACE namespace:"
kubectl get pods -n "$NAMESPACE"

echo "🛠️  Patching cluster policy to enforce MIG strategy: single"
kubectl patch clusterpolicies.nvidia.com/cluster-policy \
    --type='json' \
    -p='[{"op":"replace", "path":"/spec/mig/strategy", "value":"single"}]'

echo "🏷️  Labeling node '$NODE_NAME' with MIG config: $MIG_PROFILE"
kubectl label nodes "$NODE_NAME" "nvidia.com/mig.config=$MIG_PROFILE" --overwrite

echo "⏳ Waiting for MIG configuration to apply..."
while true; do
  state=$(kubectl get node "$NODE_NAME" -o=jsonpath="{.metadata.labels['nvidia\.com/mig\.config\.state']}")
  echo "Current MIG config state: $state"
  if [[ "$state" == "success" ]]; then
    echo "✅ MIG successfully configured!"
    break
  elif [[ "$state" == "failed" ]]; then
    echo "❌ MIG configuration failed!"
    exit 1
  fi
  sleep 10
done

echo "🔍 Final node labels:"
kubectl get node "$NODE_NAME" -o=jsonpath='{.metadata.labels}' | jq .

echo "🧠 Validating MIG slices with nvidia-smi:"
kubectl exec -it -n "$NAMESPACE" ds/nvidia-driver-daemonset -- nvidia-smi -L

echo "🎉 MIG Single Strategy setup complete!"



# EXECUTION STEPS 
# chmod +x mig-setup-single.sh
# ./mig-setup-single.sh <your-node-name> <mig-profile>

# Example: ./mig-setup-single.sh gpu-node-01 all-1g.10gb

