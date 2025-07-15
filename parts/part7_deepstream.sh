#!/bin/bash
set -e
echo "[DeepStream] Instalacja zależności..."
sudo apt install -y libssl3 libssl-dev libgstreamer1.0-0 gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav libgstreamer-plugins-base1.0-dev libgstrtspserver-1.0-0 libjansson4 libyaml-cpp-dev libjsoncpp-dev protobuf-compiler libprotobuf-dev
cd ~
wget https://developer.nvidia.com/downloads/deepstream-71-71-multiarch -O deepstream-7.1_7.1.0-1_arm64.deb
sudo apt install -y ./deepstream-7.1_7.1.0-1_arm64.deb
sudo /opt/nvidia/deepstream/deepstream/user_additional_install.sh
echo "[DeepStream] Zainstalowano."
