#!/bin/bash

# NVIDIA GPU 检测脚本
# 用于诊断容器内的GPU可用性问题

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

# 检查NVIDIA驱动和工具
check_nvidia_tools() {
    log_info "检查NVIDIA工具..."
    
    # 检查nvidia-smi
    if command -v nvidia-smi &> /dev/null; then
        log_success "nvidia-smi: 可用"
        nvidia-smi --version
    else
        log_warning "nvidia-smi: 未找到"
    fi
    
    # 检查nvidia-ml-py
    if python -c "import pynvml; print('pynvml: 可用')" 2>/dev/null; then
        log_success "pynvml: 可用"
    else
        log_warning "pynvml: 未找到"
    fi
    
    # 检查CUDA库
    if ldconfig -p | grep -q cuda; then
        log_success "CUDA库: 可用"
        ldconfig -p | grep cuda | head -5
    else
        log_warning "CUDA库: 未找到"
    fi
}

# 检查NVIDIA环境变量
check_nvidia_env() {
    log_info "检查NVIDIA环境变量..."
    
    local env_vars=(
        "NVIDIA_VISIBLE_DEVICES"
        "NVIDIA_DRIVER_CAPABILITIES"
        "CUDA_VISIBLE_DEVICES"
        "CUDA_HOME"
    )
    
    for var in "${env_vars[@]}"; do
        if [ -n "${!var}" ]; then
            log_success "$var: ${!var}"
        else
            log_warning "$var: 未设置"
        fi
    done
}

# 检查GPU状态
check_gpu_status() {
    log_info "检查GPU状态..."
    
    if nvidia-smi -L &> /dev/null; then
        local gpu_count=$(nvidia-smi -L | wc -l)
        log_success "检测到 $gpu_count 个GPU设备"
        nvidia-smi -L
        
        # 显示详细信息
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits
    else
        log_error "无法列出GPU设备"
        
        # 尝试其他方式
        if nvidia-smi --query-gpu=count --format=csv,noheader,nounits &> /dev/null; then
            local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits | head -1)
            log_success "检测到 $gpu_count 个GPU设备 (通过查询方式)"
        else
            log_error "GPU不可用"
        fi
    fi
}

# 检查PaddlePaddle CUDA支持
check_paddle_cuda() {
    log_info "检查PaddlePaddle CUDA支持..."
    
    if python -c "import paddle; print('PaddlePaddle版本:', paddle.__version__); print('CUDA支持:', paddle.is_compiled_with_cuda())" 2>/dev/null; then
        log_success "PaddlePaddle CUDA检查完成"
    else
        log_error "PaddlePaddle CUDA检查失败"
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "NVIDIA GPU 检测工具"
    echo "=========================================="
    
    check_nvidia_tools
    echo ""
    check_nvidia_env
    echo ""
    check_gpu_status
    echo ""
    check_paddle_cuda
    
    echo ""
    log_info "检测完成"
}

# 执行主函数
main "$@"