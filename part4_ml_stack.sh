#!/bin/bash
set -euo pipefail

echo "[ML Stack] Instalacja frameworkow ML..."

# --- Zaleznosci systemowe ---
echo "[ML Stack] Instalacja zaleznosci systemowych..."
sudo apt-get install -y \
    libopenblas-base libopenmpi-dev libomp-dev \
    libhdf5-serial-dev hdf5-tools libhdf5-dev \
    zlib1g-dev zip libjpeg8-dev liblapack-dev \
    libblas-dev gfortran libpng-dev libtiff-dev

# --- Aktualizacja pip ---
echo "[ML Stack] Aktualizacja pip..."
python3 -m pip install --upgrade pip setuptools cython wheel 2>/dev/null || \
    pip3 install --upgrade pip setuptools cython wheel

# --- Pakiety ML ---
echo "[ML Stack] Instalacja podstawowych pakietow ML..."
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

# --- ONNX Runtime GPU ---
echo "[ML Stack] Instalacja ONNX Runtime GPU..."
pip3 install --no-cache-dir onnxruntime-gpu \
    --extra-index-url https://pypi.jetson-ai-lab.com/jp6/cu126/ || \
    echo "[ML Stack] UWAGA: ONNX Runtime GPU nie zainstalowany (moze nie byc dostepny dla tej platformy)"

# --- PyTorch ---
echo "[ML Stack] Instalacja PyTorch dla JetPack 6..."
PYTORCH_URL="https://developer.download.nvidia.com/compute/redist/jp/v61/pytorch/torch-2.5.0a0+872d972e41.nv24.08.17622132-cp310-cp310-linux_aarch64.whl"

if python3 -c "import torch" 2>/dev/null; then
    TORCH_VER=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
    echo "[ML Stack] PyTorch juz zainstalowany: v${TORCH_VER}"
else
    pip3 install --no-cache-dir "$PYTORCH_URL" || {
        echo "[ML Stack] UWAGA: Nie udalo sie zainstalowac PyTorch z NVIDIA"
        echo "[ML Stack] Probuje z pip index..."
        pip3 install --no-cache-dir torch --extra-index-url https://pypi.jetson-ai-lab.com/jp6/cu126/ || \
            echo "[ML Stack] BLAD: PyTorch nie zainstalowany"
    }
fi

# --- Torchvision ---
echo "[ML Stack] Instalacja torchvision..."
if python3 -c "import torchvision" 2>/dev/null; then
    echo "[ML Stack] torchvision juz zainstalowane"
else
    TORCHVISION_DIR="${HOME}/torchvision"
    if [[ -d "$TORCHVISION_DIR" ]]; then
        echo "[ML Stack] Katalog torchvision istnieje, uzywam istniejacego..."
    else
        git clone --branch v0.20.0 --depth 1 https://github.com/pytorch/vision "$TORCHVISION_DIR" || {
            echo "[ML Stack] UWAGA: Nie udalo sie sklonowac torchvision"
            echo "[ML Stack] Probuje z pip..."
            pip3 install --no-cache-dir torchvision --extra-index-url https://pypi.jetson-ai-lab.com/jp6/cu126/ || true
        }
    fi

    if [[ -d "$TORCHVISION_DIR" ]]; then
        cd "$TORCHVISION_DIR"
        pip3 install --no-cache-dir . || {
            echo "[ML Stack] UWAGA: Budowanie torchvision nie powiodlo sie"
            pip3 install --no-cache-dir torchvision || true
        }
        cd ~
    fi
fi

# --- TensorFlow ---
echo "[ML Stack] Instalacja TensorFlow..."
if python3 -c "import tensorflow" 2>/dev/null; then
    TF_VER=$(python3 -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    echo "[ML Stack] TensorFlow juz zainstalowany: v${TF_VER}"
else
    pip3 install --no-cache-dir \
        --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v60dp \
        'tensorflow==2.16.1+nv24.06' || {
        echo "[ML Stack] UWAGA: TensorFlow NVIDIA nie dostepny"
        echo "[ML Stack] Probuje standardowa wersje..."
        pip3 install --no-cache-dir tensorflow || \
            echo "[ML Stack] BLAD: TensorFlow nie zainstalowany"
    }
fi

# --- Ultralytics YOLO ---
echo "[ML Stack] Instalacja Ultralytics YOLO..."
pip3 install --no-cache-dir ultralytics || \
    echo "[ML Stack] UWAGA: Ultralytics nie zainstalowane"

# --- Srodowisko wirtualne ---
VENV_DIR="${HOME}/ml-env"
if [[ ! -d "$VENV_DIR" ]]; then
    echo "[ML Stack] Tworzenie srodowiska wirtualnego ${VENV_DIR}..."
    python3 -m venv "$VENV_DIR"
fi

# Alias (idempotentny)
if ! grep -qF 'alias ml-env=' "${HOME}/.bashrc" 2>/dev/null; then
    echo "" >> "${HOME}/.bashrc"
    echo '# ML virtual environment (added by NJON)' >> "${HOME}/.bashrc"
    echo "alias ml-env='source ${VENV_DIR}/bin/activate'" >> "${HOME}/.bashrc"
fi

# --- Weryfikacja ---
echo "[ML Stack] Weryfikacja:"
for mod in numpy torch tensorflow cv2 sklearn pandas; do
    if python3 -c "import $mod" 2>/dev/null; then
        VER=$(python3 -c "import $mod; print(getattr($mod, '__version__', 'ok'))" 2>/dev/null)
        echo "  OK: $mod v${VER}"
    else
        echo "  BRAK: $mod"
    fi
done

echo "[ML Stack] Instalacja zakonczona!"
echo "[ML Stack] Uzyj 'ml-env' aby aktywowac srodowisko wirtualne"
