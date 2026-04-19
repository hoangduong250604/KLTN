#!/bin/bash
# ==============================================================================
# FCW System - Build Script
# ==============================================================================
# Usage:
#   ./build.sh              # Build Release (default)
#   ./build.sh debug        # Build Debug
#   ./build.sh clean        # Clean + Rebuild
#   ./build.sh --help       # Show help
# ==============================================================================

set -e

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FCW_DIR="${SCRIPT_DIR}/fcw-system"
BUILD_DIR="${FCW_DIR}/build"

# --- Platform Detection ---
detect_platform() {
    if [ -f /etc/nv_tegra_release ]; then
        PLATFORM="jetson"
        GENERATOR="Unix Makefiles"
        MAKE_CMD="make"
        OPENCV_DIR=""
        ONNXRT_ROOT=""
        NPROC=$(nproc)
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* || "$OSTYPE" == "cygwin" ]]; then
        PLATFORM="windows"
        GENERATOR="MinGW Makefiles"
        MAKE_CMD="mingw32-make"
        OPENCV_DIR="C:/opencv-mingw"
        ONNXRT_ROOT="${SCRIPT_DIR}/onnxruntime"
        NPROC=${NUMBER_OF_PROCESSORS:-4}
    else
        PLATFORM="linux"
        GENERATOR="Unix Makefiles"
        MAKE_CMD="make"
        OPENCV_DIR=""
        ONNXRT_ROOT="${SCRIPT_DIR}/onnxruntime"
        NPROC=$(nproc 2>/dev/null || echo 4)
    fi
}

# --- Environment Setup ---
setup_env() {
    if [ "${PLATFORM}" = "windows" ]; then
        export PATH="C:/opencv-mingw/x64/mingw/bin:C:/mingw64/bin:${SCRIPT_DIR}/onnxruntime/lib:${PATH}"
        export OPENCV_DIR="C:/opencv-mingw"
        export ONNXRUNTIME_ROOT="${SCRIPT_DIR}/onnxruntime"
    fi
}

# --- Help ---
show_help() {
    echo "=========================================="
    echo "  FCW System - Build Script"
    echo "=========================================="
    echo ""
    echo "Usage: ./build.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  (none)      Build Release (default)"
    echo "  debug       Build Debug mode"
    echo "  clean       Clean cache + Rebuild Release"
    echo "  configure   Configure CMake only (no build)"
    echo "  --help      Show this help"
    echo ""
    echo "Platform: ${PLATFORM} (auto-detected)"
    echo "Generator: ${GENERATOR}"
    echo "Threads: ${NPROC}"
    echo ""
}

# --- Clean ---
clean_build() {
    echo "[CLEAN] Removing CMake cache..."
    rm -f "${BUILD_DIR}/CMakeCache.txt"
    rm -rf "${BUILD_DIR}/CMakeFiles"
    echo "[CLEAN] Done"
}

# --- Configure ---
configure_cmake() {
    local BUILD_TYPE="${1:-Release}"

    echo "[CMAKE] Configuring (${BUILD_TYPE})..."
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    local CMAKE_ARGS=(
        -G "${GENERATOR}"
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
        -DUSE_TENSORRT=OFF
        -DUSE_ONNXRUNTIME=ON
    )

    # Platform-specific args
    if [ -n "${OPENCV_DIR}" ]; then
        CMAKE_ARGS+=(-DOpenCV_DIR="${OPENCV_DIR}")
    fi
    if [ -n "${ONNXRT_ROOT}" ]; then
        CMAKE_ARGS+=(-DONNXRUNTIME_ROOT="${ONNXRT_ROOT}")
    fi

    cmake "${CMAKE_ARGS[@]}" ..
    echo "[CMAKE] Configuration complete"
}

# --- Build ---
build_project() {
    echo "[BUILD] Compiling with ${NPROC} threads..."
    cd "${BUILD_DIR}"
    ${MAKE_CMD} -j${NPROC}

    if [ $? -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "  BUILD SUCCESSFUL"
        echo "  Output: ${BUILD_DIR}/fcw_system${EXT}"
        echo "=========================================="
    else
        echo ""
        echo "[ERROR] Build failed!"
        exit 1
    fi
}

# === MAIN ===
detect_platform

# Extension
if [ "${PLATFORM}" = "windows" ]; then
    EXT=".exe"
else
    EXT=""
fi

setup_env

case "${1}" in
    --help|-h)
        show_help
        exit 0
        ;;
    clean)
        echo "=========================================="
        echo "  FCW System - Clean Build (Release)"
        echo "=========================================="
        clean_build
        configure_cmake "Release"
        build_project
        ;;
    debug)
        echo "=========================================="
        echo "  FCW System - Debug Build"
        echo "=========================================="
        configure_cmake "Debug"
        build_project
        ;;
    configure)
        echo "=========================================="
        echo "  FCW System - Configure Only"
        echo "=========================================="
        configure_cmake "${2:-Release}"
        ;;
    *)
        echo "=========================================="
        echo "  FCW System - Build (Release)"
        echo "=========================================="
        # Only reconfigure if no cache exists
        if [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
            configure_cmake "Release"
        fi
        build_project
        ;;
esac
