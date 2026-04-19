#!/bin/bash
# ==============================================================================
# FCW System - Convert KITTI Sequences to Videos
# ==============================================================================
# Batch convert KITTI image sequences to AVI video files.
# Video naming: <drive_folder_name>.avi (e.g., 2011_09_26_drive_0001_sync.avi)
#
# Usage:
#   ./convert_videos.sh                # Convert all new drives
#   ./convert_videos.sh --force        # Re-convert all (overwrite)
#   ./convert_videos.sh --clean-old    # Remove old-format videos first
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KITTI_DIR="${SCRIPT_DIR}/KITTI"
OUTPUT_DIR="${SCRIPT_DIR}/video_data"
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

# --- Check prerequisites ---
if [ ! -d "${KITTI_DIR}" ]; then
    echo "[ERROR] KITTI directory not found: ${KITTI_DIR}"
    exit 1
fi

if [ -z "${PYTHON}" ]; then
    echo "[ERROR] Python not found"
    exit 1
fi

# Activate venv if exists
if [ -f "${SCRIPT_DIR}/.venv/Scripts/activate" ]; then
    source "${SCRIPT_DIR}/.venv/Scripts/activate" 2>/dev/null || true
elif [ -f "${SCRIPT_DIR}/.venv/bin/activate" ]; then
    source "${SCRIPT_DIR}/.venv/bin/activate" 2>/dev/null || true
fi

echo "=========================================="
echo "  KITTI → Video Conversion"
echo "=========================================="
echo ""
echo "  KITTI root:  ${KITTI_DIR}"
echo "  Output dir:  ${OUTPUT_DIR}"
echo ""

# Pass all arguments through
${PYTHON} "${SCRIPT_DIR}/convert_kitti_to_video.py" \
    --kitti-root "${KITTI_DIR}" \
    --output-dir "${OUTPUT_DIR}" \
    "$@"

echo ""
echo "=========================================="
echo "  Conversion complete"
echo "=========================================="
