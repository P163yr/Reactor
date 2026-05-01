# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# avoid interactive apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# install system dependencies for video loading / combining
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    curl \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    libxcb1 \
    libx11-6 \
    libxext6 \
    libsm6 \
    && rm -rf /var/lib/apt/lists/*

# install custom nodes
# VideoHelperSuite provides VHS_LoadVideo and VHS_VideoCombine.
# Frame Interpolation provides FILM VFI.
RUN comfy node install comfyui-videohelpersuite

RUN comfy node install comfyui-frame-interpolation

# VideoOutputBridge makes VHS_VideoCombine outputs return through RunPod's normal images/base64 payload.
# This is needed to avoid success_no_images for MP4 outputs.
RUN comfy node install video-output-bridge

# install ReActor manually so ReActorFaceSwap definitely exists
# ReActor's current repo says the newer ReActor Core does not need InsightFace or C++ build tools.
RUN rm -rf /comfyui/custom_nodes/ComfyUI-ReActor \
    && git clone --depth=1 https://github.com/Gourieff/ComfyUI-ReActor /comfyui/custom_nodes/ComfyUI-ReActor \
    && python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel importlib-metadata \
    && python3 -m pip install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-ReActor/requirements.txt \
    && python3 /comfyui/custom_nodes/ComfyUI-ReActor/install.py

# create model downloader script
# Models are downloaded at container startup instead of Docker build time.
RUN cat > /download_models.sh <<'EOF'
#!/usr/bin/env bash
set -e

download_if_missing() {
  URL="$1"
  OUT="$2"

  if [ -f "$OUT" ]; then
    echo "[models] exists: $OUT"
    return 0
  fi

  echo "[models] downloading: $OUT"
  mkdir -p "$(dirname "$OUT")"

  curl -L \
    --retry 8 \
    --retry-delay 5 \
    --retry-all-errors \
    --connect-timeout 30 \
    -o "$OUT.tmp" \
    "$URL"

  mv "$OUT.tmp" "$OUT"
  echo "[models] done: $OUT"
}

# ReActor HyperSwap model
# ReActor HyperSwap models belong in ComfyUI/models/hyperswap.
download_if_missing \
  "https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1a_256.onnx" \
  "/comfyui/models/hyperswap/hyperswap_1a_256.onnx"

# ReActor face restore model
download_if_missing \
  "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/codeformer-v0.1.0.pth" \
  "/comfyui/models/facerestore_models/codeformer-v0.1.0.pth"

# YOLOv5l face detection helper
download_if_missing \
  "https://huggingface.co/martintomov/comfy/resolve/main/facedetection/yolov5l-face.pth" \
  "/comfyui/models/facedetection/yolov5l-face.pth"

# Face parsing helper used during face restoration
download_if_missing \
  "https://huggingface.co/gmk123/GFPGAN/resolve/main/parsing_parsenet.pth" \
  "/comfyui/models/facedetection/parsing_parsenet.pth"

# FILM VFI model
download_if_missing \
  "https://huggingface.co/nguu/film-pytorch/resolve/887b2c42bebcb323baf6c3b6d59304135699b575/film_net_fp32.pt" \
  "/comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/film/film_net_fp32.pt"
EOF

RUN chmod +x /download_models.sh

# Wrap the original worker start command without knowing the base image CMD in advance.
# This downloads models first, then starts the normal RunPod ComfyUI worker.
RUN cat > /start_with_models.sh <<'EOF'
#!/usr/bin/env bash
set -e

echo "[startup] checking/downloading required models..."
/download_models.sh

echo "[startup] starting worker..."
exec "$@"
EOF

RUN chmod +x /start_with_models.sh

# Keep the base image's original CMD, but run model setup before it.
ENTRYPOINT ["/start_with_models.sh"]
