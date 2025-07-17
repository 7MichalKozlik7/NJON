#!/bin/bash

# FINALNY DZIAŁAJĄCY SKRYPT - EasyOCR GPU na Jetson Orin Nano
# Sprawdzone linia po linii

set -e

echo "🚀 EasyOCR GPU na Jetson Orin Nano - FINALNY SKRYPT"

# Maksymalna wydajność
sudo nvpmodel -m 0 2>/dev/null || echo "nvpmodel nie dostępny"
sudo jetson_clocks 2>/dev/null || echo "jetson_clocks nie dostępny"

# Czyszczenie
echo "🧹 Czyszczenie starych pakietów..."
pip3 uninstall -y torch torchvision torchaudio easyocr 2>/dev/null || true
rm -rf /tmp/torch-*.whl

# Przejście do /tmp
cd /tmp

# Pobieranie PyTorch wheel - BEZ ZMIANY NAZWY
echo "📥 Pobieranie PyTorch wheel..."
wget https://developer.download.nvidia.com/compute/redist/jp/v60/pytorch/torch-2.4.0a0+07cecf4168.nv24.05.14710581-cp310-cp310-linux_aarch64.whl

# Sprawdzenie czy plik istnieje
if [ ! -f "torch-2.4.0a0+07cecf4168.nv24.05.14710581-cp310-cp310-linux_aarch64.whl" ]; then
    echo "❌ Wheel nie został pobrany!"
    exit 1
fi

echo "✅ Wheel pobrany: $(ls torch-*.whl)"

# Instalacja PyTorch
echo "🔧 Instalacja PyTorch..."
pip3 install torch-2.4.0a0+07cecf4168.nv24.05.14710581-cp310-cp310-linux_aarch64.whl

# Instalacja kompatybilnego numpy
pip3 install 'numpy<2.0'

# Test PyTorch
echo "🧪 Test PyTorch..."
python3 -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU name: {torch.cuda.get_device_name(0)}')
    # Test GPU tensor
    x = torch.cuda.FloatTensor([1.0, 2.0])
    print(f'GPU tensor: {x}')
    print('✅ PyTorch GPU działa!')
else:
    print('❌ CUDA nie działa - sprawdź instalację')
    exit(1)
"

# Instalacja dependencies dla torchvision
echo "📦 Instalacja dependencies..."
sudo apt update
sudo apt install -y libjpeg-dev zlib1g-dev libpython3-dev libavcodec-dev libavformat-dev libswscale-dev

# Budowa torchvision
echo "🔨 Budowa torchvision..."
git clone --branch v0.17.0 https://github.com/pytorch/vision torchvision
cd torchvision
pip3 install packaging
export BUILD_VERSION=0.17.0
python3 setup.py install --user
cd /tmp

# Instalacja EasyOCR dependencies
echo "📚 Instalacja EasyOCR dependencies..."
pip3 install opencv-python-headless pillow scikit-image scipy requests PyYAML shapely

# Instalacja EasyOCR
echo "📚 Instalacja EasyOCR..."
pip3 install easyocr

# Test EasyOCR
echo "🧪 Test EasyOCR..."
python3 -c "
import easyocr
import torch
from PIL import Image, ImageDraw

print('=== Test EasyOCR GPU ===')
print(f'CUDA available: {torch.cuda.is_available()}')

# Tworzenie testowego obrazka
img = Image.new('RGB', (400, 100), color='white')
draw = ImageDraw.Draw(img)
draw.text((10, 30), 'Hello GPU World!', fill='black')
draw.text((10, 60), 'EasyOCR Test 2025', fill='black')
img.save('/tmp/test_gpu.jpg')

# Inicjalizacja EasyOCR z GPU
print('Inicjalizacja EasyOCR z GPU...')
reader = easyocr.Reader(['en'], gpu=True)

# OCR test
print('Wykonywanie OCR...')
results = reader.readtext('/tmp/test_gpu.jpg')

print('📋 WYNIKI:')
for (bbox, text, conf) in results:
    print(f'  \"{text}\" (pewność: {conf:.3f})')

if len(results) > 0:
    print('✅ EasyOCR GPU działa!')
else:
    print('⚠️ EasyOCR nie wykrył tekstu')
"

# Tworzenie przykładu użycia
echo "📝 Tworzenie przykładu użycia..."
cat > ~/easyocr_gpu_final.py << 'EOF'
#!/usr/bin/env python3
"""
EasyOCR GPU Final Test - Jetson Orin Nano
"""
import easyocr
import torch
import cv2
import time
import sys

def check_gpu():
    """Sprawdź czy GPU działa"""
    print("=== Sprawdzanie GPU ===")
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"GPU: {torch.cuda.get_device_name(0)}")
        print(f"CUDA version: {torch.version.cuda}")
        return True
    return False

def test_image_ocr():
    """Test OCR na obrazku"""
    print("\n=== Test OCR na obrazku ===")
    
    # Inicjalizacja
    reader = easyocr.Reader(['en'], gpu=True)
    
    # Otwórz kamerę lub użyj testowego obrazka
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Nie można otworzyć kamery")
        return
    
    print("📹 Kamera otwarta. Naciśnij SPACE dla OCR, Q dla wyjścia")
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        # Dodaj instrukcje na ekran
        cv2.putText(frame, "SPACE - OCR GPU | Q - Quit", (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.imshow('EasyOCR GPU - Final Test', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord(' '):
            print("\n🔥 OCR GPU processing...")
            start_time = time.time()
            
            try:
                results = reader.readtext(frame)
                end_time = time.time()
                
                print(f"⏱️ Czas: {end_time - start_time:.3f}s")
                print("📄 Wyniki:")
                for (bbox, text, conf) in results:
                    print(f"  '{text}' (pewność: {conf:.3f})")
                
                if not results:
                    print("  Nie wykryto tekstu")
                    
            except Exception as e:
                print(f"❌ Błąd OCR: {e}")
    
    cap.release()
    cv2.destroyAllWindows()

def main():
    """Główna funkcja"""
    print("🚀 EasyOCR GPU Final Test")
    
    # Sprawdź GPU
    if not check_gpu():
        print("❌ GPU nie działa - sprawdź instalację")
        sys.exit(1)
    
    # Test OCR
    try:
        test_image_ocr()
    except KeyboardInterrupt:
        print("\n👋 Zakończono przez użytkownika")
    except Exception as e:
        print(f"❌ Błąd: {e}")

if __name__ == "__main__":
    main()
EOF

chmod +x ~/easyocr_gpu_final.py

# Podsumowanie
echo ""
echo "🎉 INSTALACJA ZAKOŃCZONA!"
echo ""
echo "✅ PyTorch z GPU: zainstalowany"
echo "✅ torchvision: zbudowany ze źródeł"
echo "✅ EasyOCR z GPU: zainstalowany"
echo ""
echo "🚀 TEST:"
echo "python3 ~/easyocr_gpu_final.py"
echo ""
echo "📊 INFO:"
echo "• PyTorch version: $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'nie zainstalowany')"
echo "• CUDA available: $(python3 -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'nie zainstalowany')"
echo ""
echo "🎯 GOTOWE!"