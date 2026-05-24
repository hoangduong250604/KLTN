# ==============================================================================
# FCW System - Build Script (Windows / MinGW)
# ==============================================================================
# Usage:
#   .\build.ps1              # Release build (default)
#   .\build.ps1 clean        # Clean + Rebuild
#   .\build.ps1 debug        # Debug build
#   .\build.ps1 rebuild      # Force reconfigure + build
# ==============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("release", "debug", "clean", "rebuild", "")]
    [string]$Mode = "release"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build"

# Ensure PATH includes dependencies
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FCW System - Build ($Mode)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------------------------------------
# Clean
# --------------------------------------------------------------------------
if ($Mode -eq "clean") {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    if (Test-Path $BuildDir) {
        Remove-Item -Recurse -Force $BuildDir
    }
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
    Write-Host "Clean complete. Rebuilding..." -ForegroundColor Green
    $Mode = "release"
}

# --------------------------------------------------------------------------
# Create build dir
# --------------------------------------------------------------------------
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

# --------------------------------------------------------------------------
# Determine build type
# --------------------------------------------------------------------------
$buildType = if ($Mode -eq "debug") { "Debug" } else { "Release" }

# --------------------------------------------------------------------------
# CMake Configure (only if needed or rebuild requested)
# --------------------------------------------------------------------------
$cmakeCache = Join-Path $BuildDir "CMakeCache.txt"
$needConfigure = (-not (Test-Path $cmakeCache)) -or ($Mode -eq "rebuild")

if ($needConfigure) {
    Write-Host "Configuring CMake ($buildType)..." -ForegroundColor Cyan
    Push-Location $BuildDir
    try {
        cmake .. `
            -G "MinGW Makefiles" `
            -DCMAKE_BUILD_TYPE=$buildType `
            -DOpenCV_DIR="C:\opencv-mingw" `
            -DONNXRUNTIME_ROOT="C:\VScode\KLTN\onnxruntime" `
            -DUSE_TENSORRT=OFF `
            -DUSE_ONNXRUNTIME=ON
        if ($LASTEXITCODE -ne 0) {
            Write-Host "CMake configure FAILED!" -ForegroundColor Red
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
    Write-Host "Configure OK" -ForegroundColor Green
    Write-Host ""
}

# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
Write-Host "Building..." -ForegroundColor Cyan
$cpuCount = [Math]::Max(1, [Environment]::ProcessorCount - 1)
$makeArgs = "-j$cpuCount"

Push-Location $BuildDir
try {
    $ErrorActionPreference = "Continue"
    $buildOutput = & mingw32-make $makeArgs 2>&1
    $buildExitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    foreach ($line in $buildOutput) {
        $text = "$line"
        if ($text -match "error:") {
            Write-Host $text -ForegroundColor Red
        } elseif ($text -match "warning:") {
            Write-Host $text -ForegroundColor Yellow
        } else {
            Write-Host $text
        }
    }
    if ($buildExitCode -ne 0) {
        Write-Host ""
        Write-Host "Build FAILED!" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} finally {
    Pop-Location
}

# --------------------------------------------------------------------------
# Copy DLLs to build dir
# --------------------------------------------------------------------------
$dllSources = @(
    "C:\VScode\KLTN\onnxruntime\lib\onnxruntime.dll"
)
foreach ($dll in $dllSources) {
    if (Test-Path $dll) {
        $dest = Join-Path $BuildDir (Split-Path $dll -Leaf)
        if (-not (Test-Path $dest)) {
            Copy-Item $dll $dest
            Write-Host "Copied: $(Split-Path $dll -Leaf) -> build/" -ForegroundColor Gray
        }
    }
}

# --------------------------------------------------------------------------
# Verify
# --------------------------------------------------------------------------
$exe = Join-Path $BuildDir "fcw_system.exe"
if (Test-Path $exe) {
    $sizeMB = [math]::Round((Get-Item $exe).Length / 1MB, 1)
    Write-Host ""
    Write-Host "Build SUCCESS: fcw_system.exe (${sizeMB} MB)" -ForegroundColor Green
    Write-Host "Next: .\run.ps1" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Build completed but exe not found!" -ForegroundColor Red
    exit 1
}
