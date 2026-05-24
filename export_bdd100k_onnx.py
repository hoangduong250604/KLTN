"""
Export custom BDD100K YOLOv8s to ONNX format compatible with fcw-system.

fcw-system expects output shape: [1, 14, num_anchors]
  - 14 = 4 (cx, cy, w, h in pixels) + 10 (class scores after sigmoid)

Usage:
    cd c:\\VScode\\KLTN
    .venv_train\\Scripts\\python.exe export_bdd100k_onnx.py
"""

import sys
import os
import torch
import torch.nn as nn
import yaml

# Add the yolov8 model and utils directories to path
base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(base_dir, 'yolov8', 'model'))
sys.path.insert(0, os.path.join(base_dir, 'yolov8', 'utils'))

# Patch torch.load for PyTorch 2.6+ (the .pth file contains a full model object)
_original_torch_load = torch.load
def _patched_torch_load(*args, **kwargs):
    kwargs.setdefault('weights_only', False)
    return _original_torch_load(*args, **kwargs)
torch.load = _patched_torch_load

from tools import load_model


class YOLOv8Wrapper(nn.Module):
    """Wrapper to output in standard YOLOv8 ONNX format [1, 14, num_anchors]"""
    
    def __init__(self, model):
        super().__init__()
        self.model = model
    
    def forward(self, x):
        # Original model returns: (box, cls, dist, grid, grid_stride)
        # box: [B, A, 4] - decoded bbox as x1,y1,x2,y2 in grid units
        # cls: [B, A, 10] - class logits (not sigmoid)
        # grid_stride: [A, 1]
        box, cls, dist, grid, grid_stride = self.model(x)
        
        # Convert box to pixel coordinates: box * grid_stride
        # box is [B, A, 4], grid_stride is [A, 1]
        box_pixels = box * grid_stride  # [B, A, 4] as x1,y1,x2,y2 in pixels
        
        # Convert x1,y1,x2,y2 to cx,cy,w,h (what fcw-system decoder expects)
        x1 = box_pixels[:, :, 0:1]
        y1 = box_pixels[:, :, 1:2]
        x2 = box_pixels[:, :, 2:3]
        y2 = box_pixels[:, :, 3:4]
        cx = (x1 + x2) / 2.0
        cy = (y1 + y2) / 2.0
        w = x2 - x1
        h = y2 - y1
        box_cxcywh = torch.cat([cx, cy, w, h], dim=2)  # [B, A, 4]
        
        # Apply sigmoid to class scores
        cls_scores = cls.sigmoid()  # [B, A, 10]
        
        # Concatenate: [B, A, 14]
        output = torch.cat([box_cxcywh, cls_scores], dim=2)
        
        # Transpose to [B, 14, A] (what fcw-system expects)
        output = output.permute(0, 2, 1).contiguous()
        
        return output


def main():
    device = 'cpu'  # Export on CPU
    
    # Model config
    model_yaml = 'yolov8/config/model/yolov8s.yaml'
    weight_path = 'yolov8/config/weight/yolov8s.pth'
    cls_yaml = 'yolov8/dataset/bdd100k/cls.yaml'
    
    # Load classes
    cls = yaml.safe_load(open(cls_yaml, encoding='utf-8'))
    print(f"Classes ({len(cls)}): {cls}")
    
    # Input size - use 960x544 (original training resolution)
    input_h, input_w = 544, 960
    shape = [input_h, input_w]
    
    print(f"Loading model from {weight_path}...")
    model = load_model(model_yaml, cls, weight_path, fused=True, shape=shape, device=device)
    model.eval()
    model.to(device)
    
    # Wrap model for correct output format
    wrapper = YOLOv8Wrapper(model)
    wrapper.eval()
    
    # Test forward pass
    dummy_input = torch.randn(1, 3, input_h, input_w).to(device)
    with torch.no_grad():
        output = wrapper(dummy_input)
    
    print(f"Input shape: {dummy_input.shape}")
    print(f"Output shape: {output.shape}")  # Should be [1, 14, num_anchors]
    num_anchors = output.shape[2]
    print(f"Num anchors: {num_anchors}")
    print(f"Output format: [1, {4}+{len(cls)}, {num_anchors}]")
    
    # Export to ONNX
    onnx_path = 'fcw-system/models/yolov8s.onnx'
    print(f"\nExporting to {onnx_path}...")
    
    torch.onnx.export(
        wrapper,
        dummy_input,
        onnx_path,
        opset_version=12,
        input_names=['images'],
        output_names=['output0'],
        dynamic_axes=None,  # Fixed size
    )
    
    # Verify
    size_mb = os.path.getsize(onnx_path) / 1024 / 1024
    print(f"Export done! Size: {size_mb:.1f} MB")
    
    # Update labels.txt
    labels_path = 'fcw-system/models/labels.txt'
    with open(labels_path, 'w') as f:
        for c in cls:
            f.write(c + '\n')
    print(f"Updated {labels_path} with {len(cls)} classes")
    print(f"Classes: {cls}")
    
    print("\nDone! Model ready for fcw-system.")


if __name__ == '__main__':
    main()
