# PaddleSpeech Docker 优化部署指南

## 概述

本指南介绍了 PaddleSpeech Docker 优化部署方案，包含模型持久化存储和一键初始化功能。

## 主要特性

### 🚀 模型持久化
- **外部挂载目录**: 模型文件存储在宿主机，重启容器无需重新下载
- **缓存优化**: 智能缓存机制，大幅减少启动时间
- **存储分离**: 模型、缓存、日志分别管理

### 🔧 一键初始化
- **全面测试**: 自动执行命令行、Server 和 Streaming Server 测试
- **模型预加载**: 首次运行自动下载并验证所有必要模型
- **详细报告**: 生成完整的初始化测试报告

### 📊 部署选项
- **标准镜像**: Ubuntu 20.04 + CUDA 12.1 (生产推荐)
- **自建镜像**: Ubuntu 22.04 + CUDA 12.9 (最新环境)

## 快速开始

### 1. 环境准备

```bash
# 确保 Docker 和 Docker Compose 已安装
docker --version
docker-compose --version

# 检查 GPU 支持 (可选)
nvidia-smi
```

### 2. 目录结构

```
PaddleSpeech/
├── docker/
│   ├── deploy_optimized.sh      # 优化部署脚本
│   ├── init_paddlespeech.sh     # 一键初始化脚本
│   ├── docker-compose.yml       # 标准镜像配置
│   ├── docker-compose.custom.yml # 自建镜像配置
│   ├── .env                     # 环境变量配置
│   ├── Dockerfile               # 标准镜像构建文件
│   ├── Dockerfile.custom        # 自建镜像构建文件
│   ├── models/                  # 模型存储目录 (持久化)
│   ├── cache/                   # 缓存目录 (持久化)
│   ├── logs/                    # 日志目录
│   ├── conf/                    # 配置文件目录
│   ├── uploads/                 # 上传文件目录
│   └── outputs/                 # 输出文件目录
```

### 3. 部署命令

#### 标准镜像部署 (推荐)
```bash
cd docker
./deploy_optimized.sh standard deploy
```

#### 自建镜像部署
```bash
cd docker  
./deploy_optimized.sh custom deploy
```

#### 仅运行初始化测试
```bash
./deploy_optimized.sh standard init
```

### 4. 验证部署

```bash
# 检查服务状态
./deploy_optimized.sh standard status

# 查看日志
./deploy_optimized.sh standard logs

# 查看初始化报告
cat logs/paddlespeech_init_report.txt
```

## 端口配置

### 标准部署端口
- **主服务**: http://localhost:8080
- **ASR 服务**: http://localhost:8081  
- **TTS 服务**: http://localhost:8082
- **Web 界面**: http://localhost:8083

### 自建镜像端口
- **主服务**: http://localhost:8090
- **ASR 服务**: http://localhost:8091
- **TTS 服务**: http://localhost:8092  
- **Web 界面**: http://localhost:8093

## 详细使用

### 部署脚本参数

```bash
./deploy_optimized.sh [部署类型] [操作]

# 部署类型:
#   standard - 标准镜像 (Ubuntu 20.04 + CUDA 12.1)
#   custom   - 自建镜像 (Ubuntu 22.04 + CUDA 12.9)

# 操作:
#   deploy  - 部署并启动服务
#   init    - 运行初始化测试  
#   stop    - 停止服务
#   clean   - 清理环境
#   status  - 查看服务状态
#   logs    - 查看服务日志
#   help    - 显示帮助信息
```

### 环境变量配置

编辑 `docker/.env` 文件来自定义配置:

```bash
# GPU 配置
CUDA_VISIBLE_DEVICES=0
DEVICE_COUNT=1

# 资源限制
MEMORY_LIMIT=8G
CPU_LIMIT=4

# 端口配置 (自建镜像)
HTTP_PORT=8090
ASR_PORT=8091
TTS_PORT=8092
WEB_PORT=8093

# 模型配置
ASR_MODEL=conformer_wenetspeech
TTS_MODEL=fastspeech2_csmsc
```

## 初始化测试

一键初始化脚本会自动执行以下测试:

### 🎯 测试项目
1. **环境检查**: Python、PaddleSpeech、CUDA 环境
2. **命令行测试**: ASR 和 TTS CPU/GPU 模式
3. **Server 测试**: ASR 和 TTS HTTP 服务器
4. **Streaming 测试**: WebSocket 流式 ASR 服务

### 📋 测试报告
- **位置**: `logs/paddlespeech_init_report.txt`
- **内容**: 详细的测试结果和建议
- **统计**: 通过率和失败项目分析

### ⚡ 首次运行优化
- 初始化过程会下载和验证所有必要模型
- 后续启动速度显著提升
- 模型文件持久化存储，重启容器无需重新下载

## 故障排除

### 常见问题

1. **容器启动失败**
   ```bash
   # 检查日志
   ./deploy_optimized.sh standard logs
   
   # 重新构建
   docker-compose build --no-cache
   ```

2. **模型下载失败**
   ```bash
   # 检查网络连接
   curl -I https://paddlespeech.cdn.bcebos.com/
   
   # 手动重新初始化
   ./deploy_optimized.sh standard init
   ```

3. **GPU 不可用**
   ```bash
   # 检查 NVIDIA Docker
   docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
   
   # 检查环境变量
   echo $CUDA_VISIBLE_DEVICES
   ```

4. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tulpn | grep :8080
   
   # 修改 .env 文件中的端口配置
   ```

### 清理和重置

```bash
# 停止服务
./deploy_optimized.sh standard stop

# 完全清理 (慎用)
./deploy_optimized.sh standard clean

# 手动清理
docker system prune -f
docker volume prune -f
```

## 性能优化建议

### 🔧 硬件配置
- **GPU**: 推荐 RTX 3080 及以上，至少 8GB 显存
- **内存**: 建议 16GB 及以上
- **存储**: SSD 硬盘，至少 50GB 可用空间

### ⚙️ 软件配置
- **共享内存**: 默认 4GB，可根据需要调整
- **工作进程**: 默认 2 个，可根据 CPU 核心数调整
- **模型缓存**: 开启模型缓存以减少重复加载

### 📈 监控建议
- 使用 `docker stats` 监控资源使用
- 定期检查 `logs/` 目录下的日志文件
- 监控模型目录的磁盘使用情况

## 更新和维护

### 版本更新
```bash
# 停止当前服务
./deploy_optimized.sh standard stop

# 拉取最新代码
git pull

# 重新构建和部署
./deploy_optimized.sh standard deploy
```

### 定期维护
```bash
# 清理 Docker 缓存
docker system prune -f

# 备份模型目录
tar -czf models_backup_$(date +%Y%m%d).tar.gz docker/models/

# 检查磁盘使用
du -sh docker/models/ docker/cache/ docker/logs/
```

## 支持和反馈

如遇到问题或有建议，请：
1. 检查 `logs/paddlespeech_init_report.txt` 测试报告
2. 查看相关日志文件
3. 提供详细的错误信息和环境配置

---

**注意**: 首次部署时模型下载可能需要较长时间，请确保网络连接稳定。后续启动将显著加快。