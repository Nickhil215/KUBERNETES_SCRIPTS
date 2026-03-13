#!/bin/bash
set -euo pipefail

# =============== CONFIG ===============
JUJU_CHANNEL="3.6/stable"
JUJU_CLOUD_NAME="myk8scloud"
JUJU_CONTROLLER_NAME="uk8sx"
JUJU_MODEL_NAME="kubeflow"
K8S_CLUSTER_NAME="kubernetes"
# BUNDLE_REPO="https://github.com/deepaksri0147/juju-bundle.git"  # No longer needed
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/juju-bundle"
CHARM_DIR="$BUNDLE_DIR/juju-charm-files"
# ======================================

echo "============================================"
echo "   Kubeflow Bundle Deployment Script"
echo "============================================"

# ---- Step 1: Install git-lfs ----
# echo "[1/9] Installing git-lfs..."
# apt install git-lfs -y                          # Not needed, no LFS pull required

# ---- Step 2: Clone the repo ----
# echo "[2/9] Cloning Juju bundle repo..."        # Not needed, files are local
# if [ -d "$BUNDLE_DIR" ]; then
#   echo "Directory $BUNDLE_DIR already exists, skipping clone..."
# else
#   git clone "$BUNDLE_REPO" "$BUNDLE_DIR"
# fi

cd "$BUNDLE_DIR"

# ---- Step 3: Pull LFS files ----
# echo "[3/9] Initializing Git LFS and pulling files..."  # Not needed, files are local
# git lfs install
# git lfs pull

# ---- Step 4: Unzip charm files ----
echo "[4/9] Unzipping juju-charm-files.zip..."
if [ -d "$CHARM_DIR" ]; then
  echo "Charm files already extracted, skipping unzip..."
else
  unzip juju-charm-files.zip
fi

ls -lh juju-charm-files.zip
echo "Charm files ready:"
ls "$CHARM_DIR"

# ---- Step 5: Install Juju ----
echo "[5/9] Installing Juju snap (channel: $JUJU_CHANNEL)..."
sudo snap install juju --channel="$JUJU_CHANNEL"
export PATH=$PATH:/snap/bin

# ---- Step 6: Ensure Juju local storage ----
echo "[6/9] Ensuring Juju local storage directory exists..."
mkdir -p ~/.local/share

# ---- Step 7: Add K8s cloud to Juju ----
echo "[7/9] Adding Kubernetes cluster to Juju..."
kubectl config view --raw | \
  juju add-k8s "$JUJU_CLOUD_NAME" --cluster-name="$K8S_CLUSTER_NAME" --client || \
  echo "Cloud '$JUJU_CLOUD_NAME' already exists, skipping..."

# ---- Step 8: Bootstrap Juju controller ----
echo "[8/9] Bootstrapping Juju controller '$JUJU_CONTROLLER_NAME'..."
juju bootstrap "$JUJU_CLOUD_NAME" "$JUJU_CONTROLLER_NAME" || \
  echo "Controller '$JUJU_CONTROLLER_NAME' already exists, skipping..."

# ---- Step 9: Add Kubeflow model ----
echo "[9/9] Adding Kubeflow model '$JUJU_MODEL_NAME'..."
juju add-model "$JUJU_MODEL_NAME" || \
  echo "Model '$JUJU_MODEL_NAME' already exists, skipping..."

# ---- Sysctl tuning ----
echo "[+] Adjusting sysctl inotify limits..."
sudo sysctl fs.inotify.max_user_instances=1280
sudo sysctl fs.inotify.max_user_watches=655360

#----Docker HUB Secrets---
kubectl apply -f dockerhub-secret-kubflow.yaml


# ---- Deploy bundle ----
echo "[+] Deploying Kubeflow bundle..."
cd "$CHARM_DIR"
juju deploy ./bundle-1.10-final.yaml --trust

echo ""
echo "============================================"
echo "✅ Deployment initiated successfully!"
echo "============================================"
echo ""
echo "Monitor deployment status with:"
echo "  juju status --watch 5s"
echo ""
echo "Wait for all units to reach 'active/idle' before using Kubeflow."
echo "This typically takes 20-40 minutes depending on image pull speed."
