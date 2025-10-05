#!/bin/bash
# PaddleSpeech 自建镜像数据目录初始化脚本
# Author: Songm
# Version: 1.0.0

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_blue() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 创建主数据目录
DATA_DIR="./data"

log_info "初始化 PaddleSpeech 自建镜像数据目录..."

# 创建所有必要的目录
mkdir -p "$DATA_DIR"/{models,cache,pretrained,logs,uploads,outputs}

# 设置权限
chmod 755 "$DATA_DIR"
chmod 755 "$DATA_DIR"/{models,cache,pretrained,logs,uploads,outputs}

log_blue "数据目录结构："
log_blue "├── data/"
log_blue "│   ├── models/      # PaddleSpeech 模型缓存"
log_blue "│   ├── cache/       # Paddle 框架缓存"  
log_blue "│   ├── pretrained/  # 预训练模型存储"
log_blue "│   ├── logs/        # 服务日志文件"
log_blue "│   ├── uploads/     # 上传文件存储"
log_blue "│   └── outputs/     # 输出文件存储"

log_info "✅ 数据目录初始化完成！"
log_info "提示：这些目录将持久化存储模型和数据，重启容器后无需重新下载模型。"