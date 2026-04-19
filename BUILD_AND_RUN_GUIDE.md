# FCW System - Build & Run Guide

## Project Overview
- **Language**: C++ (primary), Python (orchestrator)
- **Inference Backend**: ONNX Runtime 1.17.1
- **Build System**: CMake 4.1.0 with MinGW Makefiles
- **Compiler**: MinGW g++ 15.2.0
- **OpenCV**: 4.5.5 MinGW (MJPG AVI codec)
- **Framework**: YOLOv8s object detection on KITTI/BDD100K datasets

---

## Prerequisites & Setup

### 1. Install Python Environment (First Time Only)
```powershell
cd C:\VScode\KLTN
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install opencv-python torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
pip install ultralytics onnx onnxruntime scipy
```

### 2. Verify Dependencies
```powershell
python -c "import cv2, torch, ultralytics, onnxruntime; print('All imports OK')"
```

### 3. Set Environment Variables (Every Build Session)
```powershell
$env:PATH = "C:\opencv-mingw\x64\mingw\bin;C:\mingw64\bin;C:\VScode\KLTN\onnxruntime\lib;" + $env:PATH
$env:OPENCV_DIR = "C:\opencv-mingw"
$env:ONNXRUNTIME_ROOT = "C:\VScode\KLTN\onnxruntime"
```

---

## Build Process

### 1. Configure CMake
```powershell
cd C:\VScode\KLTN\fcw-system\build

# Clean previous cache
Remove-Item CMakeCache.txt -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force CMakeFiles -ErrorAction SilentlyContinue

# Configure with MinGW
cmake -G "MinGW Makefiles" `
  -DCMAKE_BUILD_TYPE=Release `
  -DOpenCV_DIR="C:\opencv-mingw" `
  -DUSE_TENSORRT=OFF `
  -DUSE_ONNXRUNTIME=ON `
  -DONNXRUNTIME_ROOT="C:\VScode\KLTN\onnxruntime" `
  ..
```

### 2. Build C++ Executable
```powershell
cd C:\VScode\KLTN\fcw-system\build
mingw32-make -j4
```

**Output**: `C:\VScode\KLTN\fcw-system\build\fcw_system.exe` (~750KB)

### 3. Convert YOLOv8 Model (If Needed)
```powershell
cd C:\VScode\KLTN
python -c "
from ultralytics import YOLO
model = YOLO('yolov8s.pt')
model.export(format='onnx', imgsz=640, simplify=True, device=0, opset=11)
"
# Move exported model to fcw-system/models/yolov8s.onnx
Move-Item yolov8s.onnx fcw-system\models\yolov8s.onnx -Force
```

---

## Run Tests

### 1. Run Python Unit Tests
```powershell
cd C:\VScode\KLTN
python -m pytest test_fcw_*.py -v 2>&1 | Tee-Object test_results_latest.txt
```

### 2. Run FCW System Help
```powershell
$env:PATH = "C:\opencv-mingw\x64\mingw\bin;C:\mingw64\bin;C:\VScode\KLTN\onnxruntime\lib;" + $env:PATH
cd C:\VScode\KLTN\fcw-system
.\build\fcw_system.exe --help
```

---

## Run FCW System with Video

### 1. Via Python Orchestrator (Recommended)
```powershell
cd C:\VScode\KLTN
python run_fcw.py
```
**Default behavior**: Uses first available `.avi` in `video_data/`

### 2. Direct C++ Executable (Manual DLL Path)
```powershell
$env:PATH = "C:\opencv-mingw\x64\mingw\bin;C:\mingw64\bin;C:\VScode\KLTN\onnxruntime\lib;" + $env:PATH
cd C:\VScode\KLTN\fcw-system
.\build\fcw_system.exe --video "C:\VScode\KLTN\video_data\kitti_video_03_2011_09_26.avi"
```

### 3. Video File Options
Available test videos in `C:\VScode\KLTN\video_data\`:

| Video | Frames | Duration | Size |
|-------|--------|----------|------|
| kitti_video_01_2011_09_26.avi | 108 | 10.8s | 11.2 MB |
| kitti_video_02_2011_09_26.avi | 160 | 16.0s | 13.6 MB |
| **kitti_video_03_2011_09_26.avi** | 234 | 23.4s | 22.5 MB |
| kitti_video_04_2011_09_26.avi | 207 | 20.7s | 17.5 MB |
| kitti_video_30-53_*.avi | 22-1059 | 2.2-105.9s | 1.6-95.7 MB |

**Performance**: ~6-7 FPS with ONNX Runtime inference on CPU

### 4. Using Camera (Live)
```powershell
.\build\fcw_system.exe --camera 0
```

---

## Output Files

### After Running FCW System:
- **Logs**: `C:\VScode\KLTN\fcw-system\results\logs\system.log`
- **Debug Trace**: `C:\VScode\KLTN\fcw-system\debug_trace.txt`
- **Video Output** (optional): `C:\VScode\KLTN\fcw-system\results\videos\output.avi`
- **Metadata**: `C:\VScode\KLTN\video_data\*.json` (per-video info)

### Log Example:
```
[2026-03-29 11:48:56] [INFO] [Pipeline] Frame 234 | FPS: 6.8 | Tracks: 4 | Det: 5
[2026-03-29 11:48:56] [INFO] [Timer]
===== Timer Summary =====
Section                    Last(ms)   Avg(ms)   Count
detection                    119.53    150.31     233
tracking                       0.14      0.15     233
distance                       0.01      0.01     193
speed                          0.00      0.00     193
ttc                            0.00      0.00     193
risk                           0.00      0.00     193
visualization                  1.22      1.89     233
FPS (smoothed): 6.8
```

---

## Quick Reference - Full Build & Test Cycle

```powershell
# 1. Setup environment
$env:PATH = "C:\opencv-mingw\x64\mingw\bin;C:\mingw64\bin;C:\VScode\KLTN\onnxruntime\lib;" + $env:PATH
cd C:\VScode\KLTN

# 2. Activate Python venv
.\.venv\Scripts\Activate.ps1

# 3. Configure CMake
cd fcw-system\build
Remove-Item CMakeCache.txt, CMakeFiles -Recurse -Force -ErrorAction SilentlyContinue
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DOpenCV_DIR="C:\opencv-mingw" -DUSE_TENSORRT=OFF -DUSE_ONNXRUNTIME=ON -DONNXRUNTIME_ROOT="C:\VScode\KLTN\onnxruntime" ..

# 4. Build executable
mingw32-make -j4
if ($LASTEXITCODE -eq 0) { Write-Output "Build successful!" } else { Write-Output "Build failed!" ; exit 1 }

# 5. Run with test video
.\fcw_system.exe --video "C:\VScode\KLTN\video_data\kitti_video_03_2011_09_26.avi"

# 6. Check results
Get-Content results\logs\system.log -Tail 20
```

---

## Key Configuration Files

### System Config
- **Path**: `fcw-system/config/system_config.yaml`
- **Controls**: Detection params, tracking, distance method, TTC thresholds

### Camera Config
- **Path**: `fcw-system/config/camera_config.yaml`
- **Controls**: Camera intrinsics (fx, fy, cx, cy), mounting height/pitch

### Warning Config
- **Path**: `fcw-system/config/warning_config.yaml`
- **Controls**: TTC alert thresholds, audio settings

---

## Troubleshooting

### Problem: "STATUS_DLL_NOT_FOUND (0xC0000135)"
**Solution**: Set PATH with DLL directories before running:
```powershell
$env:PATH = "C:\opencv-mingw\x64\mingw\bin;C:\mingw64\bin;C:\VScode\KLTN\onnxruntime\lib;" + $env:PATH
```

### Problem: "Failed to open video"
**Reason**: KITTI videos are AVI (MJPG), need MinGW OpenCV with codec support
**Solution**: Use `.avi` files from `video_data/`, not `.mp4`

### Problem: Very slow FPS (~2-3 FPS)
**Reason**: 
- CPU-only ONNX Runtime inference takes ~150ms/frame
- Optical flow ego speed estimation adds overhead
**Solution**: Reduce frame resolution or use GPU-accelerated ONNX Runtime

### Problem: Build fails with "onnxruntime_cxx_api.h not found"
**Solution**: Verify CMake `-DONNXRUNTIME_ROOT` points to correct path:
```powershell
Test-Path "C:\VScode\KLTN\onnxruntime\include\onnxruntime_cxx_api.h"
```

---

## Advanced: Build on Jetson Nano (Cross-Platform)

```bash
# On Jetson:
cd ~/fcw-system/build
cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DJETSON=ON \
  -DUSE_TENSORRT=ON \
  -DUSE_ONNXRUNTIME=OFF \
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
  ..
make -j4
```

**Expected Performance**: 15-20 FPS with TensorRT GPU acceleration

---

## Model Conversion Pipeline

### Export YOLOv8 to ONNX (opset 11 for compatibility)
```python
from ultralytics import YOLO
model = YOLO('yolov8s.pt')
model.export(format='onnx', imgsz=640, simplify=True, opset=11)
```

### Verify ONNX Model
```python
import onnx
model = onnx.load('yolov8s.onnx')
print(f"Inputs: {[i.name for i in model.graph.input]}")
print(f"Outputs: {[o.name for o in model.graph.output]}")
```

---

## Summary of Features

✅ **Detection**: YOLOv8s with ONNX Runtime (12 BDD100K / 80 COCO classes)
✅ **Tracking**: SORT algorithm with Kalman filter
✅ **Distance**: Monocular camera geometry (bbox height method)
✅ **Speed**: Relative speed from distance change + ego speed from optical flow
✅ **TTC**: Time-to-collision calculation with EMA smoothing
✅ **Risk**: Multi-level collision warning (SAFE/CAUTION/DANGER/CRITICAL)
✅ **Warning**: Audio alert + visual overlay
✅ **Visualization**: HUD with detection zones, traffic light status, ego speed panel

---

## Performance Metrics

| Component | Time (ms/frame) | Notes |
|-----------|-----------------|-------|
| Capture | 4-5 | Video I/O |
| Detection | 140-160 | ONNX Runtime (CPU) |
| Tracking | 0.1-0.2 | SORT + Kalman |
| Distance | 0.01 | Geometry calc |
| Speed | 0.0 | Distance derivative |
| TTC | 0.0 | Division |
| Risk | 0.0 | Lookup table |
| Visualization | 1-2 | OpenCV drawing |
| **Total** | **145-175** | **6-7 FPS** |

---

**Last Updated**: March 29, 2026
**Status**: Production Ready
