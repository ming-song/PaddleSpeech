#!/usr/bin/env python3
"""
PaddleSpeech CORS 修补程序
修复 OPTIONS 预检请求返回 405 的问题
"""

import os
import sys

def patch_asr_api():
    """为 ASR API 添加 OPTIONS 方法支持"""
    asr_api_file = "/home/paddlespeech/PaddleSpeech/paddlespeech/server/restful/asr_api.py"
    
    # 读取原文件
    with open(asr_api_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否已经添加了OPTIONS方法
    if '@router.options("/paddlespeech/asr")' in content:
        print("ASR API OPTIONS方法已存在，跳过修补")
        return
    
    # 在POST方法之前添加OPTIONS方法
    post_route = '@router.post(\n    "/paddlespeech/asr", response_model=Union[ASRResponse, ErrorResponse])'
    options_route = '''@router.options("/paddlespeech/asr")
def asr_options():
    """Handle preflight OPTIONS request for ASR
    
    Returns:
        dict: Success response for CORS preflight
    """
    return {"message": "OK"}


@router.post(
    "/paddlespeech/asr", response_model=Union[ASRResponse, ErrorResponse])'''
    
    # 替换内容
    new_content = content.replace(post_route, options_route)
    
    # 写回文件
    with open(asr_api_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✅ ASR API OPTIONS方法修补完成")

def patch_tts_api():
    """为 TTS API 添加 OPTIONS 方法支持"""
    tts_api_file = "/home/paddlespeech/PaddleSpeech/paddlespeech/server/restful/tts_api.py"
    
    # 读取原文件
    with open(tts_api_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否已经添加了OPTIONS方法
    if '@router.options("/paddlespeech/tts")' in content:
        print("TTS API OPTIONS方法已存在，跳过修补")
        return
    
    # 查找POST路由
    if '@router.post("/paddlespeech/tts")' in content:
        post_route = '@router.post("/paddlespeech/tts")'
        options_route = '''@router.options("/paddlespeech/tts")
def tts_options():
    """Handle preflight OPTIONS request for TTS
    
    Returns:
        dict: Success response for CORS preflight
    """
    return {"message": "OK"}


@router.post("/paddlespeech/tts")'''
        
        # 替换内容
        new_content = content.replace(post_route, options_route)
        
        # 写回文件
        with open(tts_api_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print("✅ TTS API OPTIONS方法修补完成")
    else:
        print("⚠️  TTS API POST路由未找到，跳过修补")

if __name__ == "__main__":
    print("🔧 开始修补 PaddleSpeech CORS OPTIONS 支持...")
    patch_asr_api()
    patch_tts_api()
    print("🎉 CORS OPTIONS 修补完成！")
    print("请重启 PaddleSpeech 服务以应用修改")