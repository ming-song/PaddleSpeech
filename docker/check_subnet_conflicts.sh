#!/bin/bash

# 检查Docker网络子网冲突的脚本

echo "=== Docker 网络子网冲突检查 ==="
echo

# 定义PaddleSpeech将要使用的子网
PADDLESPEECH_SUBNET="172.30.0.0/16"
echo "PaddleSpeech计划使用子网: $PADDLESPEECH_SUBNET"
echo

# 获取所有现有网络的子网
echo "现有网络子网信息:"
echo "------------------------"

CONFLICT_FOUND=false

# 遍历所有网络
for network in $(docker network ls --format "{{.Name}}" | grep -vE "bridge|host|none"); do
    SUBNET=$(docker network inspect "$network" 2>/dev/null | grep -A 5 "IPAM" | grep "Subnet" | sed -E 's/.*"Subnet": "([^"]+)".*/\1/')
    
    if [ -n "$SUBNET" ]; then
        echo "$network: $SUBNET"
        
        # 检查是否与PaddleSpeech计划使用的子网冲突
        if [ "$SUBNET" = "$PADDLESPEECH_SUBNET" ]; then
            echo "  ⚠️  警告: 与PaddleSpeech计划使用的子网冲突!"
            CONFLICT_FOUND=true
        fi
    fi
done

echo

if [ "$CONFLICT_FOUND" = true ]; then
    echo "⚠️  发现子网冲突!"
    echo "建议解决方案:"
    echo "1. 删除冲突的网络: docker network rm <network_name>"
    echo "2. 或修改docker-compose.yml中的子网配置"
else
    echo "✅ 未发现子网冲突"
fi