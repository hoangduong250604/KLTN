# ==============================================================================
# FCW System - Environment Setup (PowerShell)
# ==============================================================================
# Run ONCE when setting up the project on a new machine.
#
# Usage:
#   .\setup_env.ps1              # Full setup
#   .\setup_env.ps1 -CheckOnly   # Check dependencies only
# ==============================================================================

param(
    [Alias("c")]
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = $PSScriptRoot

# --- Helpers ---
function Write-Ok   { param([string]$msg) Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }

# --- Check Dependencies ---
function Check-Dependencies {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Dependency Check (Windows)"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    $script:errors = 0

    # --- Build Tools ---
    Write-Host "--- Build Tools ---"
    
    # CMake
    $cmake = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmake) {
        $ver = (cmake --version | Select-Object -First 1)
        Write-Ok "CMake: $ver"
    } else {
        Write-Fail "CMake not found (https://cmake.org/download/)"
        $script:errors++
    }

    # g++
    $gpp = Get-Command g++ -ErrorAction SilentlyContinue
    if ($gpp) {
        $ver = (g++ --version | Select-Object -First 1)
        Write-Ok "g++: $ver"
    } else {
        Write-Fail "MinGW g++ not found (add C:\mingw64\bin to PATH)"
        $script:errors++
    }

    # mingw32-make
    $make = Get-Command mingw32-make -ErrorAction SilentlyContinue
    if ($make) {
        Write-Ok "mingw32-make found"
    } else {
        Write-Fail "mingw32-make not found"
        $script:errors++
    }

    # --- Python ---
    Write-Host ""
    Write-Host "--- Python ---"
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        $ver = (python --version 2>&1)
        Write-Ok "Python: $ver"
    } else {
        Write-Fail "Python not found"
        $script:errors++
    }

    # --- Libraries ---
    Write-Host ""
    Write-Host "--- Libraries ---"
    
    # OpenCV
    if (Test-Path "C:\opencv-mingw") {
        Write-Ok "OpenCV: C:\opencv-mingw"
    } else {
        Write-Fail "OpenCV not found at C:\opencv-mingw"
        $script:errors++
    }

    # ONNX Runtime
    $onnxrt = Join-Path $SCRIPT_DIR "onnxruntime\lib"
    if (Test-Path $onnxrt) {
        Write-Ok "ONNX Runtime: $onnxrt"
    } else {
        Write-Fail "ONNX Runtime not found in $SCRIPT_DIR\onnxruntime\"
        $script:errors++
    }

    # --- Models ---
    Write-Host ""
    Write-Host "--- Models ---"
    $modelOnnx = Join-Path $SCRIPT_DIR "fcw-system\models\yolov8s.onnx"
    $modelPt   = Join-Path $SCRIPT_DIR "yolov8s.pt"
    if (Test-Path $modelOnnx) {
        $size = "{0:N1} MB" -f ((Get-Item $modelOnnx).Length / 1MB)
        Write-Ok "YOLOv8s ONNX model ($size)"
    } elseif (Test-Path $modelPt) {
        Write-Warn "YOLOv8s .pt found (needs ONNX conversion)"
    } else {
        Write-Fail "No YOLOv8 model found"
        $script:errors++
    }

    # --- Dataset ---
    Write-Host ""
    Write-Host "--- Dataset ---"
    $kittiDir = Join-Path $SCRIPT_DIR "KITTI"
    if (Test-Path $kittiDir) {
        $drives = (Get-ChildItem -Path $kittiDir -Directory -Filter "2011_*_sync").Count
        Write-Ok "KITTI dataset: $drives drives"
    } else {
        Write-Warn "KITTI dataset not found in $kittiDir"
    }

    $videoDir = Join-Path $SCRIPT_DIR "video_data"
    if (Test-Path $videoDir) {
        $videos = (Get-ChildItem -Path $videoDir -Filter "2011_*.avi" -ErrorAction SilentlyContinue).Count
        Write-Ok "Videos: $videos AVI files"
    } else {
        Write-Warn "No videos in video_data\ (run .\convert_videos.ps1)"
    }

    # --- Optional ---
    Write-Host ""
    Write-Host "--- Optional ---"
    if (Test-Path "C:\TensorRT*") {
        $trtDir = (Get-ChildItem "C:\" -Directory -Filter "TensorRT*" | Select-Object -First 1).FullName
        Write-Ok "TensorRT: $trtDir"
    } else {
        Write-Warn "TensorRT not found (optional, for GPU acceleration)"
    }

    # --- Summary ---
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    if ($script:errors -eq 0) {
        Write-Host "  All dependencies satisfied!" -ForegroundColor Green
    } else {
        Write-Host "  $($script:errors) missing dependencies" -ForegroundColor Red
    }
    Write-Host "==========================================" -ForegroundColor Cyan

    return $script:errors
}

# --- Setup Python venv ---
function Setup-Python {
    Write-Host ""
    Write-Host "[SETUP] Python virtual environment..." -ForegroundColor Cyan

    $venvDir = Join-Path $SCRIPT_DIR ".venv"
    if (Test-Path $venvDir) {
        Write-Ok "Virtual environment already exists"
    } else {
        Write-Host "  Creating .venv..."
        python -m venv $venvDir
        Write-Ok "Virtual environment created"
    }

    # Activate
    $activate = Join-Path $venvDir "Scripts\Activate.ps1"
    if (Test-Path $activate) {
        & $activate
    }

    Write-Host "  Installing Python packages..."
    pip install --upgrade pip -q 2>$null
    pip install opencv-python ultralytics onnx onnxruntime scipy -q 2>$null
    Write-Ok "Python packages installed"
}

# --- Setup Build Directory ---
function Setup-Build {
    Write-Host ""
    Write-Host "[SETUP] Build directories..." -ForegroundColor Cyan
    
    $dirs = @(
        "fcw-system\build",
        "fcw-system\results\logs",
        "fcw-system\results\videos",
        "results\logs",
        "results\videos"
    )
    foreach ($d in $dirs) {
        $path = Join-Path $SCRIPT_DIR $d
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    Write-Ok "Directories created"
}

# === MAIN ===
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  FCW System - Environment Setup"
Write-Host "  Platform: Windows (PowerShell)"
Write-Host "==========================================" -ForegroundColor Cyan

$depErrors = Check-Dependencies

if ($CheckOnly) {
    exit $depErrors
}

if ($depErrors -gt 0) {
    Write-Host ""
    Write-Warn "Fix missing dependencies above before continuing"
}

Setup-Python
Setup-Build

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Setup complete! Next steps:"
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Build:    .\build.ps1"
Write-Host "  2. Convert:  .\convert_videos.ps1"
Write-Host "  3. Run:      .\run.ps1"
Write-Host ""
