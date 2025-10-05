# PaddleSpeech 多服务架构部署指南

## 🎯 项目概述

本项目实现了 PaddleSpeech 的多服务架构部署，包括：

1. **普通语音服务器** (8090端口) - 支持 ASR、TTS、CLS 等标准功能
2. **流式语音识别服务器** (8091端口) - 支持 WebSocket 实时语音识别
3. **流式语音合成服务器** (8092端口) - 支持流式文字转语音
4. **综合测试网页** - 提供完整的 Web 界面测试功能

## 🚀 快速启动

### 1. 构建镜像
```bash
cd /home/songm/code/PaddleSpeech/docker
./deploy.sh build
```

### 2. 启动所有服务
```bash
./deploy.sh start
```

启动完成后，脚本会自动显示详细的服务信息和使用指引。

### 3. 查看服务状态
```bash
./deploy.sh status
```

### 4. 查看服务日志
```bash
./deploy.sh logs
```

### 5. 停止服务
```bash
./deploy.sh stop
```

## 🌐 服务访问地址

| 服务类型 | 访问地址 | 协议 | 功能描述 |
|---------|---------|------|---------|
| **🌐 测试网页** | **http://localhost:8093/** | **HTTP** | **完整的 Web 测试界面** |
| 普通语音服务 | http://localhost:8090 | HTTP | ASR、TTS、CLS 标准功能 |
| 流式语音识别 | ws://localhost:8091 | WebSocket | 实时语音识别 |
| 流式语音合成 | ws://localhost:8092 | WebSocket | 流式语音合成 |

## 🧪 功能测试

### Web 界面测试
直接访问 `http://localhost:8093/` 进行：

**或者使用快捷启动脚本：**
```bash
cd /home/songm/code/PaddleSpeech/docker
./start_web.sh
```
- 实时录音转文字
- 音频文件上传转文字
- 文字转语音
- 流式语音合成
- 语种和模型切换

### 命令行测试

#### 1. 普通语音识别 (ASR)
```bash
paddlespeech_client asr --server_ip localhost --port 8090 --input test.wav
```

#### 2. 语音合成 (TTS)
```bash
paddlespeech_client tts --server_ip localhost --port 8090 --input '你好，世界'
```

#### 3. 流式语音识别测试
```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"audio": "data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEA"}' \
  http://localhost:8091/paddlespeech/asr/streaming
```

#### 4. 流式语音合成测试
```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"text": "你好，欢迎使用PaddleSpeech"}' \
  http://localhost:8092/paddlespeech/tts/streaming
```

## 📁 文件结构

```
docker/
├── deploy.sh                              # 部署脚本
├── docker-compose.yml                     # 容器编排配置
├── Dockerfile                             # 镜像构建文件
├── entrypoint.sh                          # 容器启动脚本
├── conf/                                  # 配置文件目录
│   ├── application.yaml                   # 普通服务配置
│   ├── streaming_asr_application.yaml     # 流式ASR配置
│   └── streaming_tts_application.yaml     # 流式TTS配置
├── web/                                   # 测试网页
│   ├── index.html                         # 主页面
│   ├── style.css                          # 样式文件
│   └── script.js                          # 功能脚本
└── README_DEPLOYMENT.md                   # 部署指南
```

## 🔧 配置说明

### 环境变量
- `CUDA_VISIBLE_DEVICES`: GPU 设备选择
- `SERVER_PORT`: 普通服务端口 (默认: 8090)
- `STREAMING_ASR_PORT`: 流式ASR端口 (默认: 8091)
- `STREAMING_TTS_PORT`: 流式TTS端口 (默认: 8092)

### 模型配置
所有服务均配置为 GPU 模式，使用以下模型：
- ASR: conformer_wenetspeech
- TTS: fastspeech2_csmsc
- 流式ASR: conformer_online_wenetspeech
- 流式TTS: mb_melgan_csmsc

## 🐛 故障排除

### 1. 服务启动失败
```bash
# 查看详细日志
./deploy.sh logs

# 查看容器状态
docker ps -a

# 进入容器调试
docker exec -it paddlespeech-server bash
```

### 2. GPU 相关问题
```bash
# 检查 GPU 可用性
nvidia-smi

# 检查 Docker GPU 支持
docker run --rm --gpus all nvidia/cuda:12.1-base-ubuntu20.04 nvidia-smi
```

### 3. 端口冲突
检查端口占用：
```bash
netstat -tulpn | grep -E ':(8090|8091|8092)'
```

## 📈 性能优化

1. **GPU 内存优化**: 配置适当的 CUDA_VISIBLE_DEVICES
2. **并发优化**: 调整 MAX_WORKERS 参数
3. **模型缓存**: 所有模型持久化存储，避免重复下载
4. **健康检查**: 自动监控服务状态

## 🎉 完成！

恭喜！您已成功部署 PaddleSpeech 多服务架构。现在可以通过 Web 界面或 API 进行语音识别和合成了。

如有问题，请查看日志文件或联系技术支持。