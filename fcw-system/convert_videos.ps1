# ==============================================================================
# FCW System - Convert KITTI Image Sequences to Video
# ==============================================================================
# Usage:
#   .\convert_videos.ps1            # Convert all (skip existing)
#   .\convert_videos.ps1 -Force     # Re-convert everything
# ==============================================================================

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent  # KLTN root
$ScriptPath = Join-Path $ProjectRoot "convert_kitti_to_video.py"

if (-not (Test-Path $ScriptPath)) {
    # Fallback: script might be in project root
    $ScriptPath = Join-Path (Split-Path $PSScriptRoot) "convert_kitti_to_video.py"
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "[ERROR] convert_kitti_to_video.py not found!" -ForegroundColor Red
        Write-Host "Expected at: C:\VScode\KLTN\convert_kitti_to_video.py" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  KITTI -> Video Conversion" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Python + OpenCV
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "[ERROR] Python not found in PATH" -ForegroundColor Red
    exit 1
}

python -c "import cv2; print(f'OpenCV {cv2.__version__}')" 2>&1 | ForEach-Object {
    Write-Host "[OK] Python $_" -ForegroundColor Green
}

# Run conversion
$args_ = @()
if ($Force) { $args_ += "--force" }

Write-Host "Converting KITTI sequences..." -ForegroundColor Cyan
Write-Host ""

python $ScriptPath @args_

if ($LASTEXITCODE -eq 0) {
    $count = (Get-ChildItem "C:\VScode\KLTN\video_data" -Filter "*.avi" -ErrorAction SilentlyContinue).Count
    Write-Host ""
    Write-Host "Conversion complete! $count videos in video_data/" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Conversion failed!" -ForegroundColor Red
    exit 1
}
