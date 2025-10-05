FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VERSION=12.9
ENV CUDA_PKG_VERSION=12-9
ENV CUDA_HOME=/usr/local/cuda-12.9
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PYTHONUNBUFFERED=1
ENV TZ=Asia/Shanghai

# 设置工作目录
WORKDIR /workspace

# 更新系统并安装基础依赖
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    build-essential \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    git \
    cmake \
    pkg-config \
    libsndfile1 \
    libasound2-dev \
    portaudio19-dev \
    libportaudio2 \
    libportaudiocpp0 \
    ffmpeg \
    sox \
    libsox-fmt-all \
    vim \
    htop \
    bc \
    && rm -rf /var/lib/apt/lists/*

# 添加 NVIDIA GPG 密钥和仓库
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm cuda-keyring_1.1-1_all.deb

# 安装 CUDA 12.9 工具包
RUN apt-get update && apt-get install -y \
    cuda-toolkit-12-9 \
    cuda-drivers \
    && rm -rf /var/lib/apt/lists/*

# 创建符号链接
RUN ln -sf /usr/local/cuda-12.9 /usr/local/cuda

# 创建用户和虚拟环境
RUN useradd -m -s /bin/bash paddlespeech && \
    echo "paddlespeech ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换到 paddlespeech 用户
USER paddlespeech
WORKDIR /home/paddlespeech

# 创建 Python 虚拟环境
RUN python3.10 -m venv venv

# 激活虚拟环境并升级基础包
RUN . venv/bin/activate && \
    pip install --upgrade pip setuptools wheel

# 复制必要的运行代码（精细化拷贝）
# 不再复制整个目录，只复制必要的代码文件
COPY --chown=paddlespeech:paddlespeech setup.py setup.cfg MANIFEST.in README.md README_cn.md /home/paddlespeech/PaddleSpeech/
COPY --chown=paddlespeech:paddlespeech paddlespeech/ /home/paddlespeech/PaddleSpeech/paddlespeech/
COPY --chown=paddlespeech:paddlespeech third_party/ /home/paddlespeech/PaddleSpeech/third_party/
COPY --chown=paddlespeech:paddlespeech runtime/ /home/paddlespeech/PaddleSpeech/runtime/
COPY --chown=paddlespeech:paddlespeech utils/ /home/paddlespeech/PaddleSpeech/utils/
COPY --chown=paddlespeech:paddlespeech tools/ /home/paddlespeech/PaddleSpeech/tools/
# 复制Docker相关文件（部分文件通过挂载提供）
# entrypoint.sh, static_server.py, web/目录通过挂载提供

# 切换到源码目录
WORKDIR /home/paddlespeech/PaddleSpeech

# 安装 PaddlePaddle GPU 版本
RUN . ../venv/bin/activate && \
    python -m pip install paddlepaddle-gpu==3.2.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu129/

# 从源码安装 PaddleSpeech（首先安装兼容版本aistudio-sdk）
RUN . ../venv/bin/activate && \
    pip install "aistudio-sdk==0.2.6" && \
    pip install -e .

# 编译安装 CTC 解码器
RUN . ../venv/bin/activate && \
    cd third_party/ctc_decoders && \
    bash setup.sh && \
    python -m pip install .

# 安装额外的服务依赖
RUN . ../venv/bin/activate && \
    pip install fastapi uvicorn websockets jinja2 python-multipart aiofiles

# 创建必要的基础目录（挂载点将挂载在这些目录上）
RUN mkdir -p /home/paddlespeech/.paddlespeech && \
    mkdir -p /home/paddlespeech/.cache/paddle && \
    mkdir -p /home/paddlespeech/models/pretrained && \
    mkdir -p /home/paddlespeech/PaddleSpeech/logs && \
    mkdir -p /home/paddlespeech/PaddleSpeech/models && \
    mkdir -p /home/paddlespeech/PaddleSpeech/uploads && \
    mkdir -p /home/paddlespeech/PaddleSpeech/outputs && \
    mkdir -p /home/paddlespeech/PaddleSpeech/docker/conf

# 设置 NVIDIA 库路径
ENV LD_LIBRARY_PATH=/home/paddlespeech/venv/lib/python*/site-packages/nvidia/nccl/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cublas/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cuda_runtime/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cuda_nvrtc/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cudnn/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/nvjitlink/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/curand/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cusolver/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cufft/lib:/home/paddlespeech/venv/lib/python*/site-packages/nvidia/cusparse/lib:$LD_LIBRARY_PATH

# 暴露端口（统一端口架构）
EXPOSE 8090 8091 8092 8093

# 健康检查（PaddleSpeech 原生服务）
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD curl -f http://localhost:8090/paddlespeech/asr/help || exit 1

# 启动命令
ENTRYPOINT ["/home/paddlespeech/entrypoint.sh"]
CMD ["all"]