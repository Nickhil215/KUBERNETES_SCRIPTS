#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

echo "Adding Kyverno Helm repository..."
helm repo add kyverno https://kyverno.github.io/kyverno/

echo "Updating Helm repositories..."
helm repo update

echo "Installing Kyverno..."
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

echo "Applying DockerHub secret injection manifest..."
kubectl apply -f inject-dockerhub-secret.yaml

echo "Kyverno installation and configuration completed successfully."
