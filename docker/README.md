# PaddleSpeech Docker 部署

基于 Ubuntu 22.04 + CUDA 12.9 的 PaddleSpeech 语音识别与合成服务，采用统一端口架构。

## 🚀 快速开始

### 1. 进入 Docker 目录
```bash
cd docker
```

### 2. 构建镜像
```bash
./deploy.sh build
```

### 3. 启动服务
```bash
./deploy.sh start
```

### 4. 测试服务
```bash
./test.sh
```

## 📋 服务信息

- **服务地址**: http://localhost:8090
- **API 文档**: http://localhost:8090/docs
- **健康检查**: http://localhost:8090/paddlespeech/asr/help

## 🎯 主要功能

- **语音识别 (ASR)**: 支持中文语音转文字
- **语音合成 (TTS)**: 支持中文文字转语音  
- **分类服务 (CLS)**: 音频分类功能
- **GPU 加速**: 支持 NVIDIA GPU 加速
- **统一端口**: 所有服务在 8090 端口提供

## 🔧 管理命令

```bash
# 构建镜像
./deploy.sh build

# 启动服务
./deploy.sh start

# 停止服务
./deploy.sh stop

# 重启服务
./deploy.sh restart

# 查看状态
./deploy.sh status

# 查看日志
./deploy.sh logs

# 测试服务
./test.sh

# 清理环境
./deploy.sh clean
```

## ⚙️ 配置说明

### 环境变量 (.env)
- `SERVER_PORT`: 服务端口 (默认: 8090)
- `REDIS_PORT`: Redis 端口 (默认: 6379)  
- `CUDA_VISIBLE_DEVICES`: GPU 设备 (默认: 0)
- `MEMORY_LIMIT`: 内存限制 (默认: 8G)

### 服务配置 (conf/application.yaml)
- 模型配置
- 引擎设置
- 设备选择

## 🐳 Docker 架构

```
├── Dockerfile              # 镜像构建文件
├── docker-compose.yml      # 服务编排文件
├── entrypoint.sh           # 容器启动脚本
├── deploy.sh               # 部署管理脚本
├── test.sh                 # 测试脚本
├── init_paddlespeech.sh    # 初始化脚本
├── .env                    # 环境配置
└── conf/
    └── application.yaml    # PaddleSpeech 配置
```

## 📊 系统要求

- **操作系统**: Ubuntu 22.04+
- **Docker**: 20.10+
- **GPU**: NVIDIA GPU (可选)
- **CUDA**: 12.9 (GPU 模式)
- **内存**: 8GB+
- **存储**: 50GB+

## 🔍 故障排除

### 服务无法启动
```bash
# 查看日志
./deploy.sh logs

# 检查容器状态
docker ps -a

# 重启服务
./deploy.sh restart
```

### GPU 不可用
```bash
# 检查 GPU
nvidia-smi

# 检查 Docker GPU 支持
docker run --rm --gpus all nvidia/cuda:12.1-base-ubuntu20.04 nvidia-smi
```

### 端口冲突
```bash
# 检查端口占用
netstat -tulpn | grep 8090

# 修改端口配置
vim .env
```

## 📚 API 使用

### 语音识别
```bash
curl -X POST "http://localhost:8090/paddlespeech/asr" \
  -F "audio=@test.wav"
```

### 语音合成
```bash
curl -X POST "http://localhost:8090/paddlespeech/tts" \
  -H "Content-Type: application/json" \
  -d '{"text": "你好，这是语音合成测试"}'
```

更多 API 文档请访问: http://localhost:8090/docs