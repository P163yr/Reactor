# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# install system dependencies for video loading / combining
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# install custom nodes into comfyui
RUN comfy node install comfyui-videohelpersuite
RUN comfy node install comfyui-frame-interpolation
RUN comfy node install comfyui-reactor

# download ReActor HyperSwap model
RUN comfy model download \
    --url https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1a_256.onnx \
    --relative-path models/hyperswap \
    --filename hyperswap_1a_256.onnx

# download ReActor face restore model
RUN comfy model download \
    --url https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/codeformer-v0.1.0.pth \
    --relative-path models/facerestore_models \
    --filename codeformer-v0.1.0.pth

# download YOLOv5l face detection helper used by ReActor / CodeFormer
RUN comfy model download \
    --url https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/yolov5l-face.pth \
    --relative-path models/facedetection \
    --filename yolov5l-face.pth

# download face parsing helper used during face restoration
RUN comfy model download \
    --url https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/parsing_parsenet.pth \
    --relative-path models/facedetection \
    --filename parsing_parsenet.pth

# download FILM VFI model into the Frame Interpolation custom node checkpoint folder
RUN comfy model download \
    --url https://github.com/Fannovel16/ComfyUI-Frame-Interpolation/releases/download/models/film_net_fp32.pt \
    --relative-path custom_nodes/ComfyUI-Frame-Interpolation/ckpts/film \
    --filename film_net_fp32.pt

# copy all input data into comfyui input folder
# Your workflow expects:
# - Elon_Musk_-_54820081119_(cropped).jpg.webp
# - Download (1).mp4
# Put those inside an input/ folder next to this Dockerfile, then uncomment:
# COPY input/ /comfyui/input/
