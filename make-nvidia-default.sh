#!/bin/bash
set -e

echo "=== 1) Generating fresh containerd config ==="
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

echo "=== 2) Enabling NVIDIA runtime in config.toml ==="
sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes\]/a \
  \ \ \ \ [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]\
  \ \ \ \ \ \ runtime_type = "io.containerd.runc.v2"\
  \ \ \ \ \ \ privileged_without_host_devices = false\
  \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]\
  \ \ \ \ \ \ BinaryName = "/usr/bin/nvidia-container-runtime"' \
  /etc/containerd/config.toml

echo "=== 3) Setting NVIDIA as default runtime ==="
sudo sed -i 's/default_runtime_name = "runc"/default_runtime_name = "nvidia"/' /etc/containerd/config.toml

echo "=== 4) Restarting containerd ==="
sudo systemctl restart containerd

echo "=== 5) Verifying default runtime ==="
crictl info | grep -i default -A3

echo "=== Done! NVIDIA runtime is now the default for the entire cluster ==="
