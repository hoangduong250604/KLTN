#!/bin/bash
# ==============================================================================
# FCW System - Run Script
# ==============================================================================
# Usage:
#   ./run.sh                                              # Default video
#   ./run.sh video_data/2011_09_26_drive_0009_sync.avi    # Specific video
#   ./run.sh --camera 0                                   # Live camera
#   ./run.sh --list                                       # List videos
#   ./run.sh --threaded                                   # Multi-threaded mode
#   ./run.sh --help                                       # Show help
# ==============================================================================

set -e

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FCW_DIR="${SCRIPT_DIR}/fcw-system"
BUILD_DIR="${FCW_DIR}/build"
VIDEO_DIR="${SCRIPT_DIR}/video_data"
KITTI_DIR="${SCRIPT_DIR}/KITTI"

# --- Platform Detection ---
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* || "$OSTYPE" == "cygwin" ]]; then
    EXE="${BUILD_DIR}/fcw_system.exe"
    export PATH="C:/opencv-mingw/x64/mingw/bin:C:/mingw64/bin:${SCRIPT_DIR}/onnxruntime/lib:${PATH}"
else
    EXE="${BUILD_DIR}/fcw_system"
fi

# --- Help ---
show_help() {
    echo "=========================================="
    echo "  FCW System - Run Script"
    echo "=========================================="
    echo ""
    echo "Usage: ./run.sh [options] [video_path]"
    echo ""
    echo "Options:"
    echo "  (none)          Run with default video"
    echo "  <video_path>    Run with specified video"
    echo "  --camera <id>   Use live camera (default: 0)"
    echo "  --threaded      Use multi-threaded pipeline"
    echo "  --list          List available videos"
    echo "  --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  ./run.sh"
    echo "  ./run.sh video_data/2011_09_26_drive_0009_sync.avi"
    echo "  ./run.sh --camera 0"
    echo "  ./run.sh --threaded video_data/2011_09_26_drive_0001_sync.avi"
    echo ""
}

# --- List Videos ---
list_videos() {
    echo "=========================================="
    echo "  Available KITTI Videos"
    echo "=========================================="
    echo ""
    
    if [ ! -d "${VIDEO_DIR}" ]; then
        echo "[ERROR] Video directory not found: ${VIDEO_DIR}"
        echo "        Run ./convert_videos.sh first"
        exit 1
    fi

    printf "%-45s %10s\n" "Video" "Size"
    printf "%-45s %10s\n" "-----" "----"
    
    for video in "${VIDEO_DIR}"/2011_*.avi; do
        if [ -f "${video}" ]; then
            name=$(basename "${video}")
            size=$(du -h "${video}" 2>/dev/null | cut -f1)
            printf "%-45s %10s\n" "${name}" "${size}"
        fi
    done
    echo ""
}

# --- Find Default Video ---
find_default_video() {
    local candidates=(
        "${VIDEO_DIR}/2011_09_26_drive_0009_sync.avi"
        "${VIDEO_DIR}/2011_09_26_drive_0001_sync.avi"
        "${VIDEO_DIR}/2011_09_26_drive_0005_sync.avi"
    )
    
    for v in "${candidates[@]}"; do
        if [ -f "${v}" ]; then
            echo "${v}"
            return
        fi
    done

    # Fallback: any .avi
    local first_avi=$(ls "${VIDEO_DIR}"/2011_*.avi 2>/dev/null | head -1)
    if [ -n "${first_avi}" ]; then
        echo "${first_avi}"
        return
    fi

    echo ""
}

# --- Check Binary ---
check_binary() {
    if [ ! -f "${EXE}" ]; then
        echo "[ERROR] FCW executable not found: ${EXE}"
        echo ""
        echo "Build it first:"
        echo "  ./build.sh"
        exit 1
    fi
}

# --- Check Model ---
check_model() {
    local model_onnx="${FCW_DIR}/models/yolov8s.onnx"
    local model_engine="${FCW_DIR}/models/yolov8s.engine"

    if [ -f "${model_engine}" ]; then
        echo "[INFO] Model: ${model_engine} (TensorRT)"
    elif [ -f "${model_onnx}" ]; then
        echo "[INFO] Model: ${model_onnx} (ONNX)"
    else
        echo "[ERROR] No model found in ${FCW_DIR}/models/"
        echo "        Place yolov8s.onnx or yolov8s.engine there."
        exit 1
    fi
}

# === MAIN ===
THREADED=""
CAMERA_ID=""
VIDEO_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --list|-l)
            list_videos
            exit 0
            ;;
        --threaded|-t)
            THREADED="--threaded"
            shift
            ;;
        --camera|-c)
            CAMERA_ID="${2:-0}"
            shift 2
            ;;
        *)
            VIDEO_PATH="$1"
            shift
            ;;
    esac
done

check_binary
check_model

# Build command
CMD=("${EXE}")

if [ -n "${CAMERA_ID}" ]; then
    CMD+=(--camera "${CAMERA_ID}")
    echo "[INFO] Input: Camera ${CAMERA_ID}"
elif [ -n "${VIDEO_PATH}" ]; then
    # Resolve relative path
    if [[ ! "${VIDEO_PATH}" = /* ]]; then
        VIDEO_PATH="${SCRIPT_DIR}/${VIDEO_PATH}"
    fi
    if [ ! -f "${VIDEO_PATH}" ]; then
        echo "[ERROR] Video not found: ${VIDEO_PATH}"
        exit 1
    fi
    CMD+=(--video "${VIDEO_PATH}")
    echo "[INFO] Input: ${VIDEO_PATH}"
else
    DEFAULT=$(find_default_video)
    if [ -z "${DEFAULT}" ]; then
        echo "[ERROR] No video found in ${VIDEO_DIR}/"
        echo "        Run ./convert_videos.sh or specify a video path"
        exit 1
    fi
    CMD+=(--video "${DEFAULT}")
    echo "[INFO] Input: ${DEFAULT} (default)"
fi

if [ -n "${THREADED}" ]; then
    CMD+=(${THREADED})
    echo "[INFO] Mode: Multi-threaded"
fi

echo ""
echo "=========================================="
echo "  Forward Collision Warning System"
echo "=========================================="
echo "[INFO] Press 'q' or ESC to quit"
echo ""

# Run from fcw-system directory
cd "${FCW_DIR}"
"${CMD[@]}"
