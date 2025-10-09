#!/bin/bash

# PaddleSpeech Docker 部署脚本
# 统一端口架构 - 使用原生 PaddleSpeech 服务

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

# 脚本参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATION=${1:-"help"}

# 显示帮助信息
show_help() {
    cat << EOF
PaddleSpeech Docker 部署脚本 - 多服务架构
用法: $0 [操作]

操作:
  build       构建镜像
  start       启动多服务架构
  stop        停止所有服务
  restart     重启所有服务
  status      查看服务状态
  logs        查看服务日志
  clean       清理环境
  help        显示帮助信息

示例:
  $0 build      # 构建镜像
  $0 start      # 启动所有服务
  $0 status     # 查看服务状态

服务架构:
  普通语音服务:        http://localhost:8090
  流式语音识别服务:  ws://localhost:8091
  流式语音合成服务:  ws://localhost:8092
  测试网页:          http://localhost:8090

配置文件: docker/.env
EOF
}

# 检查环境
check_environment() {
    log_info "检查系统环境..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker 未安装"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        log_info "检测到 NVIDIA GPU，将启用 GPU 支持"
    else
        log_warning "未检测到 NVIDIA GPU，将使用 CPU 模式"
    fi
    
    log_success "系统环境检查完成"
}

# 构建镜像
build_image() {
    log_info "构建 PaddleSpeech 镜像..."
    
    # 首先初始化主机目录
    log_info "初始化主机目录..."
    "$SCRIPT_DIR/setup_host_dirs.sh"
    
    cd "$SCRIPT_DIR"
    docker-compose -p paddlespeech build
    
    log_success "镜像构建完成"
}

# 显示详细服务信息
show_detailed_service_info() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🎉 PaddleSpeech 多服务架构启动完成！${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${BLUE}📋 服务概览：${NC}"
    echo "┌─────────────────────────────────────────────────────────────────────────────┐"
    echo -e "│ ${YELLOW}普通语音服务${NC}       │ http://localhost:8090 (API 服务)                       │"
    echo -e "│ ${YELLOW}流式语音识别服务${NC}   │ ws://localhost:8091 (WebSocket)                        │"
    echo -e "│ ${YELLOW}流式语音合成服务${NC}   │ ws://localhost:8092 (WebSocket)                        │"
    echo -e "│ ${YELLOW}测试/演示网页${NC}      │ http://localhost:8093                                  │"
    echo "└─────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "${BLUE}🔧 服务管理命令：${NC}"
    echo -e "  查看状态: ${GREEN}./deploy.sh status${NC}"
    echo -e "  查看日志: ${GREEN}./deploy.sh logs${NC}"
    echo -e "  停止服务: ${GREEN}./deploy.sh stop${NC}"
    echo -e "  重启服务: ${GREEN}./deploy.sh restart${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}✨ 祝您使用愉快！如有问题请查看日志或联系技术支持。${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
}

# 启动服务
start_service() {
    log_info "启动 PaddleSpeech 多服务架构..."
    
    cd "$SCRIPT_DIR"
    docker-compose -p paddlespeech up -d
    
    # 等待服务启动
    log_info "所有服务启动中，等待60秒检查服务状态..."
    
    # 显示docker compose logs -f的输出，30秒后自动结束
    timeout 60s docker-compose -p paddlespeech logs -f 2>&1 || true
    
    check_service_status
    show_detailed_service_info
}

# 停止服务
stop_service() {
    log_info "停止服务..."
    
    cd "$SCRIPT_DIR"
    docker-compose -p paddlespeech down
    
    log_success "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启服务..."
    stop_service
    start_service
}

# 检查服务状态
check_service_status() {
    log_info "检查多服务状态..."
    
    cd "$SCRIPT_DIR"
    docker-compose -p paddlespeech ps
    
    if docker ps | grep -q "paddlespeech-server"; then
        log_success "PaddleSpeech 容器运行正常"
        
        # 检查普通服务 (8090)
        if curl -s --max-time 5 "http://localhost:8090" >/dev/null 2>&1; then
            log_success "普通语音服务 (8090) 响应正常"
        else
            log_warning "普通语音服务 (8090) 暂时无响应，可能仍在初始化"
        fi
        
        # 检查流式ASR服务 (8091)
        if curl -s --max-time 5 "http://localhost:8091" >/dev/null 2>&1; then
            log_success "流式语音识别服务 (8091) 响应正常"
        else
            log_warning "流式语音识别服务 (8091) 暂时无响应，可能仍在初始化"
        fi
        
        # 检查流式TTS服务 (8092)
        if curl -s --max-time 5 "http://localhost:8092" >/dev/null 2>&1; then
            log_success "流式语音合成服务 (8092) 响应正常"
        else
            log_warning "流式语音合成服务 (8092) 暂时无响应，可能仍在初始化"
        fi
    else
        log_error "PaddleSpeech 服务未运行"
    fi
}

# 查看日志
show_logs() {
    log_info "查看服务日志..."
    
    cd "$SCRIPT_DIR"
    docker-compose -p paddlespeech logs -f
}

# 清理环境
clean_environment() {
    log_info "清理环境..."
    
    cd "$SCRIPT_DIR"
    docker-compose -p paddlespeech down --remove-orphans
    
    read -p "是否删除 Docker 镜像？[y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker image rm paddlespeech:latest || true
        log_info "Docker 镜像已删除"
    fi
    
    read -p "是否删除数据卷？[y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
        log_info "数据卷已删除"
    fi
    
    log_success "环境清理完成"
}

# 主函数
main() {
    case "$OPERATION" in
        "build")
            check_environment
            build_image
            ;;
        "start")
            check_environment
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            check_service_status
            ;;
        "logs")
            show_logs
            ;;
        "clean")
            clean_environment
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 执行主函数
main