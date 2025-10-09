#!/bin/bash

# 检查Docker网络子网信息的脚本

echo "=== Docker 网络子网信息 ==="
echo

# 获取所有自定义网络（排除默认网络）
CUSTOM_NETWORKS=$(docker network ls --format "{{.Name}}" | grep -vE "bridge|host|none")

if [ -z "$CUSTOM_NETWORKS" ]; then
    echo "未找到自定义网络"
    exit 0
fi

# 遍历每个网络并显示子网信息
for network in $CUSTOM_NETWORKS; do
    echo "=== 网络: $network ==="
    
    # 获取网络详细信息
    SUBNET=$(docker network inspect "$network" 2>/dev/null | grep -A 5 "IPAM" | grep "Subnet" | sed -E 's/.*"Subnet": "([^"]+)".*/\1/')
    
    if [ -n "$SUBNET" ]; then
        echo "子网: $SUBNET"
    else
        echo "子网: 未找到"
    fi
    
    # 显示使用该网络的容器
    CONTAINERS=$(docker network inspect "$network" 2>/dev/null | grep -A 20 "Containers" | grep "Name" | grep -v "NetworkID\|EndpointID\|GlobalIPv6Address\|IPAM" | sed -E 's/.*"Name": "([^"]+)".*/  \1/')
    
    if [ -n "$CONTAINERS" ]; then
        echo "使用容器:"
        echo "$CONTAINERS"
    else
        echo "使用容器: 无"
    fi
    
    echo
done

echo "=== 系统默认网络 ==="
echo "bridge: 通常使用 172.17.0.0/16"
echo "host: 使用主机网络"
echo "none: 无网络"