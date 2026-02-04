# =========================
# 1) Builder stage
# =========================
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_PREFER_BINARY=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 python3.10-dev python3.10-venv python3-pip \
    git ca-certificates \
    build-essential pkg-config \
    ffmpeg \
    libavcodec-dev libavformat-dev libavdevice-dev \
    libavutil-dev libswscale-dev libswresample-dev \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN python3.10 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .

# Installation PyTorch avec CUDA 11.8
RUN pip install --upgrade pip setuptools wheel && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu118 && \
    pip install --no-cache-dir -r requirements.txt

# Installation des packages mmlab (selon la doc MusePose)
RUN pip install --no-cache-dir -U openmim && \
    mim install mmengine && \
    mim install "mmcv==2.1.0" && \
    mim install "mmdet==3.2.0" && \
    pip install --no-cache-dir mmpose==1.3.1 --no-deps && \
    pip install --no-cache-dir munkres json_tricks xtcocotools


# =========================
# 2) Runtime stage
# =========================
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    ffmpeg ca-certificates \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    libgomp1 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN useradd -m user
USER user
WORKDIR /home/user/app

# Copie du code source (léger grâce au .dockerignore)
COPY --chown=user:user . .

# Création des dossiers de sortie
RUN mkdir -p output pretrained_weights assets

CMD ["bash"]
