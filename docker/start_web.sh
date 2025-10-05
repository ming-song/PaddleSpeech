#!/bin/bash

# 启动测试网页服务器
# 在8093端口提供PaddleSpeech测试网页

echo "🌐 启动 PaddleSpeech 测试网页服务器..."

# 检查端口是否被占用
if netstat -tulpn | grep -q ":8093 "; then
    echo "⚠️  端口 8093 已被占用，正在终止占用进程..."
    pkill -f "python -m http.server 8093" 2>/dev/null || true
    sleep 2
fi

# 切换到web目录
cd "$(dirname "$0")/web"

echo "📁 当前目录: $(pwd)"
echo "📄 网页文件:"
ls -la

# 启动HTTP服务器
echo "🚀 在端口 8093 启动HTTP服务器..."
echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 PaddleSpeech 测试网页已启动！"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📱 访问地址: http://localhost:8093/"
echo ""
echo "🎯 功能特性:"
echo "  • 🎙️  实时语音识别 (WebSocket)"
echo "  • 📁  文件上传语音识别"
echo "  • 🗣️  普通语音合成"
echo "  • ⚡  流式语音合成"
echo ""
echo "📝 注意事项:"
echo "  • 确保 PaddleSpeech 服务正在运行 (端口 8090-8092)"
echo "  • 浏览器需要支持 WebRTC (用于录音功能)"
echo "  • 建议使用 Chrome/Firefox 等现代浏览器"
echo ""
echo "🛑 按 Ctrl+C 停止服务器"
echo "════════════════════════════════════════════════════════"
echo ""

python -m http.server 8093