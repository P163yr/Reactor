# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# install system dependencies for video loading / combining
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    libxcb1 \
    libx11-6 \
    libxext6 \
    libsm6 \
    && rm -rf /var/lib/apt/lists/*

# install custom nodes into comfyui
RUN comfy node install comfyui-videohelpersuite
RUN comfy node install video-output-bridge
RUN comfy node install comfyui-frame-interpolation

# install ReActor manually
# Important: do NOT rely on "comfy node install comfyui-reactor"
RUN rm -rf /comfyui/custom_nodes/ComfyUI-ReActor \
    && git clone --depth=1 https://github.com/Gourieff/ComfyUI-ReActor /comfyui/custom_nodes/ComfyUI-ReActor \
    && python3 -m pip install --no-cache-dir setuptools importlib-metadata wheel \
    && python3 -m pip install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-ReActor/requirements.txt \
    && python3 /comfyui/custom_nodes/ComfyUI-ReActor/install.py

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
    --url https://huggingface.co/martintomov/comfy/resolve/main/facedetection/yolov5l-face.pth \
    --relative-path models/facedetection \
    --filename yolov5l-face.pth

# download face parsing helper used during face restoration
RUN comfy model download \
    --url https://huggingface.co/gmk123/GFPGAN/resolve/main/parsing_parsenet.pth \
    --relative-path models/facedetection \
    --filename parsing_parsenet.pth

# download FILM VFI model into the Frame Interpolation custom node checkpoint folder
RUN comfy model download \
    --url https://huggingface.co/nguu/film-pytorch/resolve/887b2c42bebcb323baf6c3b6d59304135699b575/film_net_fp32.pt \
    --relative-path custom_nodes/ComfyUI-Frame-Interpolation/ckpts/film \
    --filename film_net_fp32.pt

# optional: copy fixed input files into comfyui input folder
# COPY input/ /comfyui/input/
