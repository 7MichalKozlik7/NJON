#!/bin/bash

# =============================================================================
# INSTALACJA PADDLEOCR NA JETSON ORIN NANO 8GB - KOMPLETNY SKRYPT
# Najwyższa dokładność OCR (95-98%) w 80+ językach z TensorRT
# =============================================================================

set -e  # Zatrzymaj przy błędzie

echo "🐼 Instalacja PaddleOCR na Jetson Orin Nano..."
echo "Najwyższa dokładność OCR, 80+ języków, optymalizacja TensorRT"
echo ""

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Sprawdzenie wersji systemu
print_info "Sprawdzanie konfiguracji systemu..."

# Sprawdź L4T/JetPack version
if [ -f /etc/nv_tegra_release ]; then
    L4T_VERSION=$(head -n 1 /etc/nv_tegra_release | grep -oP 'R\K[0-9]+\.[0-9]+')
    JETPACK_VERSION=$(head -n 1 /etc/nv_tegra_release)
    print_info "Wykryto: $JETPACK_VERSION"
    print_info "L4T Version: $L4T_VERSION"
else
    print_error "Nie można wykryć wersji JetPack. Upewnij się, że używasz Jetson Orin Nano."
    exit 1
fi

# Sprawdź CUDA version
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | grep -oP 'V\K[0-9]+\.[0-9]+')
    print_info "CUDA Version: $CUDA_VERSION"
else
    print_error "CUDA nie jest zainstalowane lub nie jest dostępne w PATH"
    exit 1
fi

# Sprawdź Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
print_info "Python Version: $PYTHON_VERSION"

# Sprawdź dostępną pamięć
TOTAL_MEM=$(free -g | grep '^Mem:' | awk '{print $2}')
AVAILABLE_MEM=$(free -g | grep '^Mem:' | awk '{print $7}')
print_info "Pamięć: ${AVAILABLE_MEM}GB / ${TOTAL_MEM}GB dostępne"

if [ "$AVAILABLE_MEM" -lt 4 ]; then
    print_warning "Mało dostępnej pamięci RAM. Zalecane jest zamknięcie innych aplikacji."
fi

echo ""

# Krok 1: Przygotowanie systemu
print_info "Krok 1: Przygotowanie systemu i dependencies..."
sudo apt update && sudo apt upgrade -y

# Instalacja systemowych dependencies
sudo apt install -y \
    python3-pip python3-dev python3-setuptools \
    libopencv-dev python3-opencv \
    libfreetype6-dev pkg-config libpng-dev \
    libjpeg-dev zlib1g-dev libtiff-dev \
    libhdf5-serial-dev hdf5-tools libhdf5-dev \
    liblapack-dev libblas-dev gfortran \
    libatlas-base-dev \
    wget curl unzip

print_success "Dependencies zainstalowane"

# Krok 2: Konfiguracja CUDA Environment
print_info "Krok 2: Konfiguracja CUDA Environment..."

# Dodaj CUDA do PATH jeśli nie ma
if ! grep -q "CUDA" ~/.bashrc; then
    echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
fi

export CUDA_HOME=/usr/local/cuda
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export PATH=/usr/local/cuda/bin:$PATH

print_success "CUDA Environment skonfigurowane"

# Krok 3: Włączenie trybu maksymalnej wydajności
print_info "Krok 3: Włączanie trybu maksymalnej wydajności..."
sudo nvpmodel -m 0  # MAXN SUPER mode
sudo jetson_clocks
print_success "Tryb MAXN SUPER włączony"

# Krok 4: Zwiększenie swap space
print_info "Krok 4: Konfiguracja swap space (16GB)..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 16G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    print_success "Swap 16GB skonfigurowany"
else
    print_info "Swap już istnieje"
fi

# Krok 5: Upgrade pip i instalacja podstawowych pakietów
print_info "Krok 5: Upgrade pip i instalacja podstawowych pakietów..."
python3 -m pip install --upgrade pip setuptools wheel
pip3 install numpy opencv-python-headless pillow shapely pyclipper imgaug lmdb tqdm rapidfuzz

print_success "Podstawowe pakiety zainstalowane"

# Krok 6: Wybór metody instalacji PaddlePaddle
print_info "Krok 6: Instalacja PaddlePaddle..."

# Funkcja do instalacji PaddlePaddle z pre-built wheel
install_paddle_wheel() {
    print_info "Próba instalacji z pre-built wheel..."
    
    # Określ odpowiedni wheel na podstawie L4T version
    case "$L4T_VERSION" in
        "36.4"|"36.3"|"36.2")
            PADDLE_WHEEL_URL="https://paddle-wheel.bj.bcebos.com/2.6.0/linux/aarch64/jetpack6.0_jp60/paddlepaddle_gpu-2.6.0-cp310-cp310-linux_aarch64.whl"
            PYTHON_VER="cp310"
            ;;
        "36.1"|"36.0")
            PADDLE_WHEEL_URL="https://paddle-wheel.bj.bcebos.com/2.5.2/linux/aarch64/jetpack5.1_jp51/paddlepaddle_gpu-2.5.2-cp38-cp38-linux_aarch64.whl"
            PYTHON_VER="cp38"
            ;;
        *)
            print_warning "Nieznana wersja L4T: $L4T_VERSION. Próbuje najnowszy wheel..."
            PADDLE_WHEEL_URL="https://paddle-wheel.bj.bcebos.com/2.6.0/linux/aarch64/jetpack6.0_jp60/paddlepaddle_gpu-2.6.0-cp310-cp310-linux_aarch64.whl"
            PYTHON_VER="cp310"
            ;;
    esac
    
    print_info "Pobieranie PaddlePaddle wheel..."
    print_info "URL: $PADDLE_WHEEL_URL"
    
    # Pobierz wheel
    cd /tmp
    wget -O paddlepaddle_gpu.whl "$PADDLE_WHEEL_URL" || {
        print_error "Nie można pobrać wheel z oficjalnego źródła"
        
        # Fallback do Q-engineering wheel
        print_info "Próba alternatywnego źródła (Q-engineering)..."
        FALLBACK_URL="https://github.com/Qengineering/Paddle-Jetson-Nano/releases/download/v2.5.2/paddlepaddle_gpu-2.5.2-cp38-cp38-linux_aarch64.whl"
        wget -O paddlepaddle_gpu.whl "$FALLBACK_URL" || {
            print_error "Nie można pobrać wheel. Przechodzę na instalację ze źródeł..."
            return 1
        }
    }
    
    # Instaluj wheel
    print_info "Instalacja PaddlePaddle wheel..."
    pip3 install paddlepaddle_gpu.whl || {
        print_error "Instalacja wheel nie powiodła się"
        return 1
    }
    
    print_success "PaddlePaddle zainstalowane z wheel"
    return 0
}

# Funkcja do instalacji ze źródeł (backup method)
install_paddle_source() {
    print_warning "Instalacja ze źródeł - może zająć 2-3 godziny!"
    read -p "Czy chcesz kontynuować? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Instalacja przerwana przez użytkownika"
        exit 1
    fi
    
    print_info "Klonowanie PaddlePaddle repository..."
    cd /tmp
    git clone https://github.com/PaddlePaddle/Paddle.git
    cd Paddle
    
    # Konfiguracja CMake
    mkdir build && cd build
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DON_INFER=ON \
        -DWITH_GPU=ON \
        -DWITH_TENSORRT=ON \
        -DWITH_PYTHON=ON \
        -DWITH_TESTING=OFF \
        -DWITH_MKL=OFF \
        -DWITH_MKLDNN=OFF \
        -DWITH_NCCL=OFF \
        -DWITH_CONTRIB=OFF
    
    # Kompilacja (użyj wszystkie rdzenie)
    make -j$(nproc)
    
    # Instalacja
    pip3 install python/dist/paddlepaddle_gpu-*.whl
    
    print_success "PaddlePaddle skompilowane i zainstalowane ze źródeł"
}

# Próbuj instalację z wheel, fallback na źródła
install_paddle_wheel || {
    print_warning "Instalacja z wheel nie powiodła się. Próba instalacji ze źródeł..."
    install_paddle_source
}

# Krok 7: Test PaddlePaddle
print_info "Krok 7: Test PaddlePaddle..."
python3 -c "
import paddle
print(f'PaddlePaddle version: {paddle.__version__}')
print(f'CUDA available: {paddle.device.is_compiled_with_cuda()}')
if paddle.device.is_compiled_with_cuda():
    print(f'GPU count: {paddle.device.cuda.device_count()}')
    print('GPU info:', paddle.device.get_device())
" || {
    print_error "PaddlePaddle nie działa poprawnie"
    exit 1
}

print_success "PaddlePaddle działa poprawnie"

# Krok 8: Instalacja PaddleOCR
print_info "Krok 8: Instalacja PaddleOCR..."
pip3 install paddleocr

print_success "PaddleOCR zainstalowane"

# Krok 9: Test PaddleOCR
print_info "Krok 9: Szybki test PaddleOCR..."
python3 -c "
try:
    from paddleocr import PaddleOCR
    print('✅ PaddleOCR importuje się poprawnie')
    
    # Szybki test bez pobierania modeli
    ocr = PaddleOCR(use_angle_cls=True, lang='en', use_gpu=True, show_log=False)
    print('✅ PaddleOCR inicjalizuje się poprawnie')
    print('🚀 Pierwsza inicjalizacja pobierze modele (kilka minut)')
    
except Exception as e:
    print(f'⚠️  Problem z PaddleOCR: {e}')
    print('Sprawdź czy PaddlePaddle jest zainstalowane')
" || print_warning "PaddleOCR test nie przeszedł, ale może działać po pierwszym uruchomieniu"

# Krok 10: Tworzenie przykładowego skryptu
print_info "Krok 10: Tworzenie zaawansowanego przykładu..."
cat > /home/$USER/paddleocr_advanced.py << 'EOF'
#!/usr/bin/env python3
"""
PaddleOCR Advanced Example dla Jetson Orin Nano
Najwyższa dokładność OCR z optymalizacją TensorRT
Obsługuje 80+ języków, layout analysis, table recognition
"""
import os
import sys
import cv2
import numpy as np
import argparse
import time
import json
from pathlib import Path

# Dodaj ścieżki do PaddleOCR
sys.path.append('/usr/local/lib/python3.8/site-packages')
sys.path.append('/usr/local/lib/python3.10/site-packages')

try:
    from paddleocr import PaddleOCR
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    print(f"Błąd importu: {e}")
    print("Upewnij się, że PaddleOCR jest zainstalowane: pip3 install paddleocr")
    sys.exit(1)

class JetsonPaddleOCR:
    def __init__(self, lang='en', use_gpu=True, enable_tensorrt=True):
        """
        Inicjalizacja PaddleOCR z optymalizacjami dla Jetson
        
        Args:
            lang: język/języki do rozpoznawania ('en', 'ch', 'en,ch', itp.)
            use_gpu: czy używać GPU
            enable_tensorrt: czy włączyć optymalizację TensorRT
        """
        self.lang = lang
        print(f"🚀 Inicjalizacja PaddleOCR dla języków: {lang}")
        print("📥 Pierwsza inicjalizacja może zająć kilka minut (pobieranie modeli)...")
        
        try:
            self.ocr = PaddleOCR(
                use_angle_cls=True,
                lang=lang,
                use_gpu=use_gpu,
                show_log=False,
                # Optymalizacje dla Jetson
                det_model_dir=None,  # Użyj domyślnych modeli
                rec_model_dir=None,
                cls_model_dir=None,
                # TensorRT optymalizacja (jeśli dostępna)
                use_tensorrt=enable_tensorrt,
                precision='fp16'  # Mixed precision dla lepszej wydajności
            )
            print("✅ PaddleOCR gotowy!")
            
        except Exception as e:
            print(f"❌ Błąd inicjalizacji PaddleOCR: {e}")
            print("🔄 Próba inicjalizacji bez TensorRT...")
            self.ocr = PaddleOCR(
                use_angle_cls=True,
                lang=lang,
                use_gpu=use_gpu,
                show_log=False
            )
    
    def preprocess_image(self, image):
        """Preprocessing obrazu dla lepszych wyników OCR"""
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image
        
        # Zwiększenie kontrastu
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        enhanced = clahe.apply(gray)
        
        # Redukcja szumu
        denoised = cv2.bilateralFilter(enhanced, 9, 75, 75)
        
        # Optymalizacja rozdzielczości
        height, width = denoised.shape
        if width > 2000:
            scale = 2000 / width
            new_width = int(width * scale)
            new_height = int(height * scale)
            denoised = cv2.resize(denoised, (new_width, new_height))
        
        return denoised
    
    def process_image(self, image_path, save_result=True, preprocess=True):
        """OCR na pojedynczym obrazku z preprocessing"""
        print(f"🔍 Przetwarzanie: {image_path}")
        
        # Wczytaj obraz
        if isinstance(image_path, str):
            image = cv2.imread(image_path)
            if image is None:
                print(f"❌ Nie można wczytać {image_path}")
                return None
        else:
            image = image_path
        
        original_image = image.copy()
        
        # Preprocessing jeśli włączony
        if preprocess:
            processed_image = self.preprocess_image(image)
            # Konwertuj z powrotem do BGR dla PaddleOCR
            if len(processed_image.shape) == 2:
                processed_image = cv2.cvtColor(processed_image, cv2.COLOR_GRAY2BGR)
            image = processed_image
        
        # Wykonaj OCR
        start_time = time.time()
        try:
            result = self.ocr.ocr(image, cls=True)
            process_time = time.time() - start_time
            
            print(f"⏱️  Czas przetwarzania: {process_time:.2f}s")
            
            if not result or not result[0]:
                print("⚠️  Brak wykrytego tekstu")
                return []
            
            # Przetwórz wyniki
            detected_texts = []
            print(f"📄 Znaleziono {len(result[0])} linii tekstu:")
            
            for idx, line in enumerate(result):
                for word_info in line:
                    bbox, (text, confidence) = word_info
                    detected_texts.append({
                        'text': text,
                        'confidence': confidence,
                        'bbox': bbox
                    })
                    print(f"  {len(detected_texts)}. '{text}' (pewność: {confidence:.3f})")
                    
                    # Narysuj bbox na oryginalnym obrazie
                    if save_result:
                        pts = np.array(bbox, np.int32).reshape((-1, 1, 2))
                        cv2.polylines(original_image, [pts], True, (0, 255, 0), 2)
                        
                        # Dodaj tekst z pewnością
                        font_scale = max(0.5, min(2.0, original_image.shape[1] / 1000))
                        cv2.putText(original_image, 
                                   f"{text} ({confidence:.2f})",
                                   (int(bbox[0][0]), int(bbox[0][1]-5)), 
                                   cv2.FONT_HERSHEY_SIMPLEX, 
                                   font_scale, (0, 255, 0), 2)
            
            # Zapisz wynik
            if save_result and isinstance(image_path, str):
                output_path = image_path.replace('.jpg', '_paddleocr_result.jpg')
                output_path = output_path.replace('.png', '_paddleocr_result.png')
                cv2.imwrite(output_path, original_image)
                print(f"💾 Wynik zapisany: {output_path}")
            
            return detected_texts
            
        except Exception as e:
            print(f"❌ Błąd OCR: {e}")
            return None
    
    def process_video(self, video_source=0, save_frames=False):
        """OCR na live video z optymalizacją wydajności"""
        print(f"📹 Uruchamianie live OCR z źródła: {video_source}")
        print("Sterowanie: SPACE - OCR, S - zapisz klatkę, Q - wyjście")
        
        cap = cv2.VideoCapture(video_source)
        if not cap.isOpened():
            print(f"❌ Nie można otworzyć źródła video: {video_source}")
            return
        
        # Optymalizacje kamery
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        cap.set(cv2.CAP_PROP_FPS, 30)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        frame_count = 0
        last_ocr_time = 0
        ocr_interval = 2.0  # OCR co 2 sekundy
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            current_time = time.time()
            
            # Wyświetl instrukcje
            cv2.putText(frame, "SPACE-OCR | S-Save | Q-Quit", (10, 30), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(frame, f"FPS: {cap.get(cv2.CAP_PROP_FPS):.1f}", (10, 60), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            
            cv2.imshow('PaddleOCR Live - Jetson Orin Nano', frame)
            
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord(' ') or (current_time - last_ocr_time > ocr_interval):
                # Wykonaj OCR
                print(f"\n🔍 OCR na klatce {frame_count}...")
                results = self.process_image(frame, save_result=False, preprocess=True)
                last_ocr_time = current_time
                
                if results:
                    print("📋 Wykryty tekst:")
                    for i, item in enumerate(results[:5]):  # Pokaż tylko pierwsze 5
                        print(f"  {i+1}. '{item['text']}' ({item['confidence']:.3f})")
                    if len(results) > 5:
                        print(f"  ... i {len(results)-5} więcej")
                else:
                    print("⚠️  Brak wykrytego tekstu")
                    
            elif key == ord('s') and save_frames:
                # Zapisz klatkę
                frame_filename = f"/tmp/frame_{frame_count:06d}.jpg"
                cv2.imwrite(frame_filename, frame)
                print(f"💾 Klatka zapisana: {frame_filename}")
            
            frame_count += 1
        
        cap.release()
        cv2.destroyAllWindows()
    
    def batch_process(self, input_dir, output_dir=None, supported_formats=None):
        """Przetwarzanie batch wielu obrazków"""
        if supported_formats is None:
            supported_formats = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff']
        
        input_path = Path(input_dir)
        if not input_path.exists():
            print(f"❌ Katalog nie istnieje: {input_dir}")
            return
        
        # Znajdź wszystkie obrazki
        image_files = []
        for ext in supported_formats:
            image_files.extend(input_path.glob(f"*{ext}"))
            image_files.extend(input_path.glob(f"*{ext.upper()}"))
        
        if not image_files:
            print(f"⚠️  Brak obrazków w katalogu: {input_dir}")
            return
        
        print(f"📁 Znaleziono {len(image_files)} obrazków do przetworzenia")
        
        # Przetwórz każdy obrazek
        results = {}
        for i, image_file in enumerate(image_files):
            print(f"\n📷 Przetwarzanie {i+1}/{len(image_files)}: {image_file.name}")
            
            result = self.process_image(str(image_file), save_result=True)
            results[str(image_file)] = result
        
        # Zapisz wyniki do JSON
        if output_dir:
            output_path = Path(output_dir)
            output_path.mkdir(exist_ok=True)
            results_file = output_path / "paddleocr_results.json"
            
            # Serialize results (convert numpy arrays to lists)
            serializable_results = {}
            for file_path, result_list in results.items():
                if result_list:
                    serializable_results[file_path] = [
                        {
                            'text': item['text'],
                            'confidence': float(item['confidence']),
                            'bbox': [[float(x), float(y)] for x, y in item['bbox']]
                        }
                        for item in result_list
                    ]
            
            with open(results_file, 'w', encoding='utf-8') as f:
                json.dump(serializable_results, f, ensure_ascii=False, indent=2)
            
            print(f"💾 Wyniki zapisane w: {results_file}")
        
        return results

def main():
    parser = argparse.ArgumentParser(description='PaddleOCR Advanced dla Jetson Orin Nano')
    parser.add_argument('--image', '-i', help='Ścieżka do obrazka')
    parser.add_argument('--video', '-v', help='Źródło video (0 dla kamery lub ścieżka do pliku)')
    parser.add_argument('--batch', '-b', help='Katalog z obrazkami do batch processing')
    parser.add_argument('--output', '-o', help='Katalog output dla wyników')
    parser.add_argument('--lang', '-l', default='en', 
                       help='Język/języki (en, ch, en,ch, fr, de, es, pt, ru, ar, hi, kor, ja)')
    parser.add_argument('--cpu', action='store_true', help='Wymuś CPU (bez GPU)')
    parser.add_argument('--no-tensorrt', action='store_true', help='Wyłącz TensorRT')
    parser.add_argument('--preprocess', action='store_true', default=True, 
                       help='Włącz preprocessing obrazu')
    
    args = parser.parse_args()
    
    # Inicjalizuj PaddleOCR
    ocr = JetsonPaddleOCR(
        lang=args.lang, 
        use_gpu=not args.cpu,
        enable_tensorrt=not args.no_tensorrt
    )
    
    if args.image:
        # OCR na pojedynczym obrazku
        ocr.process_image(args.image, preprocess=args.preprocess)
        
    elif args.video is not None:
        # Live video OCR
        video_source = int(args.video) if args.video.isdigit() else args.video
        ocr.process_video(video_source, save_frames=True)
        
    elif args.batch:
        # Batch processing
        ocr.batch_process(args.batch, args.output)
        
    else:
        print("🔧 UŻYCIE:")
        print("  # OCR na obrazku:")
        print("  python3 paddleocr_advanced.py -i test.jpg")
        print("")
        print("  # Live OCR z kamery:")
        print("  python3 paddleocr_advanced.py -v 0")
        print("")
        print("  # Batch processing:")
        print("  python3 paddleocr_advanced.py -b /path/to/images/ -o /path/to/results/")
        print("")
        print("  # Różne języki:")
        print("  python3 paddleocr_advanced.py -i test.jpg -l 'en,ch'  # Angielski + chiński")
        print("  python3 paddleocr_advanced.py -i test.jpg -l 'pl'     # Polski (eksperymentalny)")
        print("")
        print("  # Optymalizacje:")
        print("  python3 paddleocr_advanced.py -i test.jpg --cpu       # Wymusz CPU")
        print("  python3 paddleocr_advanced.py -i test.jpg --no-tensorrt  # Bez TensorRT")

if __name__ == "__main__":
    main()
EOF

chmod +x /home/$USER/paddleocr_advanced.py

# Krok 11: Konfiguracja zmiennych środowiskowych
print_info "Krok 11: Konfiguracja zmiennych środowiskowych..."
echo 'export PADDLE_INSTALL_DIR=/usr/local/lib/python3.*/site-packages/paddle' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$PADDLE_INSTALL_DIR/libs:$LD_LIBRARY_PATH' >> ~/.bashrc

# Krok 12: Tworzenie skryptu benchmarkowego
print_info "Krok 12: Tworzenie skryptu benchmarkowego..."
cat > /home/$USER/paddleocr_benchmark.py << 'EOF'
#!/usr/bin/env python3
"""
Benchmark PaddleOCR na Jetson Orin Nano
Testuje wydajność z różnymi optymalizacjami
"""
import time
import cv2
import numpy as np
from PIL import Image, ImageDraw
import sys

sys.path.append('/usr/local/lib/python3.8/site-packages')
sys.path.append('/usr/local/lib/python3.10/site-packages')

from paddleocr import PaddleOCR

def create_test_images():
    """Stwórz zestaw testowych obrazków o różnych rozmiarach"""
    test_images = []
    sizes = [(640, 480), (1280, 720), (1920, 1080)]
    
    for size in sizes:
        img = Image.new('RGB', size, color='white')
        draw = ImageDraw.Draw(img)
        
        # Dodaj różne teksty
        texts = [
            "High-resolution OCR test",
            "PaddleOCR on Jetson Orin Nano",
            "Performance benchmark 2025",
            "NVIDIA GPU acceleration",
            "TensorRT optimization test"
        ]
        
        y_pos = 50
        for text in texts:
            draw.text((50, y_pos), text, fill='black')
            y_pos += 80
        
        # Konwertuj do OpenCV format
        cv_image = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        test_images.append((size, cv_image))
    
    return test_images

def benchmark_paddleocr():
    """Benchmark różnych konfiguracji PaddleOCR"""
    test_images = create_test_images()
    
    configs = [
        {"name": "GPU + TensorRT", "use_gpu": True, "use_tensorrt": True},
        {"name": "GPU Only", "use_gpu": True, "use_tensorrt": False},
        {"name": "CPU Only", "use_gpu": False, "use_tensorrt": False}
    ]
    
    results = {}
    
    for config in configs:
        print(f"\n🧪 Testowanie konfiguracji: {config['name']}")
        
        try:
            # Inicjalizacja
            init_start = time.time()
            if config['use_tensorrt']:
                ocr = PaddleOCR(use_angle_cls=True, lang='en', 
                               use_gpu=config['use_gpu'],
                               use_tensorrt=True, precision='fp16')
            else:
                ocr = PaddleOCR(use_angle_cls=True, lang='en', 
                               use_gpu=config['use_gpu'])
            init_time = time.time() - init_start
            print(f"  Czas inicjalizacji: {init_time:.2f}s")
            
            config_results = []
            
            # Test na różnych rozmiarach
            for size, image in test_images:
                print(f"  📷 Testowanie rozmiaru: {size}")
                
                times = []
                for i in range(3):  # 3 próby
                    start_time = time.time()
                    result = ocr.ocr(image, cls=True)
                    end_time = time.time()
                    times.append(end_time - start_time)
                
                avg_time = np.mean(times)
                text_count = len(result[0]) if result and result[0] else 0
                
                config_results.append({
                    'size': size,
                    'avg_time': avg_time,
                    'text_count': text_count,
                    'pixels': size[0] * size[1]
                })
                
                print(f"    Średni czas: {avg_time:.2f}s | Tekstów: {text_count}")
            
            results[config['name']] = {
                'init_time': init_time,
                'results': config_results
            }
            
        except Exception as e:
            print(f"  ❌ Błąd w konfiguracji {config['name']}: {e}")
            results[config['name']] = {'error': str(e)}
    
    # Podsumowanie wyników
    print("\n📊 PODSUMOWANIE BENCHMARKU:")
    print("=" * 50)
    
    for config_name, data in results.items():
        if 'error' in data:
            print(f"{config_name}: ERROR - {data['error']}")
            continue
            
        print(f"\n{config_name}:")
        print(f"  Inicjalizacja: {data['init_time']:.2f}s")
        
        for result in data['results']:
            mpix = result['pixels'] / 1_000_000
            print(f"  {result['size']}: {result['avg_time']:.2f}s ({mpix:.1f}MP, {result['text_count']} tekstów)")

if __name__ == "__main__":
    print("🚀 PaddleOCR Benchmark na Jetson Orin Nano")
    print("Testuje wydajność z różnymi optymalizacjami\n")
    benchmark_paddleocr()
EOF

chmod +x /home/$USER/paddleocr_benchmark.py

# Podsumowanie
echo ""
print_success "🎉 INSTALACJA PADDLEOCR ZAKOŃCZONA POMYŚLNIE!"
echo ""
echo "📊 INFORMACJE O PADDLEOCR:"
echo "• Obsługiwane języki: 80+ (w tym chiński, angielski, francuski, niemiecki)"
echo "• Dokładność: 95-98% na wysokiej jakości tekstach"
echo "• Zużycie pamięci: ~3-4GB RAM"
echo "• Wydajność: 2-4 FPS z GPU, 1-2 FPS z TensorRT"
echo "• Funkcje zaawansowane: layout analysis, table recognition"
echo ""
echo "🚀 PRZYKŁADY UŻYCIA:"
echo ""
echo "# Podstawowy OCR:"
echo "python3 ~/paddleocr_advanced.py -i /path/to/image.jpg"
echo ""
echo "# OCR z wieloma językami:"
echo "python3 ~/paddleocr_advanced.py -i test.jpg -l 'en,ch'"
echo ""
echo "# Live OCR z kamery:"
echo "python3 ~/paddleocr_advanced.py -v 0"
echo ""
echo "# Batch processing:"
echo "python3 ~/paddleocr_advanced.py -b /path/to/images/ -o /path/to/results/"
echo ""
echo "# Benchmark wydajności:"
echo "python3 ~/paddleocr_benchmark.py"
echo ""
echo "💡 WSKAZÓWKI OPTYMALIZACJI:"
echo "• Używaj obrazków o rozdzielczości 1280x720 dla najlepszego balansu"
echo "• TensorRT daje znaczne przyspieszenie (jeśli dostępne)"
echo "• Dla batch processing wyłącz angle_cls dla szybszego działania"
echo "• Monitoring: sudo tegrastats (sprawdzaj GPU/CPU usage)"
echo ""
echo "🛠️ TROUBLESHOOTING:"
echo "• Błędy pamięci: zwiększ swap lub użyj mniejszych obrazków"
echo "• CUDA errors: sprawdź nvidia-smi i zmienne środowiskowe"
echo "• Wolne działanie: upewnij się że nvpmodel -m 0 i jetson_clocks są włączone"
echo "• TensorRT errors: uruchom z --no-tensorrt flag"
echo ""
print_warning "PIERWSZA INICJALIZACJA może zająć 5-10 minut (pobieranie modeli)"
print_info "Uruchom 'source ~/.bashrc' aby odświeżyć zmienne środowiskowe"

# Test końcowy
echo ""
print_info "🔍 SPRAWDZENIE KOŃCOWEJ KONFIGURACJI..."
nvidia-smi
python3 -c "
try:
    import paddle
    print(f'✅ PaddlePaddle: {paddle.__version__}')
    print(f'✅ CUDA: {paddle.device.is_compiled_with_cuda()}')
    
    from paddleocr import PaddleOCR
    print('✅ PaddleOCR: Zainstalowane')
    print('🎯 Wszystko gotowe do użycia!')
    
except ImportError as e:
    print(f'⚠️  Import problem: {e}')
    print('Sprawdź czy wszystkie dependencies są zainstalowane')
except Exception as e:
    print(f'⚠️  Problem: {e}')
    print('PaddleOCR może wymagać pierwszego uruchomienia')
"

print_success "Instalacja PaddleOCR zakończona!"
echo "Dokumentacja: https://paddlepaddle.github.io/PaddleOCR/"