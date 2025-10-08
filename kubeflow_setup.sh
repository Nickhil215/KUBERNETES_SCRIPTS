#!/usr/bin/env bash

set -euo pipefail

# =============== CONFIG ===============
JUJU_CHANNEL="3.6/stable"
KUBEFLOW_CHANNEL="1.9/stable"
JUJU_CLOUD_NAME="myk8scloud"
JUJU_CONTROLLER_NAME="uk8sx"
JUJU_MODEL_NAME="kubeflow"
K8S_CLUSTER_NAME="kubernetes"
DEX_USERNAME="admin"
DEX_PASSWORD="admin"
# ======================================

echo "[1/9] Installing Juju snap..."
sudo snap install juju --channel="$JUJU_CHANNEL"

echo "[2/9] Ensuring Juju local storage directory exists..."
mkdir -p ~/.local/share

echo "[3/9] Adding Kubernetes cluster to Juju..."
kubectl config view --raw | \
  juju add-k8s "$JUJU_CLOUD_NAME" --cluster-name="$K8S_CLUSTER_NAME" --client || \
  echo "✅ Cloud '$JUJU_CLOUD_NAME' already exists, skipping..."

echo "[4/9] Bootstrapping Juju controller..."
juju bootstrap "$JUJU_CLOUD_NAME" "$JUJU_CONTROLLER_NAME" || \
  echo "✅ Controller '$JUJU_CONTROLLER_NAME' already exists, skipping..."

echo "[5/9] Adding Kubeflow model..."
juju add-model "$JUJU_MODEL_NAME" || \
  echo "✅ Model '$JUJU_MODEL_NAME' already exists, skipping..."

echo "[6/9] Adjusting sysctl for inotify..."
sudo sysctl fs.inotify.max_user_instances=1280
sudo sysctl fs.inotify.max_user_watches=655360

echo "[7/9] Deploying Kubeflow..."
juju deploy ch:kubeflow --trust --channel="$KUBEFLOW_CHANNEL"

echo "Waiting for dex-auth to be available..."
until juju status dex-auth --format=short &>/dev/null; do
  echo "⏳ Waiting for dex-auth charm to appear..."
  sleep 15
done

echo "[8/9] Configuring Dex static login credentials..."
juju config dex-auth static-username="$DEX_USERNAME"
juju config dex-auth static-password="$DEX_PASSWORD"

echo "[9/9] Checking external IP for Kubeflow dashboard..."
echo "⏳ Waiting for istio-ingressgateway external IP..."
until kubectl -n kubeflow get svc istio-ingressgateway-workload -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' >/dev/null; do
  sleep 10
done

EXTERNAL_IP=$(kubectl -n kubeflow get svc istio-ingressgateway-workload -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "=================================================="
echo "✅ Kubeflow deployment initiated successfully!"
echo "🔑 Dex Username: $DEX_USERNAME"
echo "🔑 Dex Password: $DEX_PASSWORD"
echo "🌐 Access the Kubeflow UI at: http://$EXTERNAL_IP/"
echo "Run the following to monitor deployment:"
echo "  juju status --watch 5s"
echo "=================================================="
