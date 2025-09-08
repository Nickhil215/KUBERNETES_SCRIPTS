#!/bin/bash
set -e

# Remove current Bazel installation if it exists
if [ -f "/usr/local/bin/bazel" ]; then
  echo "Removing existing Bazel..."
  sudo rm /usr/local/bin/bazel
else
  echo "No existing Bazel installation found."
fi

# Install Bazelisk
echo "Installing Bazelisk..."
sudo curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
  -o /usr/local/bin/bazel
sudo chmod +x /usr/local/bin/bazel

# Force Bazel version for this repo
cd ~/builder
echo "4.2.2" > .bazelversion
echo "Bazel version set to 4.2.2 for this repository."

# Verify version
echo "Verifying Bazel version..."
bazel --version

# Run the build
echo "Running Bazel build..."
bazel run //builders/py39/stack:build
