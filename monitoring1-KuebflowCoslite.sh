#!/bin/bash

set -euo pipefail

CONTROLLER="uk8sx"
COS_MODEL="monitoring"
KF_MODEL="kubeflow"
USER="admin"

echo "=========================================="
echo "Switching to controller: $CONTROLLER"
echo "=========================================="

juju switch $CONTROLLER

echo "=========================================="
echo "Creating COS model (if not exists)"
echo "=========================================="

juju add-model $COS_MODEL 2>/dev/null || echo "Model exists"

echo "=========================================="
echo "Deploying COS Lite"
echo "=========================================="

juju deploy cos-lite -m $CONTROLLER:$COS_MODEL --channel=latest/stable --trust 2>/dev/null || echo "COS already deployed"

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
