# NJON - Jetson Orin AI/ML Installer v2.0

Kompletny, modularny instalator srodowiska AI/ML dla NVIDIA Jetson Orin z JetPack 6.2.1.

## Wymagania

- NVIDIA Jetson Orin (Nano/NX/AGX)
- JetPack 6.2.1 (Ubuntu 22.04)
- Minimum 20GB wolnego miejsca na dysku
- Polaczenie internetowe
- (Opcjonalnie) SSD NVMe dla migracji systemu

## Komponenty

| # | Komponent | Opis |
|---|-----------|------|
| 1 | SWAP | Rozszerzenie pamieci wirtualnej (konfigurowalne) |
| 2 | JetPack SDK + CUDA | NVIDIA SDK i CUDA 12.6 |
| 3 | Narzedzia developerskie | build-essential, cmake, git, python3 etc. |
| 4 | PyTorch, TensorFlow, ONNX | Frameworki ML z obsluga GPU |
| 5 | OpenCV z CUDA | Kompilacja ze zrodel (~2-4h) |
| 6 | ROS2 Humble | Robot Operating System |
| 7 | DeepStream | Framework do analizy wideo NVIDIA |
| 8 | Optymalizacja Jetsona | Tryb zasilania, jetson_clocks |
| 9 | Test i weryfikacja | Skrypt testowy srodowiska |
| 10 | Ollama | Backend dla lokalnych LLM |
| 11 | Docker + NVIDIA Container | Konteneryzacja z GPU |
| 12 | OpenWebUI | Interfejs webowy dla LLM |
| 13 | Poprawka Snapd | Stabilna wersja dla Jetsona |
| 14 | Przegladarki | Chromium i Firefox |
| 15 | Migracja na SSD | Przeniesienie systemu na NVMe |
| 16 | Czyszczenie i konfiguracja | Optymalizacja, aliasy, raport |

## Instalacja

### 1. Klonowanie repozytorium
```bash
git clone https://github.com/7MichalKozlik7/njon.git
cd njon
chmod +x njon.sh parts/*.sh
```

### 2. Uruchomienie
```bash
./njon.sh
```

Instalator automatycznie:
1. Wykrywa platforme Jetson i parametry systemu
2. Uruchamia **wizard konfiguracyjny** zbierajacy wszystkie parametry
3. Wykrywa juz zainstalowane komponenty
4. Pozwala wybrac co zainstalowac

### 3. Opcje uruchomienia
```bash
./njon.sh              # Tryb interaktywny
./njon.sh -v           # Tryb debug (verbose)
./njon.sh -c njon.conf # Uzyj zapisanej konfiguracji
./njon.sh -y           # Tryb nieinteraktywny (domyslne wartosci)
```

## Wizard konfiguracyjny

Instalator zbiera WSZYSTKIE parametry przed instalacja:

| Parametr | Domyslna | Opis |
|----------|----------|------|
| SWAP Size | 16GB | Rozmiar pamieci wirtualnej (4-64GB) |
| CUDA Arch | auto (8.7) | Compute capability GPU |
| Make Jobs | CPU-2 | Watki kompilacji |
| OpenCV Version | 4.10.0 | Wersja OpenCV |
| Power Mode | 0 (MAXN) | Tryb zasilania (0/1/2) |
| ROS2 Domain ID | 0 | Domena ROS2 (0-232) |
| DeepStream Version | 7.1 | Wersja DeepStream |
| Ollama Model | (brak) | Model LLM do pobrania |
| WebUI Port | 3000 | Port OpenWebUI |
| SSD Device | auto | Urzadzenie NVMe do migracji |
| Snapd Revision | 24724 | Rewizja snapd do zamrozenia |

Konfiguracja jest zapisywana do `njon.conf` i moze byc ponownie uzyta.

## Struktura

```
njon/
├── njon.sh              # Glowny instalator z wizardem konfiguracji
├── njon.conf            # Zapisana konfiguracja (generowana)
├── njon_state           # Stan komponentow (generowany)
├── njon.log             # Log instalacji (generowany)
├── README.md
└── parts/
    ├── part1_swap.sh
    ├── part2_jetpack.sh
    ├── part3_devtools.sh
    ├── part4_ml_stack.sh
    ├── part5_opencv.sh
    ├── part6_ros2.sh
    ├── part7_deepstream.sh
    ├── part8_optimize.sh
    ├── part9_verify.sh
    ├── part10_ollama.sh
    ├── part11_docker.sh
    ├── part12_openwebui.sh
    ├── part13_snapd_fix.sh
    ├── part14_browsers.sh
    ├── part15_migrate_to_ssd.sh
    └── part16_cleanup_config.sh
```

## Polecenia po instalacji

```bash
jetson-info          # Informacje o systemie Jetson
jetson-stats         # Monitor systemu (jtop)
gpu-info             # Status GPU (nvidia-smi)
jetson-temp          # Temperatury systemu
jetson-mode          # Aktualny tryb zasilania
jetson-clocks-status # Status zegarow
ml-env               # Aktywacja srodowiska ML
```

## Wazne uwagi

### OpenCV
- Kompilacja trwa 2-4h w zaleznosci od liczby watkow
- Wymaga ~15GB wolnego miejsca podczas kompilacji
- CUDA arch jest konfigurowalne (domyslnie 8.7 dla Orin)

### Migracja na SSD
- Wymaga podlaczonego dysku NVMe
- Wymaga potwierdzenia "TAK"
- Po migracji konieczny restart

### Docker / OpenWebUI
- OpenWebUI: `http://localhost:PORT` (domyslnie 3000)
- Ollama API: `http://localhost:11434`

## Rozwiazywanie problemow

### Sprawdzenie logow
```bash
cat ~/njon.log          # Log instalacji
cat ~/njon_detect.log   # Log detekcji
cat ~/njon_state        # Stan komponentow
```

### Ponowna instalacja komponentu
Uruchom `./njon.sh`, wybierz opcje 3 (reinstalacja) i podaj numer komponentu.

### Problemy z CUDA
```bash
nvcc --version
nvidia-smi
```

### Problemy z PyTorch/TensorFlow
```bash
python3 -c "import torch; print(torch.cuda.is_available())"
python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

## Licencja

MIT License
