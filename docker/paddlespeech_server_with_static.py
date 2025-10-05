#!/usr/bin/env python3
"""
PaddleSpeech 服务器启动脚本（包含静态文件支持）
基于原始 paddlespeech_server.py 添加静态文件托管功能
"""

import argparse
import os
import sys
import warnings
from typing import List

import numpy
import uvicorn
import yaml
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.responses import RedirectResponse
from paddlespeech.cli.log import logger
from paddlespeech.resource import CommonTaskResource
from paddlespeech.server.engine.engine_pool import init_engine_pool
from paddlespeech.server.engine.engine_warmup import warm_up
from paddlespeech.server.restful.api import setup_router as setup_http_router
from paddlespeech.server.utils.config import get_config
from paddlespeech.server.ws.api import setup_router as setup_ws_router
from prettytable import PrettyTable
from starlette.middleware.cors import CORSMiddleware

warnings.filterwarnings("ignore")

app = FastAPI(
    title="PaddleSpeech Serving API", description="Api", version="0.0.1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"])


def setup_static_files(config):
    """设置静态文件服务"""
    static_path = getattr(config, 'static_path', None)
    static_url_path = getattr(config, 'static_url_path', '/static')
    
    if static_path and os.path.exists(static_path):
        logger.info(f"设置静态文件服务: {static_url_path} -> {static_path}")
        app.mount(static_url_path, StaticFiles(directory=static_path), name="static")
        
        # 添加根路径重定向
        @app.get("/")
        async def redirect_to_web():
            return RedirectResponse(url="/static/index.html")
        
        logger.info("静态文件服务配置完成")
        logger.info(f"测试网页访问地址: http://localhost:{config.port}/")
    else:
        logger.warning(f"静态文件目录不存在或未配置: {static_path}")


class ServerExecutor:
    def __init__(self):
        self.parser = argparse.ArgumentParser(
            prog='paddlespeech_server_with_static', add_help=True)
        self.parser.add_argument(
            "--config_file",
            action="store",
            help="yaml file of the app",
            default=None,
            required=True)
        self.parser.add_argument(
            "--log_file",
            action="store",
            help="log file",
            default="./log/paddlespeech.log")

    def init(self, config) -> bool:
        """系统初始化"""
        # 初始化 API
        api_list = list(engine.split("_")[0] for engine in config.engine_list)
        if config.protocol == "websocket":
            api_router = setup_ws_router(api_list)
        elif config.protocol == "http":
            api_router = setup_http_router(api_list)
        else:
            raise Exception("unsupported protocol")
        
        app.include_router(api_router)
        
        # 设置静态文件服务
        setup_static_files(config)
        
        logger.info("开始初始化引擎")
        if not init_engine_pool(config):
            return False

        # 预热
        for engine_and_type in config.engine_list:
            if not warm_up(engine_and_type):
                return False

        return True

    def __call__(self, config_file: str, log_file: str = "./log/paddlespeech.log"):
        """启动服务器"""
        config = get_config(config_file)
        if self.init(config):
            logger.info(f"启动 PaddleSpeech 服务器，地址: {config.host}:{config.port}")
            uvicorn.run(app, host=config.host, port=config.port)


def main():
    """主函数"""
    if len(sys.argv) != 2:
        print("用法: python paddlespeech_server_with_static.py <config_file>")
        sys.exit(1)
    
    config_file = sys.argv[1]
    
    try:
        executor = ServerExecutor()
        executor(config_file)
    except Exception as e:
        logger.error("启动服务器失败")
        logger.error(e)
        sys.exit(1)


if __name__ == "__main__":
    main()