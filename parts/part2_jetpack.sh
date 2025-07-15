#!/bin/bash
set -e
echo "[JetPack] Instalacja JetPack SDK i CUDA"
sudo apt update
sudo apt upgrade -y
sudo apt install -y nvidia-jetpack
echo '[JetPack] Dodaję ścieżki CUDA do .bashrc (jeśli nie ma)...'
if ! grep -q 'cuda/bin' ~/.bashrc ; then
echo 'export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
fi
source ~/.bashrc
ls /usr/local/cuda/bin/nvcc && echo "[JetPack] nvcc jest."
echo "[JetPack] Zainstalowano JetPack i CUDA."
