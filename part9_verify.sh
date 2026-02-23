#!/bin/bash
set -euo pipefail

echo "[Test] Tworzenie skryptu weryfikacyjnego..."

TEST_FILE="${HOME}/test_installation.py"

cat > "$TEST_FILE" << 'PYEOF'
#!/usr/bin/env python3
"""NJON - Skrypt weryfikacyjny srodowiska Jetson Orin"""

import sys
import subprocess
import os

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text:^60}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.ENDC}")

def test_import(module_name, test_func=None):
    try:
        module = __import__(module_name)
        status = f"{Colors.GREEN}OK{Colors.ENDC}"
        print(f"  {status}  {module_name:<20}", end="")

        if test_func:
            result = test_func(module)
            if result:
                print(f" [{Colors.YELLOW}{result}{Colors.ENDC}]")
            else:
                print()
        else:
            version = getattr(module, '__version__', '')
            if version:
                print(f" [{Colors.YELLOW}v{version}{Colors.ENDC}]")
            else:
                print()
        return True
    except ImportError as e:
        status = f"{Colors.RED}BRAK{Colors.ENDC}"
        print(f"  {status} {module_name:<20} - {Colors.RED}{e}{Colors.ENDC}")
        return False
    except Exception as e:
        status = f"{Colors.YELLOW}BLAD{Colors.ENDC}"
        print(f"  {status} {module_name:<20} - {Colors.YELLOW}{e}{Colors.ENDC}")
        return False

def test_torch(torch):
    info = [f"v{torch.__version__}"]
    if torch.cuda.is_available():
        info.append(f"CUDA: {torch.version.cuda}")
        info.append(f"GPU: {torch.cuda.get_device_name(0)}")
    else:
        info.append("CPU only")
    return ", ".join(info)

def test_tensorflow(tf):
    info = [f"v{tf.__version__}"]
    gpus = tf.config.list_physical_devices('GPU')
    if gpus:
        info.append(f"GPU: {len(gpus)} device(s)")
    else:
        info.append("CPU only")
    return ", ".join(info)

def test_cv2(cv2):
    info = [f"v{cv2.__version__}"]
    try:
        cuda_count = cv2.cuda.getCudaEnabledDeviceCount()
        if cuda_count > 0:
            info.append(f"CUDA: {cuda_count} device(s)")
        else:
            info.append("CPU only")
    except Exception:
        info.append("No CUDA support")
    return ", ".join(info)

def test_command(cmd_name, version_arg="--version"):
    try:
        result = subprocess.run(
            [cmd_name, version_arg],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            version = result.stdout.strip().split('\n')[0]
            print(f"  {Colors.GREEN}OK{Colors.ENDC}  {cmd_name:<20} - {Colors.YELLOW}{version}{Colors.ENDC}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    print(f"  {Colors.RED}BRAK{Colors.ENDC} {cmd_name:<20}")
    return False

def check_gpu():
    print_header("GPU Status")
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=name,memory.total,driver_version,compute_cap',
             '--format=csv,noheader'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                parts = [p.strip() for p in line.split(',')]
                if len(parts) >= 4:
                    print(f"  GPU:     {parts[0]}")
                    print(f"  Memory:  {parts[1]}")
                    print(f"  Driver:  {parts[2]}")
                    print(f"  Compute: {parts[3]}")
        else:
            print(f"  {Colors.YELLOW}nvidia-smi zwrocil blad{Colors.ENDC}")
    except Exception as e:
        print(f"  {Colors.RED}Blad sprawdzania GPU: {e}{Colors.ENDC}")

def check_jetson_stats():
    print_header("Konfiguracja Jetson")

    # JetPack
    try:
        result = subprocess.run(['dpkg', '-l', 'nvidia-jetpack'],
                                capture_output=True, text=True, timeout=10)
        for line in result.stdout.split('\n'):
            if line.startswith('ii'):
                version = line.split()[2]
                print(f"  JetPack: {Colors.YELLOW}{version}{Colors.ENDC}")
                break
    except Exception:
        pass

    # Power mode
    try:
        result = subprocess.run(['nvpmodel', '-q'],
                                capture_output=True, text=True, timeout=10)
        for line in result.stdout.split('\n'):
            if 'NV Power Mode' in line:
                mode = line.split(':')[-1].strip()
                print(f"  Power Mode: {Colors.YELLOW}{mode}{Colors.ENDC}")
                break
    except Exception:
        pass

    # Clocks
    try:
        result = subprocess.run(['jetson_clocks', '--show'],
                                capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"  Clocks: {Colors.GREEN}Active{Colors.ENDC}")
        else:
            print(f"  Clocks: {Colors.YELLOW}Default{Colors.ENDC}")
    except Exception:
        pass

def main():
    print_header("NJON - Weryfikacja instalacji Jetson")

    print(f"\n  System: {Colors.YELLOW}{os.uname().nodename}{Colors.ENDC}")
    print(f"  Arch:   {Colors.YELLOW}{os.uname().machine}{Colors.ENDC}")

    check_gpu()
    check_jetson_stats()

    # Python modules
    print_header("Biblioteki Python ML/AI")

    ml_tests = [
        ('numpy', None),
        ('torch', test_torch),
        ('torchvision', None),
        ('tensorflow', test_tensorflow),
        ('cv2', test_cv2),
        ('sklearn', None),
        ('pandas', None),
        ('matplotlib', None),
        ('onnxruntime', None),
        ('ultralytics', None),
    ]

    ml_success = sum(1 for name, func in ml_tests if test_import(name, func))

    # System tools
    print_header("Narzedzia systemowe")

    tools = [
        ('nvcc', '--version'),
        ('docker', '--version'),
        ('ros2', '--version'),
        ('ollama', '--version'),
        ('cmake', '--version'),
        ('ninja', '--version'),
    ]

    tools_success = sum(1 for tool, arg in tools if test_command(tool, arg))

    # Docker containers
    print_header("Kontenery Docker")
    try:
        result = subprocess.run(
            ['docker', 'ps', '--format', 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            print(result.stdout)
        else:
            print(f"  {Colors.YELLOW}Brak uruchomionych kontenerow{Colors.ENDC}")
    except Exception:
        print(f"  {Colors.RED}Docker nie dostepny{Colors.ENDC}")

    # Summary
    print_header("Podsumowanie")
    total_ml = len(ml_tests)
    total_tools = len(tools)

    ml_pct = (ml_success / total_ml) * 100
    tools_pct = (tools_success / total_tools) * 100

    ml_color = Colors.GREEN if ml_pct == 100 else Colors.YELLOW
    tools_color = Colors.GREEN if tools_pct == 100 else Colors.YELLOW

    print(f"  Python:  {ml_color}{ml_success}/{total_ml} ({ml_pct:.0f}%){Colors.ENDC}")
    print(f"  Tools:   {tools_color}{tools_success}/{total_tools} ({tools_pct:.0f}%){Colors.ENDC}")

    if ml_pct == 100 and tools_pct == 100:
        print(f"\n  {Colors.GREEN}{Colors.BOLD}Wszystkie komponenty zweryfikowane!{Colors.ENDC}")
    else:
        print(f"\n  {Colors.YELLOW}Niektore komponenty brakuja. Uruchom njon.sh aby zainstalowac.{Colors.ENDC}")

    # GPU test
    print_header("Test GPU (PyTorch CUDA)")
    try:
        import torch
        if torch.cuda.is_available():
            x = torch.randn(500, 500, device='cuda')
            y = torch.randn(500, 500, device='cuda')
            z = torch.matmul(x, y)
            print(f"  {Colors.GREEN}OK - Obliczenia CUDA pomyslne!{Colors.ENDC}")
            print(f"  Wynik: {z.shape}, device: {z.device}")
            del x, y, z
            torch.cuda.empty_cache()
        else:
            print(f"  {Colors.YELLOW}CUDA niedostepna dla PyTorch{Colors.ENDC}")
    except ImportError:
        print(f"  {Colors.YELLOW}PyTorch nie zainstalowany{Colors.ENDC}")
    except Exception as e:
        print(f"  {Colors.RED}Blad: {e}{Colors.ENDC}")

if __name__ == "__main__":
    main()
PYEOF

chmod +x "$TEST_FILE"
echo "[Test] Skrypt testowy utworzony: $TEST_FILE"
echo "[Test] Uruchamiam test..."
echo
python3 "$TEST_FILE" || echo "[Test] UWAGA: Niektore testy nie przeszly (to normalne jesli nie wszystko zainstalowane)"
