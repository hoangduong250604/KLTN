"""
Convert all KITTI image sequence folders into AVI videos + JSON metadata.

Naming convention: VIDEO NAME = KITTI DRIVE NAME
  e.g., 2011_09_26_drive_0001_sync.avi  (matches KITTI folder exactly)

This ensures a 1:1 mapping between video files and KITTI drive folders,
making OXTS ground-truth auto-detection trivial (match by name, not frame count).

Usage:
    python convert_kitti_to_video.py              # Convert all (skip existing)
    python convert_kitti_to_video.py --force       # Re-convert everything
    python convert_kitti_to_video.py --clean-old   # Remove old kitti_video_XX files first
"""

import cv2
import json
import os
import glob
import argparse
from pathlib import Path

KITTI_DIR = Path(r"C:\VScode\KLTN\KITTI")
OUTPUT_DIR = Path(r"C:\VScode\KLTN\video_data")
FPS = 10  # KITTI standard capture rate


def find_image_dir(drive_path):
    """Find the image_02/data directory inside a KITTI drive folder."""
    for root, dirs, files in os.walk(drive_path):
        if os.path.basename(root) == "data" and "image_02" in root:
            pngs = sorted(glob.glob(os.path.join(root, "*.png")))
            if pngs:
                return root, pngs
    return None, []


def find_oxts_dir(drive_path):
    """Find the oxts/data directory inside a KITTI drive folder."""
    for root, dirs, files in os.walk(drive_path):
        if os.path.basename(root) == "data":
            parent = os.path.basename(os.path.dirname(root))
            if parent == "oxts":
                txts = sorted(glob.glob(os.path.join(root, "*.txt")))
                if txts:
                    return root, len(txts)
    return None, 0


def convert_drive(drive_name, image_dir, images, oxts_dir, oxts_count, force=False):
    """Convert a single drive's images to AVI + JSON.
    Video name = drive name (e.g., 2011_09_26_drive_0001_sync.avi)
    """
    avi_name = f"{drive_name}.avi"
    json_name = f"{drive_name}.json"

    avi_path = OUTPUT_DIR / avi_name
    json_path = OUTPUT_DIR / json_name

    if avi_path.exists() and not force:
        print(f"  [SKIP] {avi_name} already exists")
        return False

    # Read first image to get dimensions
    first = cv2.imread(images[0])
    if first is None:
        print(f"  [ERROR] Cannot read {images[0]}")
        return False

    h, w = first.shape[:2]

    # Create AVI writer (MJPG codec - compatible with MinGW OpenCV)
    fourcc = cv2.VideoWriter_fourcc(*'MJPG')
    writer = cv2.VideoWriter(str(avi_path), fourcc, FPS, (w, h))

    if not writer.isOpened():
        print(f"  [ERROR] Cannot create {avi_name}")
        return False

    frame_count = 0
    for img_path in images:
        frame = cv2.imread(img_path)
        if frame is not None:
            writer.write(frame)
            frame_count += 1

    writer.release()

    # Extract date from drive name (e.g., 2011_09_26_drive_0001_sync → 2011_09_26)
    parts = drive_name.split("_drive_")
    date_str = parts[0] if parts else "unknown"

    # Create JSON metadata
    metadata = {
        "source": drive_name,
        "date": date_str,
        "video_file": avi_name,
        "resolution": {"width": w, "height": h},
        "fps": FPS,
        "total_frames": frame_count,
        "duration_seconds": round(frame_count / FPS, 2),
        "codec": "MJPG",
        "image_dir": str(image_dir),
        "oxts_dir": str(oxts_dir) if oxts_dir else None,
        "oxts_frames": oxts_count,
    }

    with open(json_path, "w") as f:
        json.dump(metadata, f, indent=2)

    oxts_status = f", OXTS: {oxts_count}" if oxts_count > 0 else ", NO OXTS"
    print(f"  [OK] {avi_name} ({frame_count} frames, {w}x{h}, "
          f"{metadata['duration_seconds']}s{oxts_status})")
    return True


def clean_old_videos():
    """Remove old kitti_video_XX_*.avi/json/mp4 files."""
    old_patterns = ["kitti_video_*.avi", "kitti_video_*.json", "kitti_video_*.mp4",
                    "kitti_video_03.avi"]
    removed = 0
    for pattern in old_patterns:
        for f in OUTPUT_DIR.glob(pattern):
            print(f"  [DEL] {f.name}")
            f.unlink()
            removed += 1
    return removed


def main():
    parser = argparse.ArgumentParser(description="Convert KITTI drives to AVI videos")
    parser.add_argument("--force", action="store_true",
                        help="Re-convert even if output already exists")
    parser.add_argument("--clean-old", action="store_true",
                        help="Remove old kitti_video_XX files before converting")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(exist_ok=True)

    if args.clean_old:
        print("Cleaning old video files...")
        removed = clean_old_videos()
        print(f"Removed {removed} old files")
        print("-" * 60)

    # Scan all KITTI drives
    drives = sorted([d for d in KITTI_DIR.iterdir() if d.is_dir()])

    print(f"Found {len(drives)} KITTI drives")
    print(f"Output: {OUTPUT_DIR}")
    print(f"Naming: <drive_name>.avi  (e.g., 2011_09_26_drive_0001_sync.avi)")
    print("-" * 60)

    created = 0
    skipped = 0
    errors = 0

    for drive_path in drives:
        drive_name = drive_path.name
        image_dir, images = find_image_dir(drive_path)
        oxts_dir, oxts_count = find_oxts_dir(drive_path)

        if not images:
            print(f"[SKIP] {drive_name}: no images found")
            skipped += 1
            continue

        print(f"[CONVERT] {drive_name} ({len(images)} images)")
        if convert_drive(drive_name, image_dir, images, oxts_dir, oxts_count,
                         force=args.force):
            created += 1
        else:
            if not (OUTPUT_DIR / f"{drive_name}.avi").exists():
                errors += 1

    print("-" * 60)
    print(f"Done! Created: {created} | Skipped: {skipped} | Errors: {errors}")
    print(f"Videos in: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
