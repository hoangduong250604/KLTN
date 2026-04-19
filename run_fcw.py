"""
FCW System Runner - Python orchestrator for C++ FCW pipeline
Usage:
    python run_fcw.py                          # Run with default video
    python run_fcw.py --video path/to/video.mp4
    python run_fcw.py --camera 0               # Use webcam
    python run_fcw.py --convert-model          # Only convert model
"""

import subprocess
import sys
import os
import argparse
import shutil
from pathlib import Path

# Paths
ROOT_DIR = Path(__file__).parent.resolve()
FCW_DIR = ROOT_DIR / "fcw-system"
BUILD_DIR = FCW_DIR / "build"
MODELS_DIR = FCW_DIR / "models"
VIDEO_DIR = ROOT_DIR / "video_data"
EXE_PATH = BUILD_DIR / "fcw_system.exe"

# Model paths
PT_MODEL = ROOT_DIR / "yolov8s.pt"
ONNX_MODEL = MODELS_DIR / "yolov8s.onnx"
ENGINE_MODEL = MODELS_DIR / "yolov8s.engine"


def convert_pt_to_onnx():
    """Export YOLOv8 .pt model to ONNX format using ultralytics."""
    if ONNX_MODEL.exists():
        print(f"[OK] ONNX model already exists: {ONNX_MODEL}")
        return True

    if not PT_MODEL.exists():
        print(f"[ERROR] PyTorch model not found: {PT_MODEL}")
        return False

    print(f"[INFO] Converting {PT_MODEL.name} -> ONNX ...")
    try:
        from ultralytics import YOLO
        model = YOLO(str(PT_MODEL))
        export_path = model.export(format="onnx", imgsz=640, simplify=True)
        # ultralytics exports next to the .pt file; move to models/
        exported = Path(export_path)
        if exported.exists():
            shutil.move(str(exported), str(ONNX_MODEL))
            print(f"[OK] ONNX model saved to {ONNX_MODEL}")
            return True
        else:
            print(f"[ERROR] Export produced no file at {exported}")
            return False
    except ImportError:
        print("[ERROR] ultralytics not installed. Run: pip install ultralytics")
        return False
    except Exception as e:
        print(f"[ERROR] Model conversion failed: {e}")
        return False


def check_exe():
    """Verify the C++ executable exists."""
    if not EXE_PATH.exists():
        print(f"[ERROR] Executable not found: {EXE_PATH}")
        print("        Build it first:")
        print(f"          cd {BUILD_DIR}")
        print("          mingw32-make -j4")
        return False
    return True


def get_default_video():
    """Find the default test video."""
    candidates = [
        VIDEO_DIR / "2011_09_26_drive_0009_sync.avi",
        VIDEO_DIR / "2011_09_26_drive_0001_sync.avi",
        VIDEO_DIR / "2011_09_26_drive_0005_sync.avi",
    ]
    for v in candidates:
        if v.exists():
            return v
    # fallback: any avi in video_data
    avis = sorted(VIDEO_DIR.glob("2011_*.avi"))
    return avis[0] if avis else None


def get_model_path():
    """Return the best available model path (.engine > .onnx)."""
    if ENGINE_MODEL.exists():
        return str(ENGINE_MODEL)
    if ONNX_MODEL.exists():
        return str(ONNX_MODEL)
    return None


def add_opencv_to_path():
    """Ensure OpenCV, MinGW, and ONNX Runtime DLLs are on PATH for the subprocess."""
    opencv_bin = r"C:\opencv-mingw\x64\mingw\bin"
    if os.path.isdir(opencv_bin) and opencv_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = opencv_bin + ";" + os.environ["PATH"]

    onnxrt_lib = str(ROOT_DIR / "onnxruntime" / "lib")
    if os.path.isdir(onnxrt_lib) and onnxrt_lib not in os.environ.get("PATH", ""):
        os.environ["PATH"] = onnxrt_lib + ";" + os.environ["PATH"]

    tensorrt_lib = r"C:\TensorRT-8.6.1.6\lib"
    if os.path.isdir(tensorrt_lib) and tensorrt_lib not in os.environ.get("PATH", ""):
        os.environ["PATH"] = tensorrt_lib + ";" + os.environ["PATH"]

    cuda_bin = r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.1\bin"
    if os.path.isdir(cuda_bin) and cuda_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = cuda_bin + ";" + os.environ["PATH"]


def run_fcw(video_path=None, camera_id=None, threaded=False):
    """Launch the C++ FCW system executable."""
    if not check_exe():
        return 1

    # Ensure model is available
    model_path = get_model_path()
    if not model_path:
        print("[INFO] No model found. Converting PT -> ONNX ...")
        if not convert_pt_to_onnx():
            return 1
        model_path = get_model_path()

    add_opencv_to_path()

    # Build command
    cmd = [str(EXE_PATH)]

    if video_path:
        cmd += ["--video", str(video_path)]
    elif camera_id is not None:
        cmd += ["--camera", str(camera_id)]
    else:
        video = get_default_video()
        if video:
            cmd += ["--video", str(video)]
        else:
            print("[ERROR] No video found in video_data/")
            return 1

    if threaded:
        cmd.append("--threaded")

    print(f"[INFO] Running: {' '.join(cmd)}")
    print(f"[INFO] Model: {model_path}")
    print(f"[INFO] Working dir: {FCW_DIR}")
    print("[INFO] Press 'q' or ESC in the video window to quit")
    print("=" * 60)

    # Run from fcw-system directory so relative paths in config work
    result = subprocess.run(cmd, cwd=str(FCW_DIR))
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description="FCW System Runner")
    parser.add_argument("--video", "-v", type=str, help="Path to input video")
    parser.add_argument("--camera", type=int, help="Camera device ID")
    parser.add_argument("--threaded", action="store_true", help="Use multi-threaded pipeline")
    parser.add_argument("--convert-model", action="store_true", help="Only convert PT model to ONNX")
    parser.add_argument("--list-videos", action="store_true", help="List available test videos")
    args = parser.parse_args()

    if args.list_videos:
        print("Available videos:")
        for mp4 in sorted(VIDEO_DIR.glob("kitti_*.mp4")):
            print(f"  {mp4.relative_to(ROOT_DIR)}")
        return 0

    if args.convert_model:
        return 0 if convert_pt_to_onnx() else 1

    video = None
    if args.video:
        video = Path(args.video)
        if not video.is_absolute():
            video = ROOT_DIR / video
        if not video.exists():
            print(f"[ERROR] Video not found: {video}")
            return 1

    return run_fcw(video_path=video, camera_id=args.camera, threaded=args.threaded)


if __name__ == "__main__":
    sys.exit(main())
