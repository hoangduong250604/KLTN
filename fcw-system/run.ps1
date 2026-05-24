# ==============================================================================
# FCW System - Run Script (Windows Laptop Testing)
# ==============================================================================
# Usage:
#   .\run.ps1                                                  # Default video
#   .\run.ps1 video_data\2011_09_26_drive_0051_sync.avi        # Specific video
#   .\run.ps1 -Camera 0                                        # USB camera
#   .\run.ps1 -Threaded                                        # Multi-threaded
#   .\run.ps1 -Threaded video_data\2011_09_26_drive_0014_sync.avi
#   .\run.ps1 -List                                            # List available videos
#   .\run.ps1 -Gui                                             # Launch GUI mode
# ==============================================================================

param(
    [Parameter(Position=0)]
    [string]$Video,
    [int]$Camera = -1,
    [switch]$Threaded,
    [switch]$List,
    [switch]$Gui,
    [switch]$ShowDebug
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$KLTNRoot = Split-Path $ProjectRoot -Parent
$BuildDir = Join-Path $ProjectRoot "build"
$Exe = Join-Path $BuildDir "fcw_system.exe"
$VideoDir = Join-Path $KLTNRoot "video_data"
$KITTIDir = Join-Path $KLTNRoot "KITTI"

# --------------------------------------------------------------------------
# Ensure PATH includes DLL directories
# --------------------------------------------------------------------------
$depsPath = @(
    "C:\mingw64\bin",
    "C:\opencv-mingw\x64\mingw\bin",
    "C:\VScode\KLTN\onnxruntime\lib"
)
foreach ($p in $depsPath) {
    if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
        $env:PATH = "$p;$env:PATH"
    }
}

# --------------------------------------------------------------------------
# Check exe exists
# --------------------------------------------------------------------------
if (-not (Test-Path $Exe)) {
    Write-Host "[ERROR] fcw_system.exe not found! Run .\build.ps1 first." -ForegroundColor Red
    exit 1
}

# --------------------------------------------------------------------------
# List mode
# --------------------------------------------------------------------------
if ($List) {
    Write-Host ""
    Write-Host "Available KITTI videos:" -ForegroundColor Cyan
    Write-Host ""
    $videos = Get-ChildItem $VideoDir -Filter "*.avi" | Sort-Object Name
    $i = 1
    foreach ($v in $videos) {
        $sizeMB = [math]::Round($v.Length / 1MB, 1)
        Write-Host "  [$i] $($v.Name)  (${sizeMB} MB)" -ForegroundColor White
        $i++
    }
    Write-Host ""
    Write-Host "Usage: .\run.ps1 video_data\$($videos[0].Name)" -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FCW System - Run" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------------------------------------
# Build args
# --------------------------------------------------------------------------
$args_ = @()

if ($Gui) {
    # GUI mode
    $args_ += "--gui"
    $args_ += "--video-dir"
    $args_ += $VideoDir
    $args_ += "--kitti-root"
    $args_ += $KITTIDir
    Write-Host "Mode: GUI" -ForegroundColor Cyan
} elseif ($Camera -ge 0) {
    # Camera mode
    $args_ += "--camera"
    $args_ += $Camera.ToString()
    $args_ += "--usb"  # Windows = USB camera
    Write-Host "Mode: Camera $Camera (USB)" -ForegroundColor Cyan
} else {
    # Video mode
    if ([string]::IsNullOrEmpty($Video)) {
        # Default: pick first video
        $defaultVideo = Get-ChildItem $VideoDir -Filter "*.avi" | Sort-Object Name | Select-Object -First 1
        if (-not $defaultVideo) {
            Write-Host "[ERROR] No .avi videos found in video_data/" -ForegroundColor Red
            Write-Host "Run .\convert_videos.ps1 first" -ForegroundColor Yellow
            exit 1
        }
        $videoPath = $defaultVideo.FullName
    } else {
        # Resolve relative or absolute path
        if ([System.IO.Path]::IsPathRooted($Video)) {
            $videoPath = $Video
        } else {
            $videoPath = Join-Path $KLTNRoot $Video
            if (-not (Test-Path $videoPath)) {
                $videoPath = Join-Path $ProjectRoot $Video
            }
        }
    }

    if (-not (Test-Path $videoPath)) {
        Write-Host "[ERROR] Video not found: $videoPath" -ForegroundColor Red
        Write-Host "Use .\run.ps1 -List to see available videos" -ForegroundColor Yellow
        exit 1
    }

    $args_ += "--video"
    $args_ += $videoPath
    Write-Host "Video: $(Split-Path $videoPath -Leaf)" -ForegroundColor Cyan

    # Auto-detect KITTI OXTS data from video name
    $videoName = [System.IO.Path]::GetFileNameWithoutExtension($videoPath)
    $kittiDrive = Join-Path $KITTIDir $videoName
    if (Test-Path $kittiDrive) {
        # Find oxts/data folder
        $oxtsData = Get-ChildItem $kittiDrive -Recurse -Directory | Where-Object {
            $_.Name -eq "data" -and $_.Parent.Name -eq "oxts"
        } | Select-Object -First 1
        if ($oxtsData) {
            $args_ += "--oxts"
            $args_ += $oxtsData.FullName
            $args_ += "--kitti-root"
            $args_ += $kittiDrive
            $oxtsCount = (Get-ChildItem $oxtsData.FullName -Filter "*.txt").Count
            Write-Host "OXTS:  $oxtsCount frames (auto-detected)" -ForegroundColor Gray
        }
    }
}

if ($Threaded) {
    $args_ += "--threaded"
    Write-Host "Pipeline: Multi-threaded" -ForegroundColor Cyan
} else {
    Write-Host "Pipeline: Single-threaded" -ForegroundColor Cyan
}

Write-Host ""

# --------------------------------------------------------------------------
# Run from build directory (so relative paths ./models/ ./sounds/ work)
# --------------------------------------------------------------------------
Push-Location $BuildDir
try {
    # Create symlinks/copies for runtime resources if not present
    $runtimeDirs = @("models", "config", "sounds", "results", "logo")
    foreach ($dir in $runtimeDirs) {
        $src = Join-Path $ProjectRoot $dir
        $dst = Join-Path $BuildDir $dir
        if ((Test-Path $src) -and (-not (Test-Path $dst))) {
            # Use junction (no admin needed) for directories
            cmd /c mklink /J "$dst" "$src" 2>&1 | Out-Null
            if (-not (Test-Path $dst)) {
                # Fallback: copy
                Copy-Item $src $dst -Recurse
            }
        }
    }

    # Ensure results/logs exists
    $logsDir = Join-Path $BuildDir "results\logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    Write-Host "Starting FCW..." -ForegroundColor Green
    Write-Host "Press 'q' to quit, 'p' to pause" -ForegroundColor Gray
    Write-Host ""

    & $Exe @args_
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "FCW exited normally." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "FCW exited with code $exitCode" -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}
