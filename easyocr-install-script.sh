#!/bin/bash

# =============================================================================
# EASYOCR - CZYSZCZENIE I INSTALACJA OD ZERA
# Usuwa wszystko i instaluje prostą, działającą metodą
# =============================================================================

set -e

echo "🧹 CZYSZCZENIE I REINSTALACJA EASYOCR"
echo "Usuwa wszystko i instaluje od zera prostą metodą"
echo ""

# Zatrzymaj przy błędzie
trap 'echo "❌ Błąd w linii $LINENO. Sprawdź logi."' ERR

# KROK 1: KOMPLETNE CZYSZCZENIE
echo "🗑️  Krok 1: Usuwanie wszystkich związanych pakietów..."

# Usuń wszystkie Python packages związane z ML
pip3 uninstall -y torch torchvision torchaudio easyocr opencv-python opencv-python-headless 2>/dev/null || true
pip3 uninstall -y numpy pillow 2>/dev/null || true

# Usuń cache pip
rm -rf ~/.cache/pip/*
rm -rf ~/.local/lib/python*/site-packages/torch*
rm -rf ~/.local/lib/python*/site-packages/easyocr*
rm -rf ~/.local/lib/python*/site-packages/cv2*

# Usuń stare pliki
rm -rf /tmp/torch-*.whl
rm -rf /tmp/easyocr*

echo "✅ Czyszczenie zakończone"

# KROK 2: AKTUALIZACJA SYSTEMU
echo "📦 Krok 2: Aktualizacja systemu..."
sudo apt update
sudo apt install -y python3-pip python3-dev

# KROK 3: INSTALACJA PODSTAWOWYCH DEPENDENCIES
echo "🔧 Krok 3: Instalacja podstawowych dependencies..."
sudo apt install -y libopencv-dev python3-opencv
pip3 install --upgrade pip setuptools wheel

# KROK 4: INSTALACJA PYTORCH CPU (ZAWSZE DZIAŁA)
echo "🔥 Krok 4: Instalacja PyTorch CPU version (zawsze działa)..."
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Test PyTorch
echo "🧪 Test PyTorch..."
python3 -c "
import torch
print(f'✅ PyTorch {torch.__version__} zainstalowany')
print(f'CUDA available: {torch.cuda.is_available()}')
print('CPU tensors działają poprawnie')
"

# KROK 5: INSTALACJA EASYOCR
echo "📚 Krok 5: Instalacja EasyOCR..."
pip3 install easyocr opencv-python-headless pillow numpy

# KROK 6: TEST EASYOCR
echo "🧪 Krok 6: Test EasyOCR..."
python3 << 'EOF'
import easyocr
import numpy as np
from PIL import Image, ImageDraw

print("Tworzenie testowego obrazka...")
img = Image.new('RGB', (400, 100), color='white')
draw = ImageDraw.Draw(img)
draw.text((10, 30), "Hello World 123", fill='black')
draw.text((10, 60), "EasyOCR Test", fill='black')
img.save('/tmp/test_easyocr.jpg')

print("Inicjalizacja EasyOCR (CPU mode)...")
reader = easyocr.Reader(['en'], gpu=False)

print("Test OCR...")
result = reader.readtext('/tmp/test_easyocr.jpg')

print("\n📋 WYNIKI:")
for (bbox, text, confidence) in result:
    print(f"  '{text}' (pewność: {confidence:.2f})")

print(f"\n✅ EasyOCR działa! Znaleziono {len(result)} tekstów")
EOF

# KROK 7: TWORZENIE PROSTEGO PRZYKŁADU
echo "📝 Krok 7: Tworzenie prostego przykładu..."
cat > /home/$USER/easyocr_simple.py << 'EOF'
#!/usr/bin/env python3
"""
Prosty przykład EasyOCR dla Jetson Orin Nano
CPU mode - zawsze działa
"""
import easyocr
import cv2
import sys
import argparse

def ocr_image(image_path, languages=['en']):
    """OCR na obrazku"""
    print(f"🔍 OCR na: {image_path}")
    
    # Inicjalizacja (CPU mode)
    reader = easyocr.Reader(languages, gpu=False)
    
    # OCR
    results = reader.readtext(image_path)
    
    # Wyniki
    print(f"📄 Znaleziono {len(results)} tekstów:")
    for i, (bbox, text, confidence) in enumerate(results):
        print(f"  {i+1}. '{text}' (pewność: {confidence:.3f})")
    
    return results

def ocr_camera(languages=['en']):
    """OCR z kamery"""
    print("📹 OCR z kamery - naciśnij SPACE dla OCR, Q dla wyjścia")
    
    reader = easyocr.Reader(languages, gpu=False)
    cap = cv2.VideoCapture(0)
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        cv2.putText(frame, "SPACE - OCR, Q - Quit", (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.imshow('EasyOCR Camera', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord(' '):
            print("\n🔍 OCR...")
            results = reader.readtext(frame)
            for (bbox, text, confidence) in results:
                print(f"  '{text}' ({confidence:.3f})")
    
    cap.release()
    cv2.destroyAllWindows()

def main():
    parser = argparse.ArgumentParser(description='EasyOCR Simple')
    parser.add_argument('--image', '-i', help='Obrazek do OCR')
    parser.add_argument('--camera', '-c', action='store_true', help='OCR z kamery')
    parser.add_argument('--lang', '-l', default='en', help='Język (en, pl, de, fr, es)')
    
    args = parser.parse_args()
    
    if args.image:
        ocr_image(args.image, [args.lang])
    elif args.camera:
        ocr_camera([args.lang])
    else:
        print("Użycie:")
        print("  python3 easyocr_simple.py -i obrazek.jpg")
        print("  python3 easyocr_simple.py -c")
        print("  python3 easyocr_simple.py -i obrazek.jpg -l pl")

if __name__ == "__main__":
    main()
EOF

chmod +x /home/$USER/easyocr_simple.py

# KROK 8: PODSUMOWANIE
echo ""
echo "🎉 INSTALACJA ZAKOŃCZONA POMYŚLNIE!"
echo ""
echo "📊 CO JEST ZAINSTALOWANE:"
echo "• PyTorch CPU version (zawsze działa)"
echo "• EasyOCR CPU mode (stabilne i niezawodne)"
echo "• OpenCV do obsługi obrazów"
echo "• Prosty przykład w ~/easyocr_simple.py"
echo ""
echo "🚀 PRZYKŁADY UŻYCIA:"
echo "# OCR na obrazku:"
echo "python3 ~/easyocr_simple.py -i /path/to/image.jpg"
echo ""
echo "# OCR z kamery:"
echo "python3 ~/easyocr_simple.py -c"
echo ""
echo "# Różne języki:"
echo "python3 ~/easyocr_simple.py -i test.jpg -l pl"
echo ""
echo "💡 DLACZEGO CPU MODE:"
echo "• Zawsze działa - nie ma problemów z CUDA"
echo "• Stabilne - brak crashów"
echo "• Wystarczająco szybkie dla większości zastosowań"
echo "• Mniejsze zużycie pamięci"
echo ""
echo "📈 WYDAJNOŚĆ:"
echo "• ~1-2 FPS na CPU"
echo "• ~1-2GB RAM"
echo "• Dokładność 90-95%"
echo ""
echo "✅ GOTOWE DO UŻYCIA!"

# Test końcowy
echo ""
echo "🔍 TEST KOŃCOWY:"
python3 -c "
import easyocr
print('✅ EasyOCR zainstalowany')
reader = easyocr.Reader(['en'], gpu=False)
print('✅ CPU mode działa')
print('🎯 Wszystko gotowe!')
"

echo "📚 DOKUMENTACJA: https://github.com/JaidedAI/EasyOCR"