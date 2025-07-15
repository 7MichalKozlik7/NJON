#!/bin/bash
set -e
echo "[Test] Tworzenie kompleksowego testu środowiska..."

cat > ~/test_installation.py << 'EOF'
#!/usr/bin/env python3
import sys
import subprocess
import os

# Kolory dla lepszej czytelności
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
        status = f"{Colors.GREEN}✓{Colors.ENDC}"
        print(f"{status} {module_name:<20}", end="")
        
        if test_func:
            result = test_func(module)
            if result:
                print(f" [{Colors.YELLOW}{result}{Colors.ENDC}]")
            else:
                print()
        else:
            # Próba pobrania wersji
            version = getattr(module, '__version__', 'N/A')
            if version != 'N/A':
                print(f" [{Colors.YELLOW}v{version}{Colors.ENDC}]")
            else:
                print()
        return True
    except ImportError as e:
        status = f"{Colors.RED}✗{Colors.ENDC}"
        print(f"{status} {module_name:<20} - {Colors.RED}ERROR: {e}{Colors.ENDC}")
        return False

def test_torch(torch):
    info = []
    info.append(f"v{torch.__version__}")
    if torch.cuda.is_available():
        info.append(f"CUDA: {torch.version.cuda}")
        info.append(f"GPU: {torch.cuda.get_device_name(0)}")
        info.append(f"Count: {torch.cuda.device_count()}")
    else:
        info.append("CPU only")
    return ", ".join(info)

def test_tensorflow(tf):
    info = []
    info.append(f"v{tf.__version__}")
    gpus = tf.config.list_physical_devices('GPU')
    if gpus:
        info.append(f"GPU: {len(gpus)} device(s)")
        for gpu in gpus:
            info.append(gpu.name.split(':')[-1])
    else:
        info.append("CPU only")
    return ", ".join(info)

def test_cv2(cv2):
    info = []
    info.append(f"v{cv2.__version__}")
    try:
        cuda_count = cv2.cuda.getCudaEnabledDeviceCount()
        if cuda_count > 0:
            info.append(f"CUDA: {cuda_count} device(s)")
            info.append(f"Compute: {cv2.cuda.getDevice()}")
        else:
            info.append("CPU only")
    except:
        info.append("No CUDA support")
    return ", ".join(info)

def test_command(cmd_name, version_arg="--version"):
    try:
        result = subprocess.run([cmd_name, version_arg], 
                              capture_output=True, 
                              text=True, 
                              timeout=5)
        if result.returncode == 0:
            version = result.stdout.strip().split('\n')[0]
            status = f"{Colors.GREEN}✓{Colors.ENDC}"
            print(f"{status} {cmd_name:<20} - {Colors.YELLOW}{version}{Colors.ENDC}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    
    status = f"{Colors.RED}✗{Colors.ENDC}"
    print(f"{status} {cmd_name:<20} - {Colors.RED}NOT FOUND{Colors.ENDC}")
    return False

def check_gpu():
    print_header("GPU Status")
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total,driver_version,compute_cap', 
                               '--format=csv,noheader'], 
                               capture_output=True, text=True)
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                parts = line.split(', ')
                print(f"{Colors.GREEN}GPU:{Colors.ENDC} {parts[0]}")
                print(f"  Memory: {parts[1]}")
                print(f"  Driver: {parts[2]}")
                print(f"  Compute: {parts[3]}")
        else:
            print(f"{Colors.RED}nvidia-smi not available{Colors.ENDC}")
    except:
        print(f"{Colors.RED}Error checking GPU{Colors.ENDC}")

def check_jetson_stats():
    print_header("Jetson Configuration")
    
    # JetPack version
    try:
        result = subprocess.run(['dpkg', '-l', 'nvidia-jetpack'], 
                               capture_output=True, text=True)
        for line in result.stdout.split('\n'):
            if line.startswith('ii'):
                version = line.split()[2]
                print(f"JetPack: {Colors.YELLOW}{version}{Colors.ENDC}")
                break
    except:
        pass
    
    # Power mode
    try:
        result = subprocess.run(['nvpmodel', '-q'], capture_output=True, text=True)
        for line in result.stdout.split('\n'):
            if 'NV Power Mode' in line:
                mode = line.split(':')[-1].strip()
                print(f"Power Mode: {Colors.YELLOW}{mode}{Colors.ENDC}")
                break
    except:
        pass
    
    # Clocks status
    try:
        result = subprocess.run(['jetson_clocks', '--show'], 
                               capture_output=True, text=True)
        if 'MAX' in result.stdout:
            print(f"Clocks: {Colors.GREEN}MAXED{Colors.ENDC}")
        else:
            print(f"Clocks: {Colors.YELLOW}Default{Colors.ENDC}")
    except:
        pass

def main():
    print_header("NJON Jetson Installation Verification")
    
    # System info
    print(f"\nSystem: {Colors.YELLOW}{os.uname().nodename}{Colors.ENDC}")
    print(f"Architecture: {Colors.YELLOW}{os.uname().machine}{Colors.ENDC}")
    
    # GPU check
    check_gpu()
    
    # Jetson specific
    check_jetson_stats()
    
    # Python modules
    print_header("Python ML/AI Libraries")
    
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
    
    ml_success = 0
    for module_name, test_func in ml_tests:
        if test_import(module_name, test_func):
            ml_success += 1
    
    # System tools
    print_header("System Tools & Frameworks")
    
    tools = [
        ('nvcc', '--version'),
        ('docker', '--version'),
        ('ros2', '--version'),
        ('ollama', '--version'),
        ('cmake', '--version'),
        ('ninja', '--version'),
    ]
    
    tools_success = 0
    for tool, arg in tools:
        if test_command(tool, arg):
            tools_success += 1
    
    # Docker containers
    print_header("Docker Containers")
    try:
        result = subprocess.run(['docker', 'ps', '--format', 'table {{.Names}}\t{{.Status}}'], 
                               capture_output=True, text=True)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.YELLOW}Docker not running or no containers{Colors.ENDC}")
    except:
        print(f"{Colors.RED}Docker not available{Colors.ENDC}")
    
    # Summary
    print_header("Summary")
    total_ml = len(ml_tests)
    total_tools = len(tools)
    
    ml_percent = (ml_success / total_ml) * 100
    tools_percent = (tools_success / total_tools) * 100
    
    print(f"Python Libraries: {Colors.GREEN if ml_percent == 100 else Colors.YELLOW}"
          f"{ml_success}/{total_ml} ({ml_percent:.0f}%){Colors.ENDC}")
    print(f"System Tools: {Colors.GREEN if tools_percent == 100 else Colors.YELLOW}"
          f"{tools_success}/{total_tools} ({tools_percent:.0f}%){Colors.ENDC}")
    
    if ml_percent == 100 and tools_percent == 100:
        print(f"\n{Colors.GREEN}{Colors.BOLD}🎉 All components verified successfully!{Colors.ENDC}")
    else:
        print(f"\n{Colors.YELLOW}⚠️  Some components are missing. Run njon.sh to install.{Colors.ENDC}")
    
    # Quick test snippet
    print_header("Quick GPU Test")
    print("Running PyTorch CUDA test...")
    try:
        import torch
        if torch.cuda.is_available():
            x = torch.randn(1000, 1000).cuda()
            y = torch.randn(1000, 1000).cuda()
            z = torch.matmul(x, y)
            print(f"{Colors.GREEN}✓ CUDA computation successful!{Colors.ENDC}")
            print(f"  Result shape: {z.shape}")
            print(f"  Device: {z.device}")
        else:
            print(f"{Colors.YELLOW}CUDA not available for PyTorch{Colors.ENDC}")
    except Exception as e:
        print(f"{Colors.RED}Error: {e}{Colors.ENDC}")

if __name__ == "__main__":
    main()
EOF

chmod +x ~/test_installation.py
echo "[Test] ✅ Skrypt testowy utworzony: ~/test_installation.py"
echo "[Test] 🚀 Uruchamiam test..."
echo
python3 ~/test_installation.py