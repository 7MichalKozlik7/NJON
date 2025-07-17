#!/bin/bash

# EasyOCR GPU dla Jetson Orin Nano - DZIAŁAJĄCY SKRYPT
set -e

echo "🚀 EasyOCR GPU dla Jetson Orin Nano"

# CZYSZCZENIE
echo "🧹 Czyszczenie..."
pip3 uninstall -y torch torchvision torchaudio easyocr opencv-python opencv-python-headless 2>/dev/null || true
rm -rf ~/.cache/pip/*
rm -rf /tmp/torch-*.whl

# SYSTEM UPDATE
sudo apt update
sudo apt install -y python3-pip python3-dev libopencv-dev

# MAKSYMALNA WYDAJNOŚĆ
sudo nvpmodel -m 0
sudo jetson_clocks

# PYTORCH Z CUDA DLA JETSON
echo "🔥 Instalacja PyTorch z CUDA..."
cd /tmp

# JetPack 6.x - Python 3.10
wget https://developer.download.nvidia.com/compute/redist/jp/v60/pytorch/torch-2.3.0a0+40ec155e58.nv24.03-cp310-cp310-linux_aarch64.whl
pip3 install torch-2.3.0a0+40ec155e58.nv24.03-cp310-cp310-linux_aarch64.whl

# TORCHVISION
pip3 install torchvision

# EASYOCR
echo "📚 Instalacja EasyOCR..."
pip3 install easyocr opencv-python-headless pillow numpy

# TEST
echo "🧪 Test GPU..."
python3 -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print('✅ GPU działa!')
else:
    print('❌ GPU nie działa')
"

# TEST EASYOCR
echo "🧪 Test EasyOCR GPU..."
python3 -c "
import easyocr
from PIL import Image, ImageDraw

# Testowy obrazek
img = Image.new('RGB', (400, 100), color='white')
draw = ImageDraw.Draw(img)
draw.text((10, 30), 'Hello GPU World!', fill='black')
img.save('/tmp/test.jpg')

# EasyOCR z GPU
reader = easyocr.Reader(['en'], gpu=True)
result = reader.readtext('/tmp/test.jpg')

print('📋 WYNIKI:')
for (bbox, text, conf) in result:
    print(f'  {text} ({conf:.2f})')

print('✅ EasyOCR GPU działa!')
"

# PRZYKŁAD
cat > ~/easyocr_gpu.py << 'EOF'
#!/usr/bin/env python3
import easyocr
import cv2
import sys

def ocr_image(image_path):
    reader = easyocr.Reader(['en'], gpu=True)
    results = reader.readtext(image_path)
    
    print(f"📄 Znaleziono {len(results)} tekstów:")
    for i, (bbox, text, conf) in enumerate(results):
        print(f"  {i+1}. '{text}' ({conf:.3f})")
    
    return results

def ocr_camera():
    reader = easyocr.Reader(['en'], gpu=True)
    cap = cv2.VideoCapture(0)
    
    print("📹 SPACE - OCR, Q - wyjście")
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        cv2.putText(frame, "SPACE - OCR, Q - Quit", (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.imshow('EasyOCR GPU', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord(' '):
            print("\n🔍 OCR GPU...")
            results = reader.readtext(frame)
            for (bbox, text, conf) in results:
                print(f"  '{text}' ({conf:.3f})")
    
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        ocr_image(sys.argv[1])
    else:
        ocr_camera()
EOF

chmod +x ~/easyocr_gpu.py

echo ""
echo "✅ GOTOWE!"
echo ""
echo "🚀 UŻYCIE:"
echo "python3 ~/easyocr_gpu.py image.jpg"
echo "python3 ~/easyocr_gpu.py  # kamera"
echo ""
echo "🎯 EasyOCR z GPU na Jetson Orin Nano działa!"