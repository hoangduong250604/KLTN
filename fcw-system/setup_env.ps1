# ==============================================================================
# FCW System - Environment Setup & Dependency Check
# ==============================================================================
# Usage:
#   .\setup_env.ps1              # Full check + setup PATH
#   .\setup_env.ps1 -CheckOnly   # Only check, don't modify anything
# ==============================================================================

param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FCW System - Environment Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allOk = $true

# --------------------------------------------------------------------------
# 1. MinGW (C++ Compiler)
# --------------------------------------------------------------------------
$mingwBin = "C:\mingw64\bin"
$gpp = Join-Path $mingwBin "c++.exe"
if (Test-Path $gpp) {
    $ver = & "$gpp" --version 2>&1 | Select-Object -First 1
    Write-Host "[OK] MinGW C++: $ver" -ForegroundColor Green
} else {
    Write-Host "[MISSING] MinGW not found at $mingwBin" -ForegroundColor Red
    $allOk = $false
}

# --------------------------------------------------------------------------
# 2. CMake
# --------------------------------------------------------------------------
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if ($cmake) {
    $ver = cmake --version 2>&1 | Select-Object -First 1
    Write-Host "[OK] CMake: $ver" -ForegroundColor Green
} else {
    Write-Host "[MISSING] cmake not in PATH" -ForegroundColor Red
    $allOk = $false
}

# --------------------------------------------------------------------------
# 3. Make (mingw32-make)
# --------------------------------------------------------------------------
$make = Join-Path $mingwBin "mingw32-make.exe"
if (Test-Path $make) {
    Write-Host "[OK] mingw32-make found" -ForegroundColor Green
} else {
    Write-Host "[MISSING] mingw32-make not found at $mingwBin" -ForegroundColor Red
    $allOk = $false
}

# --------------------------------------------------------------------------
# 4. OpenCV
# --------------------------------------------------------------------------
$opencvDir = "C:\opencv-mingw"
$opencvDll = "C:\opencv-mingw\x64\mingw\bin\libopencv_core455.dll"
if (Test-Path $opencvDll) {
    Write-Host "[OK] OpenCV 4.5.5 (MinGW) found" -ForegroundColor Green
} else {
    Write-Host "[MISSING] OpenCV not found at $opencvDir" -ForegroundColor Red
    $allOk = $false
}

# --------------------------------------------------------------------------
# 5. ONNX Runtime
# --------------------------------------------------------------------------
$onnxDir = "C:\VScode\KLTN\onnxruntime"
$onnxDll = Join-Path $onnxDir "lib\onnxruntime.dll"
$onnxHeader = Join-Path $onnxDir "include\onnxruntime_cxx_api.h"
if ((Test-Path $onnxDll) -and (Test-Path $onnxHeader)) {
    Write-Host "[OK] ONNX Runtime found" -ForegroundColor Green
} else {
    Write-Host "[MISSING] ONNX Runtime not found at $onnxDir" -ForegroundColor Red
    $allOk = $false
}

# --------------------------------------------------------------------------
# 6. Model file
# --------------------------------------------------------------------------
$modelPath = "C:\VScode\KLTN\fcw-system\models\yolov8s.onnx"
if (Test-Path $modelPath) {
    $sizeMB = [math]::Round((Get-Item $modelPath).Length / 1MB, 1)
    Write-Host "[OK] Model: yolov8s.onnx (${sizeMB} MB)" -ForegroundColor Green
} else {
    Write-Host "[MISSING] Model not found: $modelPath" -ForegroundColor Red
    $allOk = $false
}

# --------------------------------------------------------------------------
# 7. Video data
# --------------------------------------------------------------------------
$videoDir = "C:\VScode\KLTN\video_data"
$videoCount = (Get-ChildItem $videoDir -Filter "*.avi" -ErrorAction SilentlyContinue).Count
if ($videoCount -gt 0) {
    Write-Host "[OK] Video data: $videoCount KITTI videos in video_data/" -ForegroundColor Green
} else {
    Write-Host "[WARN] No .avi videos found in video_data/ - run .\convert_videos.ps1" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 8. Sounds
# --------------------------------------------------------------------------
$soundsDir = "C:\VScode\KLTN\fcw-system\sounds"
$wavCount = (Get-ChildItem $soundsDir -Filter "*.wav" -ErrorAction SilentlyContinue).Count
$mp3Count = (Get-ChildItem $soundsDir -Filter "*.mp3" -ErrorAction SilentlyContinue).Count
if ($wavCount -ge 3) {
    Write-Host "[OK] Sound files: $wavCount .wav files" -ForegroundColor Green
} elseif ($mp3Count -ge 3) {
    Write-Host "[WARN] Sound files: $mp3Count .mp3 only (Windows uses Beep(), OK for testing)" -ForegroundColor Yellow
} else {
    Write-Host "[WARN] No sound files in sounds/" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
Write-Host ""
if ($allOk) {
    Write-Host "All dependencies found!" -ForegroundColor Green
} else {
    Write-Host "Some dependencies are missing. Fix the [MISSING] items above." -ForegroundColor Red
    if ($CheckOnly) { exit 1 }
}

if ($CheckOnly) {
    Write-Host ""
    Write-Host "(Check-only mode, no PATH changes)" -ForegroundColor Gray
    exit 0
}

# --------------------------------------------------------------------------
# Setup PATH for this session
# --------------------------------------------------------------------------
Write-Host ""
Write-Host "Setting up PATH for this session..." -ForegroundColor Cyan

$pathsToAdd = @(
    $mingwBin,
    "C:\opencv-mingw\x64\mingw\bin",
    "C:\VScode\KLTN\onnxruntime\lib"
)

foreach ($p in $pathsToAdd) {
    if (Test-Path $p) {
        if ($env:PATH -notlike "*$p*") {
            $env:PATH = "$p;$env:PATH"
            Write-Host "  Added: $p" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Environment ready! Next: .\build.ps1" -ForegroundColor Green
Write-Host ""
