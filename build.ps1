# ==============================================================================
# FCW System - Build Script (PowerShell)
# ==============================================================================
# Usage:
#   .\build.ps1              # Build Release (default)
#   .\build.ps1 debug        # Build Debug
#   .\build.ps1 clean        # Clean + Rebuild
#   .\build.ps1 configure    # Configure CMake only
#   .\build.ps1 --help       # Show help
# ==============================================================================

param(
    [Parameter(Position=0)]
    [string]$Command = "build"
)

$ErrorActionPreference = "Stop"

# --- Paths ---
$SCRIPT_DIR = $PSScriptRoot
$FCW_DIR    = Join-Path $SCRIPT_DIR "fcw-system"
$BUILD_DIR  = Join-Path $FCW_DIR "build"
$NPROC      = $env:NUMBER_OF_PROCESSORS
if (-not $NPROC) { $NPROC = 4 }

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
    $env:OPENCV_DIR = "C:\opencv-mingw"
    $env:ONNXRUNTIME_ROOT = Join-Path $SCRIPT_DIR "onnxruntime"
}

# --- Help ---
function Show-Help {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  FCW System - Build Script"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\build.ps1 [command]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  (none)      Build Release (default)"
    Write-Host "  debug       Build Debug mode"
    Write-Host "  clean       Clean cache + Rebuild Release"
    Write-Host "  configure   Configure CMake only"
    Write-Host "  --help      Show this help"
    Write-Host ""
}

# --- Clean ---
function Clean-Build {
    Write-Host "[CLEAN] Removing CMake cache..." -ForegroundColor Yellow
    $cache = Join-Path $BUILD_DIR "CMakeCache.txt"
    $files = Join-Path $BUILD_DIR "CMakeFiles"
    if (Test-Path $cache) { Remove-Item $cache -Force }
    if (Test-Path $files) { Remove-Item $files -Recurse -Force }
    Write-Host "[CLEAN] Done" -ForegroundColor Green
}

# --- Configure ---
function Configure-CMake {
    param([string]$BuildType = "Release")
    
    Write-Host "[CMAKE] Configuring ($BuildType)..." -ForegroundColor Cyan
    
    if (-not (Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
    }

    Push-Location $BUILD_DIR
    try {
        cmake -G "MinGW Makefiles" `
            -DCMAKE_BUILD_TYPE=$BuildType `
            -DOpenCV_DIR="C:\opencv-mingw" `
            -DUSE_TENSORRT=OFF `
            -DUSE_ONNXRUNTIME=ON `
            -DONNXRUNTIME_ROOT="$env:ONNXRUNTIME_ROOT" `
            ..
        
        if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed" }
        Write-Host "[CMAKE] Configuration complete" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

# --- Build ---
function Build-Project {
    Write-Host "[BUILD] Compiling with $NPROC threads..." -ForegroundColor Cyan
    
    Push-Location $BUILD_DIR
    try {
        mingw32-make -j $NPROC
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "==========================================" -ForegroundColor Green
            Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
            Write-Host "  Output: $BUILD_DIR\fcw_system.exe" -ForegroundColor Green
            Write-Host "==========================================" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "[ERROR] Build failed!" -ForegroundColor Red
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

# === MAIN ===
Setup-Env

switch ($Command.ToLower()) {
    { $_ -in "--help", "-h", "help" } {
        Show-Help
        exit 0
    }
    "clean" {
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  FCW System - Clean Build (Release)"
        Write-Host "==========================================" -ForegroundColor Cyan
        Clean-Build
        Configure-CMake "Release"
        Build-Project
    }
    "debug" {
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  FCW System - Debug Build"
        Write-Host "==========================================" -ForegroundColor Cyan
        Configure-CMake "Debug"
        Build-Project
    }
    "configure" {
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  FCW System - Configure Only"
        Write-Host "==========================================" -ForegroundColor Cyan
        Configure-CMake "Release"
    }
    default {
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  FCW System - Build (Release)"
        Write-Host "==========================================" -ForegroundColor Cyan
        # Only reconfigure if no cache
        $cache = Join-Path $BUILD_DIR "CMakeCache.txt"
        if (-not (Test-Path $cache)) {
            Configure-CMake "Release"
        }
        Build-Project
    }
}
