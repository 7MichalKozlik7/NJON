#!/bin/bash
set -e
echo "[ML Stack] Instalacja zależności PyTorch/TensorFlow i środowiska naukowego"

# Instalacja zależności systemowych
sudo apt-get install -y \
    libopenblas-base libopenmpi-dev libomp-dev \
    libhdf5-serial-dev hdf5-tools libhdf5-dev \
    zlib1g-dev zip libjpeg8-dev liblapack-dev \
    libblas-dev gfortran

# Aktualizacja pip
pip3 install -U pip setuptools cython wheel

# Instalacja podstawowych pakietów ML globalnie
echo "[ML Stack] Instalacja podstawowych pakietów ML..."
pip3 install --no-cache-dir \
    numpy \
    scikit-learn \
    pandas \
    matplotlib \
    seaborn \
    jupyter \
    jupyterlab \
    pillow \
    imageio \
    scikit-image \
    h5py \
    protobuf \
    tqdm \
    pyyaml

# Instalacja ONNX Runtime z Jetson repo
echo "[ML Stack] Instalacja ONNX Runtime GPU..."
pip3 install --no-cache-dir onnxruntime-gpu --extra-index-url https://pypi.jetson-ai-lab.com/jp6/cu126/

# Instalacja PyTorch
echo "[ML Stack] Instalacja PyTorch 2.5.0 dla JetPack 6.2..."
pip3 install --no-cache-dir https://developer.download.nvidia.com/compute/redist/jp/v61/pytorch/torch-2.5.0a0+872d972e41.nv24.08.17622132-cp310-cp310-linux_aarch64.whl

# Instalacja torchvision kompatybilnego
echo "[ML Stack] Budowanie torchvision..."
cd ~
git clone --branch v0.16.0 https://github.com/pytorch/vision torchvision || true
cd torchvision
python3 setup.py install --user
cd ~

# Instalacja TensorFlow
echo "[ML Stack] Instalacja TensorFlow 2.16.1+nv24.06..."
sudo pip3 install --no-cache-dir \
    --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v60dp \
    tensorflow==2.16.1+nv24.06

# Instalacja Ultralytics (YOLO)
echo "[ML Stack] Instalacja Ultralytics YOLO..."
pip3 install --no-cache-dir ultralytics

# Tworzenie wirtualnego środowiska dla projektów (opcjonalne)
echo "[ML Stack] Tworzenie przykładowego środowiska wirtualnego ~/ml-env..."
python3 -m venv ~/ml-env

# Dodanie aliasu do .bashrc
if ! grep -q 'alias ml-env' ~/.bashrc; then
    echo 'alias ml-env="source ~/ml-env/bin/activate"' >> ~/.bashrc
fi

echo "[ML Stack] ✅ Instalacja zakończona!"
echo "[ML Stack] 💡 Użyj 'ml-env' aby aktywować środowisko wirtualne"