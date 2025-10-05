#!/usr/bin/env python3
"""
PaddleSpeech 静态文件服务补丁
为 PaddleSpeech 服务器添加静态文件托管功能
"""

import os
import sys
import yaml
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.responses import RedirectResponse

def patch_static_files_support():
    """为 PaddleSpeech 服务器添加静态文件支持"""
    
    # 导入 PaddleSpeech 的 app 实例
    from paddlespeech.server.bin.paddlespeech_server import app
    
    # 读取配置文件
    config_file = "/home/paddlespeech/PaddleSpeech/conf/application.yaml"
    if os.path.exists(config_file):
        with open(config_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        
        # 获取静态文件配置
        static_path = config.get('static_path', '/home/paddlespeech/PaddleSpeech/docker/web')
        static_url_path = config.get('static_url_path', '/static')
        
        # 检查静态文件目录是否存在
        if os.path.exists(static_path):
            print(f"[静态文件] 添加静态文件支持: {static_url_path} -> {static_path}")
            
            # 添加静态文件中间件
            app.mount(static_url_path, StaticFiles(directory=static_path), name="static")
            
            # 添加根路径重定向到测试网页
            @app.get("/")
            async def redirect_to_web():
                return RedirectResponse(url="/static/index.html")
            
            print("[静态文件] 静态文件服务配置完成")
            print(f"[静态文件] 访问地址: http://localhost:8090/")
            print(f"[静态文件] 静态文件地址: http://localhost:8090{static_url_path}/")
        else:
            print(f"[静态文件] 警告: 静态文件目录不存在: {static_path}")
    else:
        print(f"[静态文件] 警告: 配置文件不存在: {config_file}")

if __name__ == "__main__":
    patch_static_files_support()