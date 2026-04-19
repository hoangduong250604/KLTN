# ==============================================================================
# FCW System - Run Script (PowerShell)
# ==============================================================================
# Usage:
#   .\run.ps1                                                # Default video
#   .\run.ps1 video_data\2011_09_26_drive_0009_sync.avi      # Specific video
#   .\run.ps1 -Camera 0                                      # Live camera
#   .\run.ps1 -List                                          # List videos
#   .\run.ps1 -Threaded                                      # Multi-threaded
#   .\run.ps1 -Help                                          # Show help
# ==============================================================================

param(
    [Parameter(Position=0)]
    [string]$Video,
    
    [int]$Camera = -1,
    
    [switch]$Threaded,
    
    [Alias("l")]
    [switch]$List,
    
    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# --- Paths ---
$SCRIPT_DIR = $PSScriptRoot
$FCW_DIR    = Join-Path $SCRIPT_DIR "fcw-system"
$BUILD_DIR  = Join-Path $FCW_DIR "build"
$VIDEO_DIR  = Join-Path $SCRIPT_DIR "video_data"
$EXE        = Join-Path $BUILD_DIR "fcw_system.exe"

# --- Environment ---
function Setup-Env {
    $paths = @(
        "C:\opencv-mingw\x64\mingw\bin",
        "C:\mingw64\bin",
        (Join-Path $SCRIPT_DIR "onnxruntime\lib")
    )
    foreach ($p in $paths) {
        if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
            $env:PATH = "$p;$env:PATH"
        }
    }
}

# --- Help ---
function Show-Help {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  FCW System - Run Script"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\run.ps1 [options] [video_path]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  (none)              Run with default video"
    Write-Host "  <video_path>        Run with specified video"
    Write-Host "  -Camera <id>        Use live camera (default: 0)"
    Write-Host "  -Threaded           Use multi-threaded pipeline"
    Write-Host "  -List               List available videos"
    Write-Host "  -Help               Show this help"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1"
    Write-Host "  .\run.ps1 video_data\2011_09_26_drive_0009_sync.avi"
    Write-Host "  .\run.ps1 -Camera 0"
    Write-Host "  .\run.ps1 -Threaded video_data\2011_09_26_drive_0001_sync.avi"
    Write-Host ""
}

# --- List Videos ---
function List-Videos {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Available KITTI Videos"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $VIDEO_DIR)) {
        Write-Host "[ERROR] Video directory not found: $VIDEO_DIR" -ForegroundColor Red
        Write-Host "        Run .\convert_videos.ps1 first"
        return
    }

    $videos = Get-ChildItem -Path $VIDEO_DIR -Filter "2011_*.avi" | Sort-Object Name
    if ($videos.Count -eq 0) {
        Write-Host "No videos found. Run .\convert_videos.ps1 first" -ForegroundColor Yellow
        return
    }

    Write-Host ("{0,-45} {1,10}" -f "Video", "Size")
    Write-Host ("{0,-45} {1,10}" -f "-----", "----")
    foreach ($v in $videos) {
        $sizeMB = "{0:N1} MB" -f ($v.Length / 1MB)
        Write-Host ("{0,-45} {1,10}" -f $v.Name, $sizeMB)
    }
    Write-Host ""
    Write-Host "Total: $($videos.Count) videos" -ForegroundColor Green
}

# --- Find Default Video ---
function Find-DefaultVideo {
    $candidates = @(
        "2011_09_26_drive_0009_sync.avi",
        "2011_09_26_drive_0001_sync.avi",
        "2011_09_26_drive_0005_sync.avi"
    )
    foreach ($name in $candidates) {
        $path = Join-Path $VIDEO_DIR $name
        if (Test-Path $path) { return $path }
    }
    # Fallback: any avi
    $first = Get-ChildItem -Path $VIDEO_DIR -Filter "2011_*.avi" -ErrorAction SilentlyContinue |
             Sort-Object Name | Select-Object -First 1
    if ($first) { return $first.FullName }
    return $null
}

# === MAIN ===
Setup-Env

if ($Help) {
    Show-Help
    exit 0
}

if ($List) {
    List-Videos
    exit 0
}

# Check binary
if (-not (Test-Path $EXE)) {
    Write-Host "[ERROR] FCW executable not found: $EXE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Build it first:" -ForegroundColor Yellow
    Write-Host "  .\build.ps1"
    exit 1
}

# Check model
$modelOnnx   = Join-Path $FCW_DIR "models\yolov8s.onnx"
$modelEngine = Join-Path $FCW_DIR "models\yolov8s.engine"
if (Test-Path $modelEngine) {
    Write-Host "[INFO] Model: $modelEngine (TensorRT)" -ForegroundColor Gray
} elseif (Test-Path $modelOnnx) {
    Write-Host "[INFO] Model: $modelOnnx (ONNX)" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] No model found in $FCW_DIR\models\" -ForegroundColor Red
    exit 1
}

# Build command
$cmd = @($EXE)

if ($Camera -ge 0) {
    $cmd += @("--camera", "$Camera")
    Write-Host "[INFO] Input: Camera $Camera" -ForegroundColor Gray
} elseif ($Video) {
    # Resolve relative path
    if (-not [System.IO.Path]::IsPathRooted($Video)) {
        $Video = Join-Path $SCRIPT_DIR $Video
    }
    if (-not (Test-Path $Video)) {
        Write-Host "[ERROR] Video not found: $Video" -ForegroundColor Red
        exit 1
    }
    $cmd += @("--video", $Video)
    Write-Host "[INFO] Input: $Video" -ForegroundColor Gray
} else {
    $defaultVideo = Find-DefaultVideo
    if (-not $defaultVideo) {
        Write-Host "[ERROR] No video found in $VIDEO_DIR\" -ForegroundColor Red
        Write-Host "        Run .\convert_videos.ps1 or specify a video path"
        exit 1
    }
    $cmd += @("--video", $defaultVideo)
    Write-Host "[INFO] Input: $defaultVideo (default)" -ForegroundColor Gray
}

if ($Threaded) {
    $cmd += "--threaded"
    Write-Host "[INFO] Mode: Multi-threaded" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Forward Collision Warning System"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[INFO] Press 'q' or ESC to quit" -ForegroundColor Yellow
Write-Host ""

# Run from fcw-system directory
Push-Location $FCW_DIR
try {
    & $cmd[0] $cmd[1..($cmd.Length-1)]
}
finally {
    Pop-Location
}
