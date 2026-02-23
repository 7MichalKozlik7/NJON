#!/bin/bash
set -euo pipefail

OPENCV_VERSION="${CFG_OPENCV_VERSION:-4.10.0}"
CUDA_ARCH="${CFG_CUDA_ARCH:-8.7}"
MAKE_JOBS="${CFG_MAKE_JOBS:-$(( $(nproc) > 2 ? $(nproc) - 2 : 1 ))}"
PYTHON_VER="${PYTHON_VERSION:-$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo '3.10')}"

echo "[OpenCV] Instalacja OpenCV ${OPENCV_VERSION} z CUDA (arch: ${CUDA_ARCH})"
echo "[OpenCV] Watki kompilacji: ${MAKE_JOBS}"
echo "[OpenCV] UWAGA: Kompilacja moze trwac 2-4 godziny!"

# Sprawdz czy juz zainstalowane z CUDA
if python3 -c "import cv2; assert cv2.cuda.getCudaEnabledDeviceCount() > 0; print(f'OpenCV {cv2.__version__} z CUDA')" 2>/dev/null; then
    echo "[OpenCV] OpenCV z CUDA juz zainstalowane. Pomijam."
    exit 0
fi

# Sprawdz wolne miejsce (potrzeba ~15GB)
AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
if (( AVAIL_GB < 15 )); then
    echo "[OpenCV] BLAD: Za malo miejsca! Dostepne: ${AVAIL_GB}GB, wymagane: 15GB"
    exit 1
fi

# Usun domyslne OpenCV
echo "[OpenCV] Usuwanie domyslnego OpenCV..."
sudo apt-get purge -y 'libopencv*' python3-opencv 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

# Instalacja zaleznosci
echo "[OpenCV] Instalacja zaleznosci..."
sudo apt-get install -y \
    build-essential cmake git pkg-config \
    libgtk-3-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libxvidcore-dev libx264-dev \
    libjpeg-dev libpng-dev libtiff-dev \
    gfortran openexr \
    libatlas-base-dev python3-dev python3-numpy \
    libtbb2 libtbb-dev libdc1394-dev \
    libopenexr-dev \
    libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev \
    libopenblas-dev liblapack-dev liblapacke-dev \
    libeigen3-dev libgflags-dev libgoogle-glog-dev

# Pobieranie OpenCV
OPENCV_DIR="${HOME}/opencv"
OPENCV_CONTRIB_DIR="${HOME}/opencv_contrib"

echo "[OpenCV] Pobieranie kodu zrodlowego..."
if [[ -d "$OPENCV_DIR" ]]; then
    echo "[OpenCV] Katalog opencv istnieje, czyszcze build..."
    rm -rf "${OPENCV_DIR}/build"
else
    git clone --depth 1 --branch "${OPENCV_VERSION}" https://github.com/opencv/opencv.git "$OPENCV_DIR"
fi

if [[ -d "$OPENCV_CONTRIB_DIR" ]]; then
    echo "[OpenCV] opencv_contrib juz istnieje"
else
    git clone --depth 1 --branch "${OPENCV_VERSION}" https://github.com/opencv/opencv_contrib.git "$OPENCV_CONTRIB_DIR"
fi

# Kompilacja
echo "[OpenCV] Konfiguracja cmake..."
mkdir -p "${OPENCV_DIR}/build"
cd "${OPENCV_DIR}/build"

cmake -D CMAKE_BUILD_TYPE=RELEASE \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D OPENCV_EXTRA_MODULES_PATH="${OPENCV_CONTRIB_DIR}/modules" \
      -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 \
      -D WITH_OPENCL=OFF \
      -D WITH_CUDA=ON \
      -D CUDA_ARCH_BIN="${CUDA_ARCH}" \
      -D CUDA_ARCH_PTX="" \
      -D WITH_CUDNN=ON \
      -D WITH_CUBLAS=ON \
      -D ENABLE_FAST_MATH=ON \
      -D CUDA_FAST_MATH=ON \
      -D OPENCV_DNN_CUDA=ON \
      -D ENABLE_NEON=ON \
      -D WITH_QT=OFF \
      -D WITH_OPENMP=ON \
      -D BUILD_TIFF=ON \
      -D WITH_FFMPEG=ON \
      -D WITH_GSTREAMER=ON \
      -D WITH_TBB=ON \
      -D BUILD_TBB=ON \
      -D BUILD_TESTS=OFF \
      -D WITH_EIGEN=ON \
      -D WITH_V4L=ON \
      -D WITH_LIBV4L=ON \
      -D OPENCV_ENABLE_NONFREE=ON \
      -D INSTALL_C_EXAMPLES=OFF \
      -D INSTALL_PYTHON_EXAMPLES=OFF \
      -D PYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages \
      -D BUILD_opencv_python3=ON \
      -D OPENCV_GENERATE_PKGCONFIG=ON \
      -D BUILD_EXAMPLES=OFF ..

echo "[OpenCV] Kompilacja z ${MAKE_JOBS} watkami (to potrwa dlugo)..."
echo "[OpenCV] Start: $(date '+%H:%M:%S')"
make -j"${MAKE_JOBS}"

echo "[OpenCV] Instalacja..."
sudo make install
sudo ldconfig

# Symlink Python (dynamiczny - na podstawie aktualnej wersji)
PYTHON_CV2_PATH="/usr/local/lib/python${PYTHON_VER}/dist-packages/cv2"
DEST_PATH="/usr/lib/python3/dist-packages/cv2"
if [[ -d "$PYTHON_CV2_PATH" ]] && [[ ! -e "$DEST_PATH" ]]; then
    sudo ln -s "$PYTHON_CV2_PATH" "$DEST_PATH" || true
fi

# Weryfikacja
echo "[OpenCV] Weryfikacja..."
if python3 -c "import cv2; print(f'OpenCV {cv2.__version__}'); cuda=cv2.cuda.getCudaEnabledDeviceCount(); print(f'CUDA devices: {cuda}')" 2>/dev/null; then
    echo "[OpenCV] OK - OpenCV z CUDA zainstalowane!"
else
    echo "[OpenCV] UWAGA: OpenCV zainstalowane ale weryfikacja CUDA nie powiodla sie"
    echo "[OpenCV] Moze wymagac restartu lub source ~/.bashrc"
fi
