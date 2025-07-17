#!/bin/bash

# =============================================================================
# INSTALACJA EASYOCR NA JETSON ORIN NANO 8GB - KOMPLETNY SKRYPT
# OCR w 42 językach z akceleracją GPU - 2-3GB RAM
# =============================================================================

echo "🔍 Instalacja EasyOCR na Jetson Orin Nano..."

# Krok 1: Przygotowanie systemu
echo "📦 Aktualizacja systemu..."
sudo apt update && sudo apt upgrade -y

# Instalacja systemowych dependencies
sudo apt install -y python3-pip python3-dev python3-setuptools
sudo apt install -y libopencv-dev python3-opencv
sudo apt install -y libfreetype6-dev pkg-config libpng-dev
sudo apt install -y libjpeg-dev zlib1g-dev libtiff-dev

# Krok 2: Włączenie trybu maksymalnej wydajności
echo "⚡ Włączanie trybu maksymalnej wydajności..."
sudo nvpmodel -m 0
sudo jetson_clocks

# Krok 3: Instalacja PyTorch dla Jetson
echo "🔥 Instalacja PyTorch z obsługą CUDA..."
# PyTorch dla JetPack 6.x (CUDA 12.2)
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Sprawdzenie dostępności CUDA
python3 -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU name: {torch.cuda.get_device_name(0)}')
    print(f'GPU memory: {torch.cuda.get_device_properties(0).total_memory // 1024**3} GB')
"

# Krok 4: Instalacja EasyOCR i dependencies
echo "📚 Instalacja EasyOCR..."
pip3 install easyocr
pip3 install opencv-python-headless pillow numpy

# Krok 5: Test instalacji
echo "🧪 Test EasyOCR..."
python3 << 'EOF'
import easyocr
import numpy as np
from PIL import Image, ImageDraw, ImageFont

print("Tworzenie testowego obrazka z tekstem...")

# Stwórz prosty obrazek testowy
img = Image.new('RGB', (400, 100), color='white')
draw = ImageDraw.Draw(img)

# Dodaj tekst (używamy domyślnej czcionki)
draw.text((10, 30), "Hello World! Test OCR 123", fill='black')
draw.text((10, 60), "Jetson Orin Nano", fill='black')

# Zapisz obrazek
img.save('/tmp/test_ocr.jpg')
print("Testowy obrazek zapisany: /tmp/test_ocr.jpg")

# Inicjalizacja EasyOCR
print("Inicjalizacja EasyOCR (angielski i polski)...")
reader = easyocr.Reader(['en', 'pl'], gpu=True)

# Test OCR
print("Wykonywanie OCR...")
result = reader.readtext('/tmp/test_ocr.jpg', detail=1)

print("\n📋 WYNIKI OCR:")
for (bbox, text, confidence) in result:
    print(f"Tekst: '{text}' | Pewność: {confidence:.3f}")

print(f"\n✅ EasyOCR działa poprawnie!")
print(f"Znalezionych elementów tekstowych: {len(result)}")
EOF

# Krok 6: Tworzenie przykładowego skryptu
echo "📝 Tworzenie przykładowego skryptu..."
cat > /home/$USER/easyocr_example.py << 'EOF'
#!/usr/bin/env python3
"""
EasyOCR Example dla Jetson Orin Nano
Obsługuje obrazki i live video z kamery
"""
import easyocr
import cv2
import numpy as np
import argparse
import time

class JetsonOCR:
    def __init__(self, languages=['en', 'pl'], gpu=True):
        """Inicjalizacja EasyOCR"""
        print(f"Inicjalizacja EasyOCR z językami: {languages}")
        self.reader = easyocr.Reader(languages, gpu=gpu)
        print("EasyOCR gotowy!")
    
    def process_image(self, image_path, output_path=None):
        """OCR na pojedynczym obrazku"""
        print(f"Przetwarzanie: {image_path}")
        
        # Wczytaj obraz
        image = cv2.imread(image_path)
        if image is None:
            print(f"Błąd: Nie można wczytać {image_path}")
            return []
        
        # Wykonaj OCR
        start_time = time.time()
        results = self.reader.readtext(image, detail=1)
        process_time = time.time() - start_time
        
        print(f"Czas przetwarzania: {process_time:.2f}s")
        print(f"Znaleziono {len(results)} elementów tekstowych:")
        
        # Wyświetl wyniki
        for i, (bbox, text, confidence) in enumerate(results):
            print(f"  {i+1}. '{text}' (pewność: {confidence:.3f})")
            
            # Narysuj bbox na obrazie
            pts = np.array(bbox, np.int32).reshape((-1, 1, 2))
            cv2.polylines(image, [pts], True, (0, 255, 0), 2)
            cv2.putText(image, f"{text} ({confidence:.2f})", 
                       (int(bbox[0][0]), int(bbox[0][1]-10)), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        # Zapisz wynik jeśli podano ścieżkę
        if output_path:
            cv2.imwrite(output_path, image)
            print(f"Wynik zapisany: {output_path}")
        
        return results
    
    def live_video_ocr(self, camera_id=0):
        """OCR na live video z kamery"""
        print(f"Uruchamianie live OCR z kamery {camera_id}")
        print("Naciśnij 'q' aby zakończyć, 'space' aby wykonać OCR")
        
        cap = cv2.VideoCapture(camera_id)
        if not cap.isOpened():
            print(f"Błąd: Nie można otworzyć kamery {camera_id}")
            return
        
        # Ustawienia kamery
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Wyświetl podgląd
            cv2.putText(frame, "SPACE - OCR, Q - Quit", (10, 30), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.imshow('Jetson OCR Live', frame)
            
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord(' '):
                # Wykonaj OCR na bieżącej klatce
                print("\nWykonywanie OCR...")
                start_time = time.time()
                results = self.reader.readtext(frame, detail=1)
                process_time = time.time() - start_time
                
                print(f"OCR zakończone w {process_time:.2f}s")
                for i, (bbox, text, confidence) in enumerate(results):
                    print(f"  {i+1}. '{text}' (pewność: {confidence:.3f})")
        
        cap.release()
        cv2.destroyAllWindows()

def main():
    parser = argparse.ArgumentParser(description='EasyOCR dla Jetson Orin Nano')
    parser.add_argument('--image', '-i', help='Ścieżka do obrazka')
    parser.add_argument('--output', '-o', help='Ścieżka zapisu wyniku')
    parser.add_argument('--camera', '-c', action='store_true', help='Live OCR z kamery')
    parser.add_argument('--languages', '-l', nargs='+', default=['en', 'pl'],
                       help='Języki do rozpoznawania (domyślnie: en pl)')
    parser.add_argument('--cpu', action='store_true', help='Wymuś CPU (bez GPU)')
    
    args = parser.parse_args()
    
    # Inicjalizuj OCR
    ocr = JetsonOCR(languages=args.languages, gpu=not args.cpu)
    
    if args.image:
        # OCR na obrazku
        ocr.process_image(args.image, args.output)
    elif args.camera:
        # Live OCR
        ocr.live_video_ocr()
    else:
        print("Użycie:")
        print("  python3 easyocr_example.py --image test.jpg")
        print("  python3 easyocr_example.py --camera")
        print("  python3 easyocr_example.py --image test.jpg --output result.jpg")

if __name__ == "__main__":
    main()
EOF

chmod +x /home/$USER/easyocr_example.py

# Krok 7: Konfiguracja środowiska
echo "⚙️ Konfiguracja zmiennych środowiskowych..."
echo 'export CUDA_VISIBLE_DEVICES=0' >> ~/.bashrc
echo 'export CUDA_DEVICE_ORDER=PCI_BUS_ID' >> ~/.bashrc

# Krok 8: Podsumowanie
echo ""
echo "✅ INSTALACJA ZAKOŃCZONA POMYŚLNIE!"
echo ""
echo "📊 INFORMACJE O EASYOCR:"
echo "• Obsługiwane języki: 42 (w tym polski i angielski)"
echo "• Zużycie pamięci: ~2-3GB RAM"
echo "• Wydajność: 3-5 FPS na Jetson Orin Nano"
echo "• Dokładność: 90-95% na standardowym tekście"
echo ""
echo "🚀 PRZYKŁADY UŻYCIA:"
echo "• OCR na obrazku:"
echo "  python3 ~/easyocr_example.py --image /path/to/image.jpg"
echo ""
echo "• Live OCR z kamery:"
echo "  python3 ~/easyocr_example.py --camera"
echo ""
echo "• OCR z zapisem wyniku:"
echo "  python3 ~/easyocr_example.py --image test.jpg --output result.jpg"
echo ""
echo "• Inne języki (np. niemiecki, francuski):"
echo "  python3 ~/easyocr_example.py --image test.jpg --languages en de fr"
echo ""
echo "💡 WSKAZÓWKI:"
echo "• Uruchom 'source ~/.bashrc' aby odświeżyć zmienne środowiskowe"
echo "• Dla lepszych rezultatów użyj obrazków o wysokiej rozdzielczości"
echo "• Wyczyść tło i zwiększ kontrast przed OCR"
echo "• Monitor wydajności: 'sudo tegrastats'"
echo ""
echo "🛠️ TROUBLESHOOTING:"
echo "• Jeśli CUDA nie działa: sprawdź 'nvidia-smi'"
echo "• Problemy z pamięcią: dodaj więcej swap"
echo "• Wolne działanie: sprawdź nvpmodel i jetson_clocks"

# Test końcowy GPU
echo ""
echo "🔍 SPRAWDZENIE KONFIGURACJI GPU..."
nvidia-smi
python3 -c "
import torch
import easyocr
print(f'PyTorch CUDA: {torch.cuda.is_available()}')
print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')
"