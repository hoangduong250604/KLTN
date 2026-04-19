#!/bin/bash
# ==============================================================================
# FCW System - Environment Setup (First Time)
# ==============================================================================
# Run this ONCE when setting up the project on a new machine.
#
# Usage:
#   ./setup_env.sh              # Full setup
#   ./setup_env.sh --check      # Check dependencies only
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

# --- Platform Detection ---
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* || "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="windows"
elif [ -f /etc/nv_tegra_release ]; then
    PLATFORM="jetson"
else
    PLATFORM="linux"
fi

# --- Check Dependencies ---
check_deps() {
    echo "=========================================="
    echo "  Dependency Check (${PLATFORM})"
    echo "=========================================="
    echo ""

    ERRORS=0

    # CMake
    echo "--- Build Tools ---"
    if command -v cmake &>/dev/null; then
        ok "CMake: $(cmake --version | head -1)"
    else
        fail "CMake not found"
        ((ERRORS++))
    fi

    # Compiler
    if [ "${PLATFORM}" = "windows" ]; then
        if command -v g++ &>/dev/null; then
            ok "g++: $(g++ --version | head -1)"
        else
            fail "MinGW g++ not found (add C:\\mingw64\\bin to PATH)"
            ((ERRORS++))
        fi
        if command -v mingw32-make &>/dev/null; then
            ok "mingw32-make found"
        else
            fail "mingw32-make not found"
            ((ERRORS++))
        fi
    else
        if command -v g++ &>/dev/null; then
            ok "g++: $(g++ --version | head -1)"
        else
            fail "g++ not found (apt install build-essential)"
            ((ERRORS++))
        fi
        if command -v make &>/dev/null; then
            ok "make found"
        else
            fail "make not found"
            ((ERRORS++))
        fi
    fi

    # Python
    echo ""
    echo "--- Python ---"
    if command -v python &>/dev/null || command -v python3 &>/dev/null; then
        PYTHON=$(command -v python3 || command -v python)
        ok "Python: $(${PYTHON} --version 2>&1)"
    else
        fail "Python not found"
        ((ERRORS++))
    fi

    # OpenCV
    echo ""
    echo "--- Libraries ---"
    if [ "${PLATFORM}" = "windows" ]; then
        if [ -d "C:/opencv-mingw" ]; then
            ok "OpenCV: C:/opencv-mingw"
        else
            fail "OpenCV not found at C:/opencv-mingw"
            ((ERRORS++))
        fi
    else
        if pkg-config --exists opencv4 2>/dev/null; then
            ok "OpenCV: $(pkg-config --modversion opencv4)"
        elif [ -d "/usr/include/opencv4" ]; then
            ok "OpenCV: found in /usr/include/opencv4"
        else
            warn "OpenCV not detected (may still work via CMake)"
        fi
    fi

    # ONNX Runtime
    if [ -d "${SCRIPT_DIR}/onnxruntime/lib" ]; then
        ok "ONNX Runtime: ${SCRIPT_DIR}/onnxruntime/"
    else
        fail "ONNX Runtime not found in ${SCRIPT_DIR}/onnxruntime/"
        ((ERRORS++))
    fi

    # YOLOv8 Model
    echo ""
    echo "--- Models ---"
    if [ -f "${SCRIPT_DIR}/fcw-system/models/yolov8s.onnx" ]; then
        ok "YOLOv8s ONNX model found"
    elif [ -f "${SCRIPT_DIR}/yolov8s.onnx" ]; then
        warn "YOLOv8s ONNX at root (should be in fcw-system/models/)"
    elif [ -f "${SCRIPT_DIR}/yolov8s.pt" ]; then
        warn "YOLOv8s .pt found (needs conversion: ./convert_videos.sh or python export)"
    else
        fail "No YOLOv8 model found"
        ((ERRORS++))
    fi

    # KITTI Data
    echo ""
    echo "--- Dataset ---"
    if [ -d "${SCRIPT_DIR}/KITTI" ]; then
        DRIVE_COUNT=$(ls -d "${SCRIPT_DIR}"/KITTI/2011_*_sync 2>/dev/null | wc -l)
        ok "KITTI dataset: ${DRIVE_COUNT} drives"
    else
        warn "KITTI dataset not found in ${SCRIPT_DIR}/KITTI/"
    fi

    if [ -d "${SCRIPT_DIR}/video_data" ]; then
        VIDEO_COUNT=$(ls "${SCRIPT_DIR}"/video_data/2011_*.avi 2>/dev/null | wc -l)
        ok "Videos: ${VIDEO_COUNT} AVI files"
    else
        warn "No videos in video_data/ (run ./convert_videos.sh)"
    fi

    # TensorRT (optional)
    echo ""
    echo "--- Optional ---"
    if [ "${PLATFORM}" = "jetson" ]; then
        if command -v trtexec &>/dev/null || [ -f /usr/src/tensorrt/bin/trtexec ]; then
            ok "TensorRT available"
        else
            warn "TensorRT not found (optional, for GPU acceleration)"
        fi
    elif [ "${PLATFORM}" = "windows" ]; then
        if [ -d "C:/TensorRT-8.6.1.6" ]; then
            ok "TensorRT: C:/TensorRT-8.6.1.6"
        else
            warn "TensorRT not found (optional)"
        fi
    fi

    # Summary
    echo ""
    echo "=========================================="
    if [ ${ERRORS} -eq 0 ]; then
        echo -e "  ${GREEN}All dependencies satisfied!${NC}"
    else
        echo -e "  ${RED}${ERRORS} missing dependencies${NC}"
    fi
    echo "=========================================="

    return ${ERRORS}
}

# --- Setup Python venv ---
setup_python() {
    echo ""
    echo "[SETUP] Python virtual environment..."

    PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

    if [ -d "${SCRIPT_DIR}/.venv" ]; then
        ok "Virtual environment already exists"
    else
        echo "  Creating .venv..."
        ${PYTHON} -m venv "${SCRIPT_DIR}/.venv"
        ok "Virtual environment created"
    fi

    # Activate
    if [ "${PLATFORM}" = "windows" ]; then
        source "${SCRIPT_DIR}/.venv/Scripts/activate" 2>/dev/null || true
    else
        source "${SCRIPT_DIR}/.venv/bin/activate" 2>/dev/null || true
    fi

    echo "  Installing Python packages..."
    pip install --upgrade pip -q
    pip install opencv-python ultralytics onnx onnxruntime scipy -q
    ok "Python packages installed"
}

# --- Setup Build Directory ---
setup_build() {
    echo ""
    echo "[SETUP] Build directory..."
    mkdir -p "${SCRIPT_DIR}/fcw-system/build"
    mkdir -p "${SCRIPT_DIR}/fcw-system/results/logs"
    mkdir -p "${SCRIPT_DIR}/fcw-system/results/videos"
    mkdir -p "${SCRIPT_DIR}/results/logs"
    mkdir -p "${SCRIPT_DIR}/results/videos"
    ok "Directories created"
}

# === MAIN ===
echo "=========================================="
echo "  FCW System - Environment Setup"
echo "  Platform: ${PLATFORM}"
echo "=========================================="

case "${1}" in
    --check|-c)
        check_deps
        ;;
    *)
        check_deps
        DEPS_OK=$?
        
        if [ ${DEPS_OK} -gt 0 ]; then
            echo ""
            warn "Fix missing dependencies above before continuing"
            echo ""
        fi

        setup_python
        setup_build

        echo ""
        echo "=========================================="
        echo "  Setup complete! Next steps:"
        echo "=========================================="
        echo ""
        echo "  1. Build:    ./build.sh"
        echo "  2. Convert:  ./convert_videos.sh"
        echo "  3. Run:      ./run.sh"
        echo ""
        ;;
esac
