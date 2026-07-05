#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FCW System – Thesis Chapter 4 Chart Generator
Generates 8 publication-quality charts (300 DPI) from KITTI evaluation data.

Usage:
    python plot_thesis_charts.py

Output:
    charts/H4_01_detection_performance.png
    charts/H4_02_distance_mae.png
    charts/H4_03_pipeline_timing_pie.png
    charts/H4_04_distance_comparison_0061.png
    charts/H4_05_scatter_distance.png
    charts/H4_06_velocity_mae.png
    charts/H4_07_resolution_tradeoff.png
    charts/H4_08_summary_dashboard.png
"""

import json
import os
import re
import warnings
import numpy as np
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.gridspec import GridSpec

warnings.filterwarnings("ignore")
matplotlib.rcParams["axes.unicode_minus"] = False

# ──────────────────────────────────────────────────────────────────────────────
# PATHS
# ──────────────────────────────────────────────────────────────────────────────
EVAL_JSON    = "results/evaluation/evaluation_summary.json"
EVAL_DIR     = "results/evaluation"
OUT_DIR      = "charts"
DPI          = 300

os.makedirs(OUT_DIR, exist_ok=True)

# ──────────────────────────────────────────────────────────────────────────────
# GLOBAL STYLE  (academic / thesis look)
# ──────────────────────────────────────────────────────────────────────────────
plt.rcParams.update({
    "font.family"      : "DejaVu Serif",
    "font.size"        : 11,
    "axes.titlesize"   : 12,
    "axes.titleweight" : "bold",
    "axes.labelsize"   : 11,
    "xtick.labelsize"  : 9,
    "ytick.labelsize"  : 9,
    "legend.fontsize"  : 9,
    "legend.framealpha": 0.9,
    "axes.grid"        : True,
    "grid.linestyle"   : ":",
    "grid.alpha"       : 0.55,
    "figure.facecolor" : "white",
    "axes.facecolor"   : "#FAFAFA",
    "savefig.dpi"      : DPI,
    "savefig.bbox"     : "tight",
})

COLORS = {
    "blue"  : "#1565C0",
    "green" : "#2E7D32",
    "orange": "#E65100",
    "red"   : "#C62828",
    "purple": "#6A1B9A",
    "teal"  : "#00695C",
    "grey"  : "#546E7A",
    "light_blue"  : "#90CAF9",
    "light_green" : "#A5D6A7",
    "light_orange": "#FFCC80",
    "light_red"   : "#EF9A9A",
}

# ──────────────────────────────────────────────────────────────────────────────
# LOAD  evaluation_summary.json
# ──────────────────────────────────────────────────────────────────────────────
with open(EVAL_JSON, encoding="utf-8") as f:
    summary = json.load(f)

df = pd.DataFrame(summary)
df["label"] = (df["drive"]
               .str.replace("2011_09_26_drive_", "D", regex=False)
               .str.replace("_sync", "", regex=False))

# ──────────────────────────────────────────────────────────────────────────────
# HELPER – parse frame-by-frame data from a report .txt
# ──────────────────────────────────────────────────────────────────────────────
def _parse_report(drive_name: str):
    """Return lists (frame_ids, gt_dist, sys_dist) from a drive report file."""
    path = os.path.join(EVAL_DIR, f"{drive_name}_report.txt")
    if not os.path.exists(path):
        return [], [], []

    frame_ids, gt_dist, sys_dist = [], [], []
    in_block = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if "SAMPLE FRAME-BY-FRAME" in line:
                in_block = True
                continue
            if "END OF REPORT" in line:
                break
            if not in_block:
                continue
            # Skip header / separator lines
            stripped = line.strip()
            if not stripped or stripped.startswith("Frame") or stripped.startswith("-"):
                continue
            parts = stripped.split()
            if len(parts) >= 4:
                try:
                    frame_ids.append(int(parts[0]))
                    gt_dist.append(float(parts[2]))
                    sys_dist.append(float(parts[3]))
                except ValueError:
                    pass
    return frame_ids, gt_dist, sys_dist


# ══════════════════════════════════════════════════════════════════════════════
# CHART 1 – Detection Performance (Recall & Precision) per drive
# ══════════════════════════════════════════════════════════════════════════════
def chart1_detection_performance():
    ds = df.sort_values("recall").reset_index(drop=True)
    x  = np.arange(len(ds))
    w  = 0.38

    fig, ax = plt.subplots(figsize=(13, 6))

    ax.bar(x - w/2, ds["recall"],    w, label="Recall (%)",
           color=COLORS["blue"],  alpha=0.85, edgecolor="white", linewidth=0.5)
    ax.bar(x + w/2, ds["precision"], w, label="Precision (%)",
           color=COLORS["green"], alpha=0.85, edgecolor="white", linewidth=0.5)

    # Reference threshold
    ax.axhline(90, color="crimson", linestyle="--", linewidth=1.3,
               label="Ngưỡng tham chiếu 90%")

    # Average annotations
    avg_r = df["recall"].mean()
    avg_p = df["precision"].mean()
    ax.axhline(avg_r, color=COLORS["blue"],  linestyle=":", linewidth=1.1, alpha=0.7)
    ax.axhline(avg_p, color=COLORS["green"], linestyle=":", linewidth=1.1, alpha=0.7)

    ax.set_xticks(x)
    ax.set_xticklabels(ds["label"], rotation=45, ha="right")
    ax.set_ylim(0, 115)
    ax.set_xlabel("KITTI Drive Sequence")
    ax.set_ylabel("Giá trị (%)")
    ax.set_title(
        f"Hình 4.X – Hiệu năng Phát hiện Phương tiện theo Đoạn KITTI\n"
        f"Trung bình: Recall = {avg_r:.1f}% | Precision = {avg_p:.1f}%"
    )
    ax.legend(loc="lower right", ncol=3)

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_01_detection_performance.png"
    plt.savefig(path)
    plt.close()
    print(f"  [1] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 2 – Distance MAE per drive (colour-coded by quality)
# ══════════════════════════════════════════════════════════════════════════════
def chart2_distance_mae():
    ds = df.sort_values("distance_mae").reset_index(drop=True)
    x  = np.arange(len(ds))

    bar_colors = [
        COLORS["green"]  if v <= 2.0 else
        COLORS["orange"] if v <= 4.0 else
        COLORS["red"]
        for v in ds["distance_mae"]
    ]

    fig, ax = plt.subplots(figsize=(13, 5))
    ax.bar(x, ds["distance_mae"], color=bar_colors, alpha=0.85,
           edgecolor="white", linewidth=0.5)

    # NOTE: unweighted mean of each drive's own MAE (every drive counts
    # equally regardless of sample count). evaluate_fcw.py's console summary
    # instead prints a POOLED/sample-weighted mean over every individual
    # sample across all drives — the two will not generally agree; know
    # which one a cited thesis number came from.
    avg = df["distance_mae"].mean()
    ax.axhline(avg, color="navy", linestyle="--", linewidth=1.5,
               label=f"Trung bình MAE = {avg:.2f} m")

    ax.set_xticks(x)
    ax.set_xticklabels(ds["label"], rotation=45, ha="right")
    ax.set_xlabel("KITTI Drive Sequence")
    ax.set_ylabel("MAE khoảng cách (m)")
    ax.set_title("Hình 4.X – Sai số Ước lượng Khoảng cách (MAE) theo Đoạn KITTI")

    handles = [
        mpatches.Patch(color=COLORS["green"],  alpha=0.85, label="Tốt  (MAE ≤ 2 m)"),
        mpatches.Patch(color=COLORS["orange"], alpha=0.85, label="TB   (2–4 m)"),
        mpatches.Patch(color=COLORS["red"],    alpha=0.85, label="Khó  (MAE > 4 m)"),
        plt.Line2D([0],[0], color="navy", linestyle="--",
                   label=f"Trung bình = {avg:.2f} m"),
    ]
    ax.legend(handles=handles, loc="upper left")

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_02_distance_mae.png"
    plt.savefig(path)
    plt.close()
    print(f"  [2] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 3 – Pipeline timing breakdown (pie × 2: Jetson vs Desktop)
# ══════════════════════════════════════════════════════════════════════════════
def chart3_pipeline_timing():
    stages   = ["YOLOv8 Inference", "Visualization", "Camera Buffer", "Tracking+TTC+Risk"]
    colors   = [COLORS["red"], COLORS["blue"], COLORS["green"], COLORS["orange"]]
    sizes_j  = [120, 5, 4, 1]   # ms – Jetson Nano
    sizes_d  = [150, 8, 4, 1]   # ms – Desktop
    total_j  = sum(sizes_j)
    total_d  = sum(sizes_d)

    platforms = ["Jetson Nano\n(TensorRT FP16)", "Desktop\n(ONNX Runtime CPU)"]
    all_sizes = [sizes_j, sizes_d]
    totals    = [total_j, total_d]

    fig, ax = plt.subplots(figsize=(12, 3.8))

    bar_height = 0.42
    y_pos = [1.0, 0.0]   # two rows

    THRESHOLD = 9   # ms – slices below this get a single combined label

    for row, (sizes, total, y) in enumerate(zip(all_sizes, totals, y_pos)):
        left = 0
        small_start_x = None   # x where small slices begin
        small_total   = 0

        for sz, color, stage in zip(sizes, colors, stages):
            ax.barh(y, sz, bar_height, left=left, color=color,
                    alpha=0.88, edgecolor="white", linewidth=1.2)
            pct = sz / total * 100
            mid = left + sz / 2

            if sz >= THRESHOLD:
                # Wide enough – label inside
                ax.text(mid, y, f"{sz} ms\n({pct:.1f}%)",
                        ha="center", va="center", fontsize=9,
                        fontweight="bold", color="white")
            else:
                # Track the combined "small" group
                if small_start_x is None:
                    small_start_x = left
                small_total += sz

            left += sz

        # One combined annotation for all small slices + total
        small_pct  = small_total / total * 100
        tip_x      = total
        text_x     = total + 8
        oy         = bar_height * 0.85 * (1 if row == 0 else -1)
        detail_parts = [
            f"{st}: {sz} ms"
            for st, sz in zip(stages, sizes) if sz < THRESHOLD
        ]
        detail = "  |  ".join(detail_parts)
        label_text = (
            f"Remaining  {small_total} ms ({small_pct:.1f}%)\n"
            f"{detail}\n"
            f"Total: {total} ms  (~{1000//total} FPS)"
        ) if small_total > 0 else f"Total: {total} ms  (~{1000//total} FPS)"

        ax.annotate(
            label_text,
            xy=(tip_x, y),
            xytext=(text_x, y + oy),
            fontsize=8, color="#111111",
            ha="left", va="center",
            arrowprops=dict(arrowstyle="-", color="#888888", lw=0.9),
            bbox=dict(boxstyle="round,pad=0.3", fc="white",
                      ec="#BBBBBB", alpha=0.97, lw=0.8),
        )

    ax.set_yticks(y_pos)
    ax.set_yticklabels(platforms, fontsize=11)
    ax.set_xlabel("Processing Time (ms per frame)", fontsize=11)
    ax.set_xlim(0, max(totals) * 1.75)
    ax.set_ylim(-0.85, 1.85)
    ax.set_title(
        "Figure 4.X  -  FCW Pipeline Processing Time Breakdown\n"
        "(YOLOv8s 768x448, KITTI sequences)",
        fontsize=12, fontweight="bold", pad=10,
    )
    ax.grid(axis="x", linestyle=":", alpha=0.5)
    ax.set_axisbelow(True)

    legend_patches = [mpatches.Patch(color=c, alpha=0.88, label=lbl)
                      for c, lbl in zip(colors, stages)]
    fig.legend(handles=legend_patches,
               loc="lower center",
               bbox_to_anchor=(0.5, -0.08),
               ncol=4, fontsize=9,
               framealpha=0.92, borderpad=0.6)

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_03_pipeline_timing_pie.png"
    plt.savefig(path, dpi=DPI, bbox_inches="tight", facecolor="white")
    plt.close()
    print(f"  [3] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 4 – GT vs Estimated distance (Drive 0061, frame-by-frame)
# ══════════════════════════════════════════════════════════════════════════════
def chart4_distance_comparison():
    drive = "2011_09_26_drive_0061"
    frames, gt, sys_ = _parse_report(drive)
    if not frames:
        print(f"  [4] Skipped – no data for {drive}")
        return

    errors = np.abs(np.array(sys_) - np.array(gt))
    mae    = errors.mean()

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)

    # ── Top: distance curves
    ax1.plot(frames, gt,   color="black",          linewidth=1.6,
             linestyle="--", marker="o", markersize=2.5,
             label="Ground Truth (KITTI Tracklets)")
    ax1.plot(frames, sys_, color=COLORS["blue"],    linewidth=1.6,
             marker="^",  markersize=2.5,
             label="Hệ thống ước lượng (Pinhole Camera)")
    ax1.fill_between(frames, gt, sys_, alpha=0.13, color="red", label="Sai số")
    ax1.set_ylabel("Khoảng cách (m)")
    ax1.set_title(
        f"Hình 4.X – So sánh Khoảng cách Ước lượng vs Ground Truth\n"
        f"Drive 0061  |  MAE = {mae:.2f} m  |  {len(frames)} mẫu"
    )
    ax1.legend(loc="upper right")

    # ── Bottom: per-frame error bar
    ax2.bar(frames, errors, color=COLORS["orange"], alpha=0.75,
            edgecolor="none", label="|Sai số| (m)")
    ax2.axhline(mae, color="navy", linestyle="--", linewidth=1.5,
                label=f"MAE = {mae:.2f} m")
    ax2.set_xlabel("Frame Index")
    ax2.set_ylabel("|Sai số| (m)")
    ax2.set_title("Phân bố Sai số Khoảng cách theo Frame")
    ax2.legend(loc="upper right")

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_04_distance_comparison_0061.png"
    plt.savefig(path)
    plt.close()
    print(f"  [4] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 5 – Scatter: GT vs Estimated distance (all drives)
# ══════════════════════════════════════════════════════════════════════════════
def chart5_scatter_distance():
    all_gt, all_sys = [], []
    for row in summary:
        f, g, s = _parse_report(row["drive"])
        all_gt.extend(g)
        all_sys.extend(s)

    if not all_gt:
        print("  [5] Skipped – no frame data found")
        return

    all_gt  = np.array(all_gt)
    all_sys = np.array(all_sys)
    mae  = np.mean(np.abs(all_sys - all_gt))
    rmse = np.sqrt(np.mean((all_sys - all_gt) ** 2))

    fig, ax = plt.subplots(figsize=(8, 7))

    ax.scatter(all_gt, all_sys, alpha=0.30, s=12,
               color=COLORS["blue"], label=f"Mẫu (N={len(all_gt)})")

    lim = max(all_gt.max(), all_sys.max()) * 1.05
    # Perfect line
    ax.plot([0, lim], [0, lim], "k--", linewidth=1.5, label="Ước lượng hoàn hảo")
    # ±25 % band
    ax.fill_between([0, lim], [0, lim*0.75], [0, lim*1.25],
                    alpha=0.08, color="green", label="Dải ±25%")
    # Linear regression
    m, b = np.polyfit(all_gt, all_sys, 1)
    xs = np.linspace(0, lim, 200)
    ax.plot(xs, m*xs + b, color=COLORS["red"], linewidth=1.5,
            label=f"Hồi quy (slope={m:.3f}, b={b:.2f})")

    ax.set_xlim(0, lim);  ax.set_ylim(0, lim)
    ax.set_xlabel("Khoảng cách Ground Truth (m)")
    ax.set_ylabel("Khoảng cách Ước lượng (m)")
    ax.set_title(
        f"Hình 4.X – Tương quan Khoảng cách Ước lượng vs Ground Truth\n"
        f"MAE = {mae:.2f} m  |  RMSE = {rmse:.2f} m  |  N = {len(all_gt)}"
    )
    ax.legend(loc="upper left")

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_05_scatter_distance.png"
    plt.savefig(path)
    plt.close()
    print(f"  [5] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 6 – Velocity MAE per drive
# ══════════════════════════════════════════════════════════════════════════════
def chart6_velocity_mae():
    ds = df.sort_values("velocity_mae").reset_index(drop=True)
    x  = np.arange(len(ds))

    bar_colors = [
        COLORS["green"]  if v <= 2.0 else
        COLORS["orange"] if v <= 5.0 else
        COLORS["red"]
        for v in ds["velocity_mae"]
    ]

    fig, ax = plt.subplots(figsize=(13, 5))
    ax.bar(x, ds["velocity_mae"], color=bar_colors, alpha=0.85,
           edgecolor="white", linewidth=0.5)

    avg = df["velocity_mae"].mean()
    ax.axhline(avg, color="navy", linestyle="--", linewidth=1.5,
               label=f"Trung bình MAE = {avg:.2f} m/s")

    ax.set_xticks(x)
    ax.set_xticklabels(ds["label"], rotation=45, ha="right")
    ax.set_xlabel("KITTI Drive Sequence")
    ax.set_ylabel("Closing Speed MAE (m/s)")
    ax.set_title("Hình 4.X – Sai số Ước lượng Vận tốc Tiếp cận (Velocity MAE) theo Đoạn KITTI")

    handles = [
        mpatches.Patch(color=COLORS["green"],  alpha=0.85, label="Tốt  (≤ 2 m/s)"),
        mpatches.Patch(color=COLORS["orange"], alpha=0.85, label="TB   (2–5 m/s)"),
        mpatches.Patch(color=COLORS["red"],    alpha=0.85, label="Khó  (> 5 m/s)"),
        plt.Line2D([0],[0], color="navy", linestyle="--",
                   label=f"Trung bình = {avg:.2f} m/s"),
    ]
    ax.legend(handles=handles, loc="upper left")

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_06_velocity_mae.png"
    plt.savefig(path)
    plt.close()
    print(f"  [6] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 7 – Resolution vs FPS trade-off
# ══════════════════════════════════════════════════════════════════════════════
def chart7_resolution_tradeoff():
    resolutions  = ["640×640", "768×448\n(đề tài)", "960×544"]
    infer_j_ms   = [100, 120, 190]   # Jetson Nano inference ms
    infer_d_ms   = [125, 150, 225]   # Desktop ONNX ms (estimated)
    fps_j        = [9.5,  8.5,  4.8]
    fps_d        = [7.5,  6.2,  4.0]

    x = np.arange(len(resolutions))
    w = 0.35

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5.5))

    # ── Left: Inference time
    b1 = ax1.bar(x - w/2, infer_j_ms, w,
                 label="Jetson Nano (TensorRT FP16)",
                 color=COLORS["blue"], alpha=0.82, edgecolor="white")
    b2 = ax1.bar(x + w/2, infer_d_ms, w,
                 label="Desktop (ONNX Runtime CPU)",
                 color=COLORS["green"], alpha=0.82, edgecolor="white")

    # Highlight chosen resolution
    for bars in [b1, b2]:
        bars[1].set_edgecolor("crimson")
        bars[1].set_linewidth(2.5)

    for bar, val in zip(b1, infer_j_ms):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
                 f"{val} ms", ha="center", va="bottom", fontsize=9, fontweight="bold")
    for bar, val in zip(b2, infer_d_ms):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
                 f"{val} ms", ha="center", va="bottom", fontsize=9, fontweight="bold")

    ax1.set_xticks(x);  ax1.set_xticklabels(resolutions)
    ax1.set_ylabel("Thời gian Inference (ms/frame)")
    ax1.set_title("Thời gian Suy diễn YOLOv8s\ntheo Kích thước Đầu vào")
    ax1.legend()
    ax1.text(1, 5, "← Đề tài chọn", ha="center", color="crimson",
             fontsize=9, fontweight="bold")

    # ── Right: FPS
    b3 = ax2.bar(x - w/2, fps_j, w,
                 label="Jetson Nano (TensorRT FP16)",
                 color=COLORS["blue"], alpha=0.82, edgecolor="white")
    b4 = ax2.bar(x + w/2, fps_d, w,
                 label="Desktop (ONNX Runtime CPU)",
                 color=COLORS["green"], alpha=0.82, edgecolor="white")
    for bars in [b3, b4]:
        bars[1].set_edgecolor("crimson")
        bars[1].set_linewidth(2.5)

    ax2.set_xticks(x);  ax2.set_xticklabels(resolutions)
    ax2.set_ylabel("FPS (frames/second)")
    ax2.set_title("FPS Tổng Pipeline\ntheo Kích thước Đầu vào")
    ax2.legend()
    ax2.text(1, 0.3, "← Đề tài chọn", ha="center", color="crimson",
             fontsize=9, fontweight="bold")

    fig.suptitle(
        "Hình 4.X – Đánh đổi Độ phân giải vs Tốc độ FPS (Resolution–FPS Trade-off)",
        fontsize=12, fontweight="bold", y=1.02,
    )
    plt.tight_layout()
    path = f"{OUT_DIR}/H4_07_resolution_tradeoff.png"
    plt.savefig(path)
    plt.close()
    print(f"  [7] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 8 – Summary metric bar (horizontal gauge bars)
# ══════════════════════════════════════════════════════════════════════════════
def chart8_summary_dashboard():
    metrics = [
        ("Recall (phát hiện phương tiện)",  93.4,  "%",     100,   COLORS["blue"]),
        ("Precision (phát hiện phương tiện)", 99.1, "%",     100,   COLORS["green"]),
        ("Distance MAE",                     2.19,  "m",       8,   COLORS["orange"]),
        ("Distance RMSE",                    2.97,  "m",       8,   COLORS["teal"]),
        ("Velocity MAE (closing speed)",     2.68,  "m/s",    12,   COLORS["purple"]),
        ("Tốc độ pipeline – Jetson Nano",    8.5,   "FPS",    15,   COLORS["grey"]),
    ]

    fig, axes = plt.subplots(len(metrics), 1, figsize=(10, 8))
    fig.suptitle(
        "Hình 4.X – Tổng kết Kết quả Đánh giá Hệ thống FCW\n"
        "(25 Đoạn KITTI – Phương tiện: Car, Van, Truck, Tram)",
        fontsize=12, fontweight="bold",
    )

    for ax, (label, val, unit, max_val, color) in zip(axes, metrics):
        # Background bar (full range)
        ax.barh(0, max_val, height=0.55, color="#E0E0E0", edgecolor="none")
        # Value bar
        ax.barh(0, val,     height=0.55, color=color,    alpha=0.88, edgecolor="none")
        # Value text inside bar
        txt_x = max(val * 0.5, val - max_val * 0.03)
        ax.text(txt_x, 0, f"{val} {unit}",
                va="center", ha="center", fontsize=11, fontweight="bold",
                color="white" if val / max_val > 0.35 else color)
        # Label on the left
        ax.text(-max_val * 0.02, 0, label,
                va="center", ha="right", fontsize=10, color="#333333")
        ax.set_xlim(-max_val * 0.45, max_val * 1.05)
        ax.set_ylim(-0.5, 0.5)
        ax.axis("off")

    plt.tight_layout(rect=[0, 0, 1, 0.93])
    path = f"{OUT_DIR}/H4_08_summary_dashboard.png"
    plt.savefig(path, facecolor="white")
    plt.close()
    print(f"  [8] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# CHART 0 – BDD100K per-class mAP (YOLOv8s, 960×544)
# ══════════════════════════════════════════════════════════════════════════════
def chart0_bdd100k_map_perclass():
    # Official results from yolov8/README.md (input 960×544)
    data = [
        ("car",           82.9, 58.3, 101893),
        ("traffic sign",  73.1, 45.4,  33914),
        ("traffic light", 71.2, 33.1,  24869),
        ("person",        70.8, 41.7,  13085),
        ("bus",           66.8, 56.2,   1597),
        ("truck",         66.3, 53.0,   4233),
        ("rider",         57.8, 33.8,    646),
        ("bike",          56.8, 32.6,   1000),
        ("motor",         54.3, 30.1,    447),
        ("train",          0.0,  0.0,     14),
    ]

    classes   = [d[0] for d in data]
    ap50      = np.array([d[1] for d in data])
    ap50_95   = np.array([d[2] for d in data])
    instances = [d[3] for d in data]

    n   = len(classes)
    y   = np.arange(n)
    h   = 0.35          # bar height

    fig, ax = plt.subplots(figsize=(10, 6))

    bars1 = ax.barh(y + h/2, ap50,    h, label="mAP@0.5",
                    color=COLORS["blue"],   alpha=0.85, edgecolor="white")
    bars2 = ax.barh(y - h/2, ap50_95, h, label="mAP@0.5:0.95",
                    color=COLORS["orange"], alpha=0.85, edgecolor="white")

    # Value labels on bars
    for bar, val in zip(bars1, ap50):
        if val > 0:
            ax.text(val + 0.8, bar.get_y() + bar.get_height()/2,
                    f"{val:.1f}%", va="center", ha="left", fontsize=8.5,
                    color=COLORS["blue"], fontweight="bold")
    for bar, val in zip(bars2, ap50_95):
        if val > 0:
            ax.text(val + 0.8, bar.get_y() + bar.get_height()/2,
                    f"{val:.1f}%", va="center", ha="left", fontsize=8.5,
                    color=COLORS["orange"])

    # Instance count annotation on right margin
    for i, (cls, inst) in enumerate(zip(classes, instances)):
        ax.text(102, y[i], f"n={inst:,}", va="center", ha="left",
                fontsize=7.5, color="#555555")

    # Overall mean lines
    mean50    = 60.0
    mean50_95 = 38.4
    ax.axvline(mean50,    color=COLORS["blue"],   linestyle="--", lw=1.2,
               label=f"mAP@0.5 trung binh = {mean50:.1f}%")
    ax.axvline(mean50_95, color=COLORS["orange"], linestyle="--", lw=1.2,
               label=f"mAP@0.5:0.95 trung binh = {mean50_95:.1f}%")

    # Zero-result highlight for train
    train_idx = classes.index("train")
    ax.axhspan(train_idx - 0.5, train_idx + 0.5, color="#FFF3E0", zorder=0)
    ax.text(30, train_idx, "Chi 14 instances\nkhong du de hoc",
            va="center", ha="center", fontsize=7.5, color="#BF360C",
            fontstyle="italic")

    ax.set_yticks(y)
    ax.set_yticklabels(classes, fontsize=10)
    ax.set_xlabel("AP (%)")
    ax.set_xlim(0, 118)
    ax.set_title(
        "Hinh 4.1 – Ket qua mAP theo tung lop doi tuong\n"
        "YOLOv8s tren BDD100K validation set (960x544, 10 lop)\n"
        "(luc huan luyen/danh gia; suy dien trien khai hien dung 768x448 de tang FPS,\n"
        "chua do lai mAP theo lop o do phan giai nay)",
        fontsize=11, fontweight="bold",
    )
    ax.legend(loc="lower right", fontsize=9)
    ax.invert_yaxis()   # highest mAP at top

    plt.tight_layout()
    path = f"{OUT_DIR}/H4_00_bdd100k_map_perclass.png"
    plt.savefig(path)
    plt.close()
    print(f"  [0] {path}")


# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print(f"\nGenerating thesis charts -> {OUT_DIR}/\n")
    chart0_bdd100k_map_perclass()
    chart1_detection_performance()
    chart2_distance_mae()
    chart3_pipeline_timing()
    chart4_distance_comparison()
    chart5_scatter_distance()
    chart6_velocity_mae()
    chart7_resolution_tradeoff()
    chart8_summary_dashboard()
    files = os.listdir(OUT_DIR)
    print(f"\nDone! {len(files)} chart(s) saved in '{OUT_DIR}/':\n")
    for f in sorted(files):
        print(f"  {f}")
