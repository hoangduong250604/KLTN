from ultralytics import YOLO

# Tải mô hình YOLOv8 nano mặc định
model = YOLO('yolov8n.pt')

# Xuất file sang ONNX với cấu hình chuẩn cho Jetson Nano
model.export(format='onnx', opset=12)