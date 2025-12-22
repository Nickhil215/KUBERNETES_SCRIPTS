#!/bin/bash
set -e

#################################################
# CONFIG
#################################################
JUJU_CONTROLLER="k8s-controller"
K8S_CLOUD="k8s-cloud"
MONITORING_MODEL="monitoring"
KUBEFLOW_MODEL="kubeflow"
COS_CHANNEL="latest/stable"
DASHBOARD_DIR="./dashboards"

#################################################
# UTILS
#################################################
log() { echo -e "\n▶ $1"; }

require() {
  command -v "$1" >/dev/null || {
    echo "❌ Required command '$1' not found"
    exit 1
  }
}

#################################################
# PRECHECKS
#################################################
require kubectl
require juju

kubectl cluster-info >/dev/null || {
  echo "❌ kubectl not configured"
  exit 1
}

#################################################
# REGISTER K8S WITH JUJU (SAFE)
#################################################
log "Registering Kubernetes with Juju (if needed)"
juju add-k8s "$K8S_CLOUD" --client 2>/dev/null || true

#################################################
# ENSURE CONTROLLER
#################################################
log "Ensuring Juju controller exists"
juju controllers | grep -q "$JUJU_CONTROLLER" || \
  juju bootstrap "$K8S_CLOUD" "$JUJU_CONTROLLER"

juju switch "$JUJU_CONTROLLER"

#################################################
# ENSURE MONITORING MODEL
#################################################
log "Ensuring monitoring model exists"
juju models | grep -q "$MONITORING_MODEL" || \
  juju add-model "$MONITORING_MODEL"

#################################################
# DEPLOY COS LITE
#################################################
juju switch "$MONITORING_MODEL"

log "Deploying COS Lite (if not already deployed)"
juju deploy cos-lite --channel="$COS_CHANNEL" --trust || true

log "Waiting for COS Lite to become ready"
juju wait-for model "$MONITORING_MODEL" --timeout=30m

#################################################
# WAIT FOR GRAFANA
#################################################
log "Waiting for Grafana application"
juju wait-for application grafana --timeout=10m

#################################################
# IMPORT GRAFANA DASHBOARDS
#################################################
if [ -d "$DASHBOARD_DIR" ]; then
  log "Importing Grafana dashboards from $DASHBOARD_DIR"
  for file in "$DASHBOARD_DIR"/*.json; do
    [ -f "$file" ] || continue
    log "Importing dashboard: $(basename "$file")"
    juju run grafana/0 add-dashboard dashboard="$(cat "$file")"
  done
else
  log "Dashboards directory not found, skipping import"
fi

#################################################
# RELATE EXISTING KUBEFLOW SERVICES
#################################################
if juju models | grep -q "$KUBEFLOW_MODEL"; then
  juju switch "$KUBEFLOW_MODEL"

  log "Relating Kubeflow services to Prometheus (COS Lite)"

  KUBEFLOW_APPS=(
    argo-controller
    dex-auth
    envoy
    istio-pilot
    istio-gateway
    jupyter-controller
    katib-controller
    kfp-api
    knative-eventing
    knative-serving
    knative-operator
    metacontroller-operator
    minio
    seldon-controller-manager
    training-operator
    pvcviewer-operator
    kserve-controller
    kubeflow-profiles
    tensorboard-controller
  )

  for app in "${KUBEFLOW_APPS[@]}"; do
    juju relate "$app" prometheus || true
  done
else
  log "Kubeflow model not found, skipping relations"
fi

#################################################
# DONE
#################################################
log "COS Lite monitoring + dashboards setup completed 🎉"

juju switch "$MONITORING_MODEL"
juju status --relations --color

echo -e "\nGrafana access:"
echo "  juju switch monitoring"
echo "  juju run grafana/0 get-admin-password"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:3000"
