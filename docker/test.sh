#!/bin/bash

# PaddleSpeech 服务测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_PORT=8090

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 主测试函数
main() {
    log_info "开始 PaddleSpeech 服务测试..."
    
    # 检查容器状态
    log_info "检查容器状态..."
    if docker ps | grep -q "paddlespeech-server"; then
        log_success "容器运行正常"
    else
        log_error "容器未运行"
        exit 1
    fi
    
    # 检查服务响应
    log_info "检查服务响应..."
    if curl -s --max-time 10 "http://localhost:${SERVER_PORT}" >/dev/null; then
        log_success "服务响应正常"
    else
        log_error "服务无响应"
        exit 1
    fi
    
    # 测试 API 端点
    log_info "测试 API 端点..."
    
    # 检查 ASR help
    if curl -s --max-time 10 "http://localhost:${SERVER_PORT}/paddlespeech/asr/help" >/dev/null; then
        log_success "ASR API 可访问"
    else
        log_error "ASR API 不可访问"
    fi
    
    # 检查 TTS help  
    if curl -s --max-time 10 "http://localhost:${SERVER_PORT}/paddlespeech/tts/help" >/dev/null; then
        log_success "TTS API 可访问"
    else
        log_error "TTS API 不可访问"
    fi
    
    # 运行容器内测试
    log_info "运行容器内初始化测试..."
    if docker exec paddlespeech-server /home/paddlespeech/PaddleSpeech/init_paddlespeech.sh; then
        log_success "容器内测试通过"
    else
        log_error "容器内测试失败"
    fi
    
    log_success "所有测试完成！"
    log_info "服务地址: http://localhost:${SERVER_PORT}"
    log_info "API 文档: http://localhost:${SERVER_PORT}/docs"
}

# 执行主函数
main "$@"