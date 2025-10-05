# PaddleSpeech 自建镜像更新说明

## 🔄 关键变更

### 1. 移除 aistudio-sdk 版本限制

**变更前:**
```dockerfile
pip install "aistudio-sdk==0.2.6" && \
pip install -e .
```

**变更后:**
```dockerfile
pip install -e .
```

**原因:**
- 遵循避免固定第三方SDK版本的最佳实践
- 让 PaddleSpeech 框架自行解决依赖版本兼容性问题
- 避免因版本冲突导致的模块导入失败

### 2. 简化依赖检查逻辑

**entrypoint.sh 中的变更:**
- 移除强制降级 aistudio-sdk 的逻辑
- 改为仅检查是否安装，不强制特定版本
- 如果未安装，给出警告但不中断启动

### 3. 移除自定义服务依赖

**Dockerfile 清理:**
- 移除 `docker/services/` 目录复制
- 移除 `docker/web/` 目录复制  
- 移除 `docker/configs/` 目录复制
- 只保留 PaddleSpeech 原生服务所需的配置

## 🎯 新构建流程优势

### 1. 版本兼容性
- **自动解决依赖**: 让 PaddleSpeech 安装时自动选择兼容版本
- **减少冲突**: 避免手动指定版本导致的依赖冲突
- **跟随更新**: 自动跟随 PaddleSpeech 的依赖更新

### 2. 构建稳定性
- **简化流程**: 减少人工干预的版本管理
- **容错性强**: 即使某些依赖版本有变化也能正常构建
- **维护性好**: 无需跟踪第三方库的版本更新

### 3. 运行时表现
- **启动更快**: 减少版本检查和强制降级的时间
- **兼容性好**: 使用 PaddleSpeech 推荐的依赖版本
- **错误更少**: 避免版本不匹配导致的运行时错误

## 🚀 测试建议

### 1. 构建测试
```bash
cd /home/songm/code/PaddleSpeech/docker
./deploy.sh build
```

### 2. 功能验证
```bash
# 启动服务
./deploy.sh start

# 运行测试
./test.sh

# 检查依赖版本（应该看到新版本）
docker exec paddlespeech-server pip show aistudio-sdk
```

### 3. 性能对比
- 对比构建时间（应该更快）
- 对比启动时间（应该更快）
- 验证 ASR/TTS 功能正常

## 📝 注意事项

1. **首次构建**: 可能需要重新下载依赖包
2. **版本变化**: aistudio-sdk 可能会使用最新版本
3. **兼容性**: 如果出现问题，可以回退到固定版本方案
4. **监控**: 关注启动日志中的依赖版本信息

## 🔍 故障排除

如果遇到依赖版本问题：

1. **查看版本**: `docker exec paddlespeech-server pip list | grep aistudio`
2. **检查日志**: `docker logs paddlespeech-server`
3. **手动测试**: 进入容器测试功能模块
4. **回退方案**: 必要时可恢复固定版本

---

更新时间: $(date)
更新原因: 遵循最佳实践，让框架自行管理依赖版本