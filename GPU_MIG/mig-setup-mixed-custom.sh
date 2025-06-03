#!/bin/bash

# mig-setup-custom.sh
# Setup NVIDIA GPU Operator with a user-supplied custom MIG config

set -e

NAMESPACE="gpu-operator"
GPU_OPERATOR_VERSION="v25.3.0"
NODE_NAME="$1"
MIG_PROFILE="$2"
CUSTOM_CONFIG_FILE="$3"

if [ -z "$NODE_NAME" ] || [ -z "$MIG_PROFILE" ] || [ -z "$CUSTOM_CONFIG_FILE" ]; then
  echo "Usage: $0 <node-name> <mig-profile> <custom-config-file>"
  echo "Example: $0 gpu-node-01 five-1g-one-2g ./custom-mig-config.yaml"
  exit 1
fi

if [ ! -f "$CUSTOM_CONFIG_FILE" ]; then
  echo "❌ ERROR: File '$CUSTOM_CONFIG_FILE' does not exist."
  exit 1
fi

# Extract ConfigMap name from YAML (basic parse)
CUSTOM_CONFIG_NAME=$(yq e '.metadata.name' "$CUSTOM_CONFIG_FILE" 2>/dev/null || grep -m1 'name:' "$CUSTOM_CONFIG_FILE" | awk '{print $2}')
if [ -z "$CUSTOM_CONFIG_NAME" ]; then
  echo "❌ ERROR: Could not extract config map name from $CUSTOM_CONFIG_FILE"
  exit 1
fi

echo "📦 Applying custom MIG config from '$CUSTOM_CONFIG_FILE'..."
kubectl apply -n "$NAMESPACE" -f "$CUSTOM_CONFIG_FILE"

echo "🚀 Installing GPU Operator with custom MIG config '$CUSTOM_CONFIG_NAME'..."
helm install --wait --generate-name \
    -n "$NAMESPACE" --create-namespace \
    nvidia/gpu-operator \
    --version="$GPU_OPERATOR_VERSION" \
    --set mig.strategy=mixed \
    --set migManager.config.name="$CUSTOM_CONFIG_NAME" \
    --set migManager.config.create=false \
    --set migManager.env[0].name=WITH_REBOOT \
    --set-string migManager.env[0].value=true \
    --set driver.enabled=false

echo "🧩 Patching cluster policy to mixed strategy"
kubectl patch clusterpolicies.nvidia.com/cluster-policy \
    --type='json' \
    -p='[{"op":"replace", "path":"/spec/mig/strategy", "value":"mixed"}]'

echo "🧩 Patching MIG Manager config name to '$CUSTOM_CONFIG_NAME'"
kubectl patch clusterpolicies.nvidia.com/cluster-policy \
    --type='json' \
    -p='[{"op":"replace", "path":"/spec/migManager/config/name", "value":"'"$CUSTOM_CONFIG_NAME"'"}]'

echo "🏷️  Labeling node '$NODE_NAME' with MIG profile: $MIG_PROFILE"
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

echo "🧠 Validating with nvidia-smi:"
kubectl exec -it -n "$NAMESPACE" ds/nvidia-driver-daemonset -- nvidia-smi -L

echo "📜 Last few MIG Manager logs:"
kubectl logs -n "$NAMESPACE" -l app=nvidia-mig-manager -c nvidia-mig-manager --tail=20

echo "🎉 Custom MIG configuration applied successfully!"
