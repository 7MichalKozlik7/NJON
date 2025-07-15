#!/bin/bash
set -e
echo "[Docker] Sprawdzenie/instalacja docker.io"
if ! command -v docker &> /dev/null; then
  sudo apt update
  sudo apt install -y docker.io
fi
sudo systemctl enable docker
sudo systemctl start docker

echo "[Docker] Instalacja NVIDIA Container Toolkit"
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list |\
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' |\
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker
sudo docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi && echo "[Docker] NVIDIA Docker OK"
