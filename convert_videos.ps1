# ==============================================================================
# FCW System - Convert KITTI Sequences to Videos (PowerShell)
# ==============================================================================
# Batch convert KITTI image sequences to AVI video files.
#
# Usage:
#   .\convert_videos.ps1                # Convert all new drives
#   .\convert_videos.ps1 -Force         # Re-convert all (overwrite)
#   .\convert_videos.ps1 -CleanOld      # Remove old-format videos first
# ==============================================================================

param(
    [switch]$Force,
    [switch]$CleanOld
)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR  = $PSScriptRoot
$KITTI_DIR   = Join-Path $SCRIPT_DIR "KITTI"
$OUTPUT_DIR  = Join-Path $SCRIPT_DIR "video_data"
$CONVERT_PY  = Join-Path $SCRIPT_DIR "convert_kitti_to_video.py"

# --- Check prerequisites ---
if (-not (Test-Path $KITTI_DIR)) {
    Write-Host "[ERROR] KITTI directory not found: $KITTI_DIR" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $CONVERT_PY)) {
    Write-Host "[ERROR] Conversion script not found: $CONVERT_PY" -ForegroundColor Red
    exit 1
}

# Activate venv if exists
$activate = Join-Path $SCRIPT_DIR ".venv\Scripts\Activate.ps1"
if (Test-Path $activate) {
    & $activate
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  KITTI -> Video Conversion"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  KITTI root:  $KITTI_DIR"
Write-Host "  Output dir:  $OUTPUT_DIR"
Write-Host ""

# Build arguments
$args = @(
    $CONVERT_PY,
    "--kitti-root", $KITTI_DIR,
    "--output-dir", $OUTPUT_DIR
)

if ($Force)    { $args += "--force" }
if ($CleanOld) { $args += "--clean-old" }

python @args

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  Conversion complete"
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[ERROR] Conversion failed" -ForegroundColor Red
    exit 1
}
