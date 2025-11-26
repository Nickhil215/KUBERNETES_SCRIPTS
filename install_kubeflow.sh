#!/usr/bin/env bash

set -euo pipefail

# =============== CONFIG ===============
JUJU_CHANNEL="3.6/stable"
KUBEFLOW_CHANNEL="1.10/stable"
JUJU_CLOUD_NAME="myk8scloud"
JUJU_CONTROLLER_NAME="uk8sx"
JUJU_MODEL_NAME="kubeflow"
K8S_CLUSTER_NAME="kubernetes"
# ======================================

echo "[1/7] Installing Juju snap..."
sudo snap install juju --channel="$JUJU_CHANNEL"

echo "[2/7] Ensuring Juju local storage directory exists..."
mkdir -p ~/.local/share

echo "[3/7] Adding Kubernetes cluster to Juju..."
kubectl config view --raw | \
  juju add-k8s "$JUJU_CLOUD_NAME" --cluster-name="$K8S_CLUSTER_NAME" --client || \
  echo "Cloud $JUJU_CLOUD_NAME already exists, skipping..."

echo "[4/7] Bootstrapping Juju controller..."
juju bootstrap "$JUJU_CLOUD_NAME" "$JUJU_CONTROLLER_NAME" || \
  echo "Controller $JUJU_CONTROLLER_NAME already exists, skipping..."

echo "[5/7] Adding Kubeflow model..."
juju add-model "$JUJU_MODEL_NAME" || \
  echo "Model $JUJU_MODEL_NAME already exists, skipping..."

echo "[6/7] Adjusting sysctl for inotify..."
sudo sysctl fs.inotify.max_user_instances=1280
sudo sysctl fs.inotify.max_user_watches=655360

echo "[7/7] Deploying Kubeflow..."
juju deploy ch:kubeflow --trust --channel="$KUBEFLOW_CHANNEL"

echo "=================================================="
echo "Kubeflow deployment initiated. Use:"
echo "  juju status --watch 5s"
echo "to monitor progress."
echo "=================================================="
