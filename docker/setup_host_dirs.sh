#!/bin/bash

# PaddleSpeech Docker 主机目录初始化脚本
# 创建必要的主机目录，确保挂载正常工作

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info "初始化 PaddleSpeech Docker 主机目录..."
log_info "项目根目录: $PROJECT_ROOT"

# 创建主机目录
create_directories() {
    local dirs=(
        "logs"              # 日志目录
        "models"            # 外部模型目录
        "uploads"           # 上传文件目录
        "outputs"           # 输出文件目录
    )
    
    for dir in "${dirs[@]}"; do
        local full_path="$PROJECT_ROOT/$dir"
        if [ ! -d "$full_path" ]; then
            mkdir -p "$full_path"
            log_info "创建目录: $full_path"
        else
            log_info "目录已存在: $full_path"
        fi
    done
}

# 检查配置文件
check_config_files() {
    local config_dir="$PROJECT_ROOT/docker/conf"
    
    if [ ! -d "$config_dir" ]; then
        log_error "配置目录不存在: $config_dir"
        return 1
    fi
    
    local required_configs=(
        "application.yaml"
        "streaming_asr_application.yaml"
        "streaming_tts_application.yaml"
    )
    
    for config in "${required_configs[@]}"; do
        local config_path="$config_dir/$config"
        if [ ! -f "$config_path" ]; then
            log_warning "配置文件不存在: $config_path"
        else
            log_info "配置文件存在: $config"
        fi
    done
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."
    
    # 确保当前用户对这些目录有读写权限
    local dirs=("logs" "models" "uploads" "outputs")
    
    for dir in "${dirs[@]}"; do
        local full_path="$PROJECT_ROOT/$dir"
        if [ -d "$full_path" ]; then
            chmod 755 "$full_path"
            log_info "设置权限 755: $full_path"
        fi
    done
}

# 显示目录结构
show_directory_structure() {
    log_info "目录结构:"
    echo "项目根目录: $PROJECT_ROOT"
    echo "├── docker/"
    echo "│   ├── conf/                    # 服务配置文件 (挂载到容器)"
    echo "│   ├── web/                     # 测试网页文件"
    echo "│   └── *.sh, *.py              # 部署和服务脚本"
    echo "├── logs/                        # 日志目录 (与容器同步)"
    echo "├── models/                      # 外部模型目录 (与容器同步)"
    echo "├── uploads/                     # 上传文件目录 (与容器同步)"
    echo "├── outputs/                     # 输出文件目录 (与容器同步)"
    echo "└── paddlespeech/                # 源代码 (复制到镜像)"
}

# 主函数
main() {
    echo "=========================================="
    echo "PaddleSpeech Docker 主机目录初始化"
    echo "=========================================="
    
    create_directories
    check_config_files
    set_permissions
    show_directory_structure
    
    log_success "主机目录初始化完成!"
    echo ""
    log_info "下一步操作:"
    echo "  1. 构建镜像: ./docker/deploy.sh build"
    echo "  2. 启动服务: ./docker/deploy.sh start"
    echo ""
}

# 执行主函数
main "$@"