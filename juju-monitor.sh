 #!/bin/bash

set -euo pipefail

CONTROLLER="uk8sx"
COS_MODEL="monitoring"
KF_MODEL="kubeflow"
USER="admin"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/juju-bundle"
CHARM_DIR="$BUNDLE_DIR/kubeflow-monitor"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "   Monitoring Bundle Deployment Script"
echo "============================================"


cd "$BUNDLE_DIR"

# ---- Step 3: Pull LFS files ----
# echo "[3/9] Initializing Git LFS and pulling files..."  # Not needed, files are local
# git lfs install
# git lfs pull

# ---- Step 4: Unzip charm files ----
echo "[4/9] Unzipping kubeflow-monitor.zip..."
if [ -d "$CHARM_DIR" ]; then
  echo "Charm files already extracted, skipping unzip..."
else
  unzip kubeflow-monitor.zip
fi

ls -lh kubeflow-monitor.zip
echo "Charm files ready:"
ls "$CHARM_DIR"



echo "=========================================="
echo "Switching to controller: $CONTROLLER"
echo "=========================================="

juju switch $CONTROLLER

echo "=========================================="
echo "Creating COS model (if not exists)"
echo "=========================================="

juju add-model $COS_MODEL 2>/dev/null || echo "Model exists"

echo "=========================================="
echo "Docker hub secret"
echo "=========================================="
kubectl apply -f "$SCRIPT_DIR/docker-secret-monitor.yaml"


echo "=========================================="
echo "Deploying COS Lite"
echo "=========================================="

#juju deploy cos-lite -m $CONTROLLER:$COS_MODEL --channel=latest/stable --trust 2>/dev/null || echo "COS already deployed"
juju deploy ./bundle.yaml --trust
juju wait-for application prometheus -m $CONTROLLER:$COS_MODEL --timeout 10m

echo "=========================================="
echo "Offering Prometheus remote-write endpoint"
echo "=========================================="

juju switch $COS_MODEL
juju offer prometheus:receive-remote-write 2>/dev/null || echo "Offer already exists"

echo "=========================================="
echo "Deploying Grafana Agent in Kubeflow model"
echo "=========================================="

juju switch $KF_MODEL

juju deploy grafana-agent-k8s \
  --channel=2/stable \
  --trust 2>/dev/null || echo "Grafana Agent already deployed"

echo "Waiting for Grafana Agent pod..."
sleep 10

echo "=========================================="
echo "Consuming Prometheus offer"
echo "=========================================="

juju consume ${USER}/${COS_MODEL}.prometheus 2>/dev/null || echo "Already consumed"

echo "=========================================="
echo "Integrating Remote Write"
echo "=========================================="

juju integrate \
  grafana-agent-k8s:send-remote-write \
  prometheus:receive-remote-write 2>/dev/null || echo "Remote write already integrated"

echo "=========================================="
echo "Integrating Kubeflow Metrics"
echo "=========================================="

APPS=(
argo-controller
dex-auth
envoy
istio-ingressgateway
istio-pilot
jupyter-controller
katib-controller
katib-db
kfp-api
kfp-db
knative-operator
kserve-controller
kubeflow-dashboard
kubeflow-profiles
metacontroller-operator
minio
pvcviewer-operator
tensorboard-controller
training-operator
)

for app in "${APPS[@]}"; do
  juju integrate \
    $app:metrics-endpoint \
    grafana-agent-k8s:metrics-endpoint 2>/dev/null || true
done

echo "=========================================="
echo "Integrating Logging (Optional)"
echo "=========================================="

juju integrate \
  grafana-agent-k8s:logging-consumer \
  loki 2>/dev/null || true

echo "=========================================="
echo "STATUS CHECK"
echo "=========================================="

juju status -m $KF_MODEL
juju status -m $COS_MODEL --relations

echo "=========================================="
echo "DEPLOYMENT COMPLETE ￼"
echo "=========================================
