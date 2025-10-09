#!/bin/bash
# PaddleSpeech 容器启动脚本
# Author: Songm
# Version: 1.0.0

# set -e  # 移除严格错误处理，避免服务启动失败导致容器退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_blue() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 应用CORS修补
apply_cors_patch() {
    log_info "应用 CORS 修补..."
    
    # 检查修补脚本是否存在
    if [ -f "/home/paddlespeech/patch_cors.py" ]; then
        cd /home/paddlespeech/PaddleSpeech
        source ../venv/bin/activate
        
        if python /home/paddlespeech/patch_cors.py; then
            log_info "CORS 修补应用成功"
        else
            log_warn "CORS 修补应用失败，但继续启动服务"
        fi
    else
        log_warn "CORS 修补脚本不存在，跳过修补"
    fi
}

# 检查 GPU 可用性
check_gpu() {
    log_info "检查 GPU 可用性..."
    
    # 检查NVIDIA环境变量是否设置
    if [ -n "$NVIDIA_VISIBLE_DEVICES" ] || [ -n "$CUDA_VISIBLE_DEVICES" ]; then
        # 检查nvidia-smi是否可用
        if command -v nvidia-smi &> /dev/null; then
            if nvidia-smi &> /dev/null; then
                local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits | head -1)
                log_info "检测到 ${gpu_count} 个 GPU 设备"
                nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits
                export PADDLESPEECH_DEVICE=gpu
                export CUDA_VISIBLE_DEVICES=0
            else
                log_warn "NVIDIA 驱动未正确安装或 GPU 不可用"
                export PADDLESPEECH_DEVICE=cpu
            fi
        else
            log_warn "nvidia-smi 命令不可用，使用 CPU 模式"
            export PADDLESPEECH_DEVICE=cpu
        fi
    else
        log_warn "NVIDIA 环境变量未设置，使用 CPU 模式"
        export PADDLESPEECH_DEVICE=cpu
    fi
}

# 设置环境变量
setup_environment() {
    log_info "设置环境变量..."
    
    # 基础路径
    export PYTHONPATH="/home/paddlespeech/PaddleSpeech:$PYTHONPATH"
    export HOME="/home/paddlespeech"

    # 设置NLTK数据目录为挂载目录（持久化存储）
    export NLTK_DATA="/home/paddlespeech/models/nltk_data"

    # 设置PaddleNLP缓存目录为持久化存储
    export PADDLE_HOME="/home/paddlespeech/.cache/paddlenlp"
    
    # CUDA 路径
    export CUDA_HOME=${CUDA_HOME:-/usr/local/cuda}
    export PATH="$CUDA_HOME/bin:$PATH"
    
    # 设置 NVIDIA 库路径（从经验记忆中获取）
    local nvidia_lib_base="/home/paddlespeech/venv/lib/python3.10/site-packages/nvidia"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${nvidia_lib_base}/nccl/lib:${nvidia_lib_base}/cublas/lib:${nvidia_lib_base}/cuda_runtime/lib:${nvidia_lib_base}/cuda_nvrtc/lib:${nvidia_lib_base}/cudnn/lib:${nvidia_lib_base}/nvjitlink/lib:${nvidia_lib_base}/curand/lib:${nvidia_lib_base}/cusolver/lib:${nvidia_lib_base}/cufft/lib:${nvidia_lib_base}/cusparse/lib:$LD_LIBRARY_PATH"
    
    # PaddleSpeech 配置
    export PADDLESPEECH_GPU=${PADDLESPEECH_GPU:-true}
    export PADDLESPEECH_DEVICE=${PADDLESPEECH_DEVICE:-gpu}
    
    # 服务配置（统一端口架构）
    export SERVER_HOST=${SERVER_HOST:-0.0.0.0}
    export SERVER_PORT=${SERVER_PORT:-8090}  # PaddleSpeech 统一服务端口
    export MAX_WORKERS=${MAX_WORKERS:-4}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    
    log_info "环境配置完成:"
    log_blue "  设备: $PADDLESPEECH_DEVICE"
    log_blue "  统一服务端口: $SERVER_PORT"
}

# 检查依赖
check_dependencies() {
    log_info "检查 Python 依赖..."
    
    cd /home/paddlespeech/PaddleSpeech
    source ../venv/bin/activate
    
    # 检查关键依赖
    local deps=("paddlepaddle-gpu" "paddlespeech" "fastapi" "uvicorn")
    
    for dep in "${deps[@]}"; do
        if pip show "$dep" &> /dev/null; then
            local version=$(pip show "$dep" | grep Version | cut -d' ' -f2)
            log_info "✓ $dep: $version"
        else
            log_error "✗ $dep: 未安装"
            return 1
        fi
    done
    
    # 检查 aistudio-sdk （不强制版本）
    if pip show aistudio-sdk &> /dev/null; then
        local aistudio_version=$(pip show aistudio-sdk | grep Version | cut -d' ' -f2)
        log_info "✓ aistudio-sdk: $aistudio_version"
    else
        log_warn "aistudio-sdk 未安装，可能影响部分功能"
    fi
    
    return 0
}

# 预下载模型
preload_models() {
    log_info "预加载模型..."
    
    cd /home/paddlespeech/PaddleSpeech
    source ../venv/bin/activate
    
    # 创建模型预加载脚本
    cat > /tmp/preload_models.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
sys.path.insert(0, '/home/paddlespeech/PaddleSpeech')

try:
    print("初始化 ASR 模型...")
    from paddlespeech.cli.asr.infer import ASRExecutor
    asr = ASRExecutor()
    print("✓ ASR 模型加载成功")
    
    print("初始化 TTS 模型...")
    from paddlespeech.cli.tts.infer import TTSExecutor
    tts = TTSExecutor()
    print("✓ TTS 模型加载成功")
    
    print("模型预加载完成")

except Exception as e:
    print(f"模型预加载失败: {e}")
    # 不退出，继续启动服务
    pass
EOF
    
    if python /tmp/preload_models.py; then
        log_info "模型预加载成功"
    else
        log_warn "模型预加载失败，将在首次使用时下载"
    fi
    
    rm -f /tmp/preload_models.py
}

# 确保日志目录和文件权限正确
ensure_log_permissions() {
    log_info "确保日志目录权限正确..."
    
    # 创建日志目录
    mkdir -p logs
    
    # 确保日志目录对当前用户可写
    chmod 755 logs 2>/dev/null || true
    
    # 如果日志文件存在，确保它们可写
    for file in logs/*.out logs/*.log logs/*.pid; do
        if [ -f "$file" ]; then
            chmod 644 "$file" 2>/dev/null || true
        fi
    done
}

# 启动服务（多服务模式）
start_services() {
    local mode=${1:-all}
    
    log_info "启动 PaddleSpeech 多服务..."
    
    cd /home/paddlespeech/PaddleSpeech
    source ../venv/bin/activate
    
    # 确保日志权限正确
    ensure_log_permissions
    
    # 启动静态文件服务器 (8093)
    log_info "启动静态文件服务器 - 端口 8093..."
    nohup python ./docker/static_server.py 8093 > ./logs/static.out 2>&1 &
    STATIC_PID=$!
    if [ $? -eq 0 ]; then
        # 使用更安全的方式写入PID文件
        echo $STATIC_PID > ./logs/static.pid 2>/dev/null || {
            log_warn "无法写入 static.pid 文件"
        }
        log_info "静态文件服务器已启动 (PID: $STATIC_PID)"
    else
        log_warn "静态文件服务器启动失败，但继续启动其他服务"
    fi
    
    # 等待静态服务器启动
    sleep 3
    
    # 启动普通服务 (8090)
    log_info "启动普通服务 (ASR+TTS+CLS) - 端口 8090..."
    nohup paddlespeech_server start \
        --config_file ./docker/conf/application.yaml \
        --log_file ./logs/server.log > ./logs/server.out 2>&1 &
    SERVER_PID=$!
    if [ $? -eq 0 ]; then
        # 使用更安全的方式写入PID文件
        echo $SERVER_PID > ./logs/server.pid 2>/dev/null || {
            log_warn "无法写入 server.pid 文件"
        }
        log_info "普通服务已启动 (PID: $SERVER_PID)"
    else
        log_warn "普通服务启动失败，但继续启动其他服务"
    fi
    
    # 等待普通服务启动
    sleep 10
    
    # 启动流式ASR服务 (8091)
    log_info "启动流式 ASR 服务 (WebSocket) - 端口 8091..."
    nohup paddlespeech_server start \
        --config_file ./docker/conf/streaming_asr_application.yaml \
        --log_file ./logs/streaming_asr.log > ./logs/streaming_asr.out 2>&1 &
    STREAMING_ASR_PID=$!
    if [ $? -eq 0 ]; then
        # 使用更安全的方式写入PID文件
        echo $STREAMING_ASR_PID > ./logs/streaming_asr.pid 2>/dev/null || {
            log_warn "无法写入 streaming_asr.pid 文件"
        }
        log_info "流式ASR服务已启动 (PID: $STREAMING_ASR_PID)"
    else
        log_warn "流式ASR服务启动失败，但继续启动其他服务"
    fi
    
    # 等待流式ASR服务启动
    sleep 10
    
    # 启动流式TTS服务 (8092) - 重新启用进行测试
    log_info "启动流式 TTS 服务 (HTTP) - 端口 8092..."
    nohup paddlespeech_server start \
        --config_file ./docker/conf/streaming_tts_application.yaml \
        --log_file ./logs/streaming_tts.log > ./logs/streaming_tts.out 2>&1 &
    STREAMING_TTS_PID=$!
    if [ $? -eq 0 ]; then
        # 使用更安全的方式写入PID文件
        echo $STREAMING_TTS_PID > ./logs/streaming_tts.pid 2>/dev/null || {
            log_warn "无法写入 streaming_tts.pid 文件"
        }
        log_info "流式TTS服务已启动 (PID: $STREAMING_TTS_PID)"
    else
        log_warn "流式TTS服务启动失败，但继续启动其他服务"
    fi
    
    # 等待所有服务启动
    log_info "等待所有服务启动完成..."
    sleep 30
    
    # 显示服务信息
    show_service_info
    
    # 保持容器运行 - 等待信号而不是后台进程
    log_info "所有服务已启动，容器保持运行状态..."
    
    # 持续监控服务状态
    while true; do
        sleep 60
        log_info "服务监控中... (每60秒检查一次)"
        show_service_status_brief
    done
}

# 显示服务信息
show_service_info() {
    echo ""
    log_blue "============================="
    log_blue "   服务启动完成   "
    log_blue "============================="
    echo ""
    
    # 检查服务状态
    check_service_status "8090" "普通服务 (ASR+TTS+CLS)"
    check_service_status "8091" "流式 ASR 服务 (WebSocket)"
    check_service_status "8092" "流式 TTS 服务 (HTTP)"
    
    echo ""
    log_green "服务访问地址:"
    echo "  普通服务:     http://localhost:8090"
    echo "  流式 ASR:      ws://localhost:8091"
    echo "  流式 TTS:      http://localhost:8092"
    echo "  测试网页:     http://localhost:8093"
    echo ""
    
    log_green "测试命令:"
    echo "  # 普通 ASR"
    echo "  paddlespeech_client asr --server_ip localhost --port 8090 --input test.wav"
    echo ""
    echo "  # 流式 ASR"
    echo "  paddlespeech_client asr_online --server_ip localhost --port 8091 --input test.wav"
    echo ""
    echo "  # 普通 TTS"
    echo "  paddlespeech_client tts --server_ip localhost --port 8090 --input '你好' --output output.wav"
    echo ""
    echo "  # 流式 TTS"
    echo "  paddlespeech_client tts_online --server_ip localhost --port 8092 --input '你好' --output output.wav"
    echo ""
    
    log_blue "============================="
}

# 简化的服务状态显示
show_service_status_brief() {
    check_service_status "8090" "普通服务" "brief"
    check_service_status "8091" "流式ASR" "brief"
    check_service_status "8092" "流式TTS" "brief"
}

# 检查服务状态
check_service_status() {
    local port=$1
    local service_name=$2
    local mode=${3:-full}  # full 或 brief
    local max_attempts=3  # 减少检查次数避免阻塞
    local attempt=1
    
    if [ "$mode" = "brief" ]; then
        max_attempts=1  # 简化模式只检查一次
    fi
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s --max-time 2 http://localhost:$port > /dev/null 2>&1; then
            if [ "$mode" != "brief" ]; then
                log_green "✓ $service_name (端口 $port) - 运行正常"
            fi
            return 0
        fi
        if [ "$mode" != "brief" ]; then
            sleep 3
        fi
        attempt=$((attempt + 1))
    done
    
    if [ "$mode" != "brief" ]; then
        log_red "✗ $service_name (端口 $port) - 启动失败或未就绪"
    fi
    return 0  # 不让服务检查失败导致容器退出
}

# 信号处理
cleanup() {
    log_info "正在关闭所有服务..."
    
    # 关闭所有后台进程
    if [ -f "./logs/server.pid" ]; then
        kill -TERM $(cat ./logs/server.pid) 2>/dev/null || true
    fi
    if [ -f "./logs/streaming_asr.pid" ]; then
        kill -TERM $(cat ./logs/streaming_asr.pid) 2>/dev/null || true
    fi
    if [ -f "./logs/streaming_tts.pid" ]; then
        kill -TERM $(cat ./logs/streaming_tts.pid) 2>/dev/null || true
    fi
    
    # 等待进程关闭
    sleep 2
    
    # 强制关闭
    pkill -f "paddlespeech_server" 2>/dev/null || true
    
    log_info "所有服务已关闭"
    exit 0
}

# 颜色输出函数
log_red() {
    echo -e "\033[31m$1\033[0m"
}

log_green() {
    echo -e "\033[32m$1\033[0m"
}

# 注册信号处理器
trap cleanup SIGTERM SIGINT

# 显示启动横幅
show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ____            __    ____     _____                    __  
   / __ \____ _____/ /___/ / /__  / ___/____  ___  ___  ___/ /_ 
  / /_/ / __ `/ __  / __  / / _ \ \__ \/ __ \/ _ \/ _ \/ __  __ \
 / ____/ /_/ / /_/ / /_/ / /  __/___/ / /_/ /  __/  __/ /_/ / / /
/_/    \__,_/\__,_/\__,_/_/\___//____/ .___/\___/\___/\__,_/_/_/ 
                                   /_/                          
                    流式语音服务 - Docker 版本
EOF
    echo -e "${NC}"
    echo -e "${GREEN}版本: 1.0.0${NC}"
    echo -e "${GREEN}构建时间: $(date)${NC}"
    echo ""
}

# 主函数
main() {
    show_banner
    
    log_info "PaddleSpeech 流式服务启动中..."
    
    # 检查并设置环境
    check_gpu
    setup_environment
    
    # 应用CORS修补
    apply_cors_patch
    
    # 检查依赖
    if ! check_dependencies; then
        log_error "依赖检查失败"
        exit 1
    fi
    
    # 预加载模型（可选）
    if [[ "${PRELOAD_MODELS:-true}" == "true" ]]; then
        preload_models
    fi
    
    # 启动服务 - 使用 PaddleSpeech 原生服务器
    start_services
}

# 执行主函数
main "$@"
main "$@"