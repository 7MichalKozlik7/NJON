# NJON - Jetson Orin AI/ML Installer 🚀

Kompleksowy instalator środowiska AI/ML dla NVIDIA Jetson Orin z JetPack 6.2.1.

## 📋 Wymagania

- NVIDIA Jetson Orin (Nano/NX/AGX)
- JetPack 6.2.1 (Ubuntu 22.04)
- Minimum 20GB wolnego miejsca na dysku
- Połączenie internetowe
- (Opcjonalnie) SSD NVMe dla migracji systemu

## 🎯 Komponenty

NJON instaluje i konfiguruje następujące komponenty:

1. **SWAP 16GB** - Rozszerzenie pamięci wirtualnej
2. **JetPack SDK + CUDA** - NVIDIA SDK i CUDA 12.6
3. **Narzędzia developerskie** - build-essential, cmake, git, etc.
4. **PyTorch, TensorFlow, ONNX** - Frameworki ML z obsługą GPU
5. **OpenCV 4.10.0 z CUDA** - Biblioteka wizji komputerowej (kompilacja ~3h)
6. **ROS2 Humble** - Robot Operating System
7. **DeepStream 7.1** - Framework do analizy wideo
8. **Optymalizacja Jetsona** - Tryb MAXN, jetson_clocks
9. **Test i weryfikacja** - Skrypt testowy środowiska
10. **Ollama** - Backend dla lokalnych LLM
11. **Docker + NVIDIA Container** - Konteneryzacja z GPU
12. **OpenWebUI** - Interfejs webowy dla LLM
13. **Poprawka Snapd** - Stabilna wersja dla Jetsona
14. **Przeglądarki** - Chromium i Firefox
15. **Migracja na SSD** - Przeniesienie systemu na NVMe
16. **Czyszczenie i konfiguracja** - Optymalizacja i aliasy

## 🚀 Instalacja

### 1. Klonowanie repozytorium
```bash
git clone https://github.com/7MichalKozik7/njon.git
cd njon
```

### 2. Struktura katalogów
```
njon/
├── njon.sh                    # Główny skrypt instalatora
├── parts/                     # Katalog ze skryptami części
│   ├── part1_swap.sh
│   ├── part2_jetpack.sh
│   ├── part3_devtools.sh
│   ├── part4_ml_stack.sh
│   ├── part5_opencv.sh
│   ├── part6_ros2.sh
│   ├── part7_deepstream.sh
│   ├── part8_optimize.sh
│   ├── part9_verify.sh
│   ├── part10_ollama.sh
│   ├── part11_docker.sh
│   ├── part12_openwebui.sh
│   ├── part13_snapd_fix.sh
│   ├── part14_browsers.sh
│   ├── part15_migrate_to_ssd.sh
│   └── part16_cleanup_config.sh
└── README.md
```

### 3. Uruchomienie
```bash
chmod +x njon.sh
chmod +x parts/*.sh
./njon.sh
```

## 📖 Użycie

### Instalacja wszystkich brakujących komponentów:
```bash
./njon.sh
# Wybierz: all
```

### Instalacja wybranych komponentów:
```bash
./njon.sh
# Wybierz numery, np: 1 4 5 10
```

### Weryfikacja instalacji:
```bash
python3 ~/test_installation.py
```

## 🛠️ Polecenia pomocnicze

Po instalacji dostępne są następujące aliasy i polecenia:

- `jetson-info` - Informacje o systemie Jetson
- `jetson-stats` - Monitor systemu (jtop)
- `gpu-info` - Status GPU (nvidia-smi)
- `ml-env` - Aktywacja środowiska ML
- `jetson-clocks-status` - Status zegarów
- `jetson-mode` - Aktualny tryb zasilania
- `jetson-temp` - Temperatury systemu

## ⚠️ Uwagi

### OpenCV
- Kompilacja OpenCV trwa około 3 godzin
- Wymaga około 10GB wolnego miejsca podczas kompilacji
- Kompilowane z obsługą CUDA, CUDNN i GStreamer

### Migracja na SSD
- Wymaga podłączonego dysku NVMe jako `/dev/nvme0n1`
- Wykonaj backup przed migracją
- Po migracji konieczny restart

### Docker
- OpenWebUI dostępne pod `http://localhost:3000`
- Ollama API dostępne pod `http://localhost:11434`

## 🔧 Rozwiązywanie problemów

### Brak miejsca na dysku
```bash
# Sprawdź miejsce
df -h
# Wyczyść cache
sudo apt clean
pip3 cache purge
```

### Problemy z CUDA
```bash
# Sprawdź instalację CUDA
nvcc --version
nvidia-smi
# Dodaj ścieżki do .bashrc
echo 'export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
source ~/.bashrc
```

### Problemy z PyTorch/TensorFlow
```bash
# Sprawdź w Pythonie
python3 -c "import torch; print(torch.cuda.is_available())"
python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

## 📝 Logi

- Log instalacji: `~/njon.log`
- Log detekcji: `~/njon_detect.log`
- Stan komponentów: `~/njon_state`
- Raport instalacji: `~/njon_installation_report.txt`

## 🤝 Wsparcie

W przypadku problemów:
1. Sprawdź logi instalacji
2. Uruchom skrypt weryfikacyjny
3. Sprawdź [NVIDIA Developer Forums](https://forums.developer.nvidia.com/)
4. Zgłoś issue w repozytorium

## 📄 Licencja

MIT License
