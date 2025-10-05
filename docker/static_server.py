#!/usr/bin/env python3
"""
PaddleSpeech 静态文件服务器
运行在8093端口，专门提供Web界面的静态文件服务
"""

import os
import http.server
import socketserver
from pathlib import Path

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # 设置静态文件根目录
        static_dir = Path(__file__).parent / "web"
        super().__init__(*args, directory=str(static_dir), **kwargs)
    
    def end_headers(self):
        # 添加CORS头，允许跨域请求
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_OPTIONS(self):
        # 处理预检请求
        self.send_response(200)
        self.end_headers()

def main():
    PORT = 8093
    web_dir = Path(__file__).parent / "web"
    
    # 检查web目录是否存在
    if not web_dir.exists():
        print(f"错误: Web目录 {web_dir} 不存在")
        return
    
    print(f"PaddleSpeech 静态文件服务器启动中...")
    print(f"端口: {PORT}")
    print(f"Web目录: {web_dir.absolute()}")
    print(f"访问地址: http://localhost:{PORT}/")
    print(f"主界面: http://localhost:{PORT}/index.html")
    print(f"测试页面: http://localhost:{PORT}/tts_test.html")
    print("按 Ctrl+C 停止服务器")
    
    try:
        with socketserver.TCPServer(("", PORT), CustomHTTPRequestHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n静态文件服务器已停止")
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"错误: 端口 {PORT} 已被占用")
            print("请检查是否有其他服务在使用该端口，或者修改PORT变量")
        else:
            print(f"服务器启动失败: {e}")

if __name__ == "__main__":
    main()