#!/bin/bash
set -e
echo "[OpenCV] Usuwam domyślne OpenCV..."
sudo apt purge -y libopencv* python3-opencv
sudo apt autoremove -y
echo "[OpenCV] Instalacja zależności..."
sudo apt install -y build-essential cmake git pkg-config libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev gfortran openexr libatlas-base-dev python3-dev python3-numpy libtbb2 libtbb-dev libdc1394-dev libopenexr-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libopenblas-dev liblapack-dev liblapacke-dev libeigen3-dev libgflags-dev libgoogle-glog-dev
echo "[OpenCV] Pobieram i kompiluję OpenCV (będzie trwać kilka godzin)"
cd ~
git clone https://github.com/opencv/opencv.git
git clone https://github.com/opencv/opencv_contrib.git
cd opencv && git checkout 4.10.0 && cd ../opencv_contrib && git checkout 4.10.0
cd ~/opencv && mkdir build && cd build
cmake -D CMAKE_BUILD_TYPE=RELEASE \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
      -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 \
      -D WITH_OPENCL=OFF \
      -D WITH_CUDA=ON \
      -D CUDA_ARCH_BIN=8.7 \
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
make -j6
sudo make install
sudo ldconfig
sudo ln -s /usr/local/lib/python3.10/dist-packages/cv2 /usr/lib/python3/dist-packages/cv2 || true
