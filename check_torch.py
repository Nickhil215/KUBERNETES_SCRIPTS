import torch

print("\n=========== PyTorch Info ===========")
print("PyTorch version:", torch.__version__)

print("\n=========== CPU ===========")
print("CPU available: Yes")

print("\n=========== CUDA (NVIDIA GPU) ===========")
print("CUDA available:", torch.cuda.is_available())
print("CUDA device count:", torch.cuda.device_count())
if torch.cuda.is_available():
    print("CUDA device name:", torch.cuda.get_device_name(0))

print("\n=========== XPU (Intel GPU) ===========")
if hasattr(torch, "xpu"):
    print("XPU module available: Yes")
    try:
        print("XPU available:", torch.xpu.is_available())
        print("XPU device count:", torch.xpu.device_count())
        if torch.xpu.is_available():
            print("XPU device name:", torch.xpu.get_device_name(0))
    except Exception as e:
        print("XPU check error:", e)
else:
    print("XPU module available: No")

print("\n=========== MPS (Apple Silicon) ===========")
try:
    print("MPS available:", torch.backends.mps.is_available())
except Exception as e:
    print("MPS check error:", e)

print("\n=====================================\n")
