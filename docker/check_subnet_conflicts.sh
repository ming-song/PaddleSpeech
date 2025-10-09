#!/bin/bash

# 检查Docker网络子网冲突的脚本

echo "=== Docker 网络子网冲突检查 ==="
echo

# 从docker-compose.yml文件中动态获取PaddleSpeech将要使用的子网
PADDLESPEECH_SUBNET=""

if [ -f "docker-compose.yml" ]; then
    # 使用更准确的方法解析subnet配置
    PADDLESPEECH_SUBNET=$(grep -A 3 "ipam:" docker-compose.yml | grep "subnet:" | sed -E 's/.*subnet: *([0-9./]+).*/\1/' | head -1)
    
    if [ -n "$PADDLESPEECH_SUBNET" ]; then
        echo "从docker-compose.yml解析到PaddleSpeech子网: $PADDLESPEECH_SUBNET"
    else
        # 如果还是找不到，使用默认值
        PADDLESPEECH_SUBNET="172.40.0.0/16"
        echo "警告: 无法从docker-compose.yml中解析子网，使用默认值: $PADDLESPEECH_SUBNET"
    fi
else
    PADDLESPEECH_SUBNET="172.40.0.0/16"
    echo "警告: 未找到docker-compose.yml文件，使用默认值: $PADDLESPEECH_SUBNET"
fi

echo

# 获取所有现有网络的子网
echo "现有网络子网信息:"
echo "------------------------"

CONFLICT_FOUND=false

# 遍历所有网络
docker_networks=$(docker network ls --format "{{.Name}}" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "错误: 无法获取Docker网络列表"
    exit 1
fi

for network in $docker_networks; do
    # 跳过默认网络
    if [[ "$network" == "bridge" || "$network" == "host" || "$network" == "none" ]]; then
        continue
    fi
    
    network_info=$(docker network inspect "$network" 2>/dev/null)
    if [ $? -ne 0 ]; then
        continue
    fi
    
    SUBNET=$(echo "$network_info" | grep -A 5 "IPAM" | grep "Subnet" | sed -E 's/.*"Subnet": "([^"]+)".*/\1/' | head -1)
    
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