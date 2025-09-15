# BuildLogParser Development Guide

## 🚀 快速开始

### 构建项目
```bash
# 解析依赖
swift package resolve

# 构建 Debug 版本
swift build

# 构建 Release 版本
swift build -c release
```

### 运行测试
```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter BuildLogParserTests
```


## 🔄 CI/CD 流水线

项目配置了 GitHub Actions 来确保跨平台兼容性：

- **CI 流水线** (`.github/workflows/ci.yml`) - 在每次推送和 PR 时运行
- **发布流水线** (`.github/workflows/release.yml`) - 在推送版本标签时运行

### 支持的平台矩阵
- ✅ macOS (最新版)
- ✅ Linux (Ubuntu 最新版)
- ✅ Swift 5.9 和 5.10

## 📋 开发工作流

### 1. 日常开发
```bash
# 编辑代码后
swift build              # 确保编译通过
swift test               # 运行测试
```


### 3. 发布新版本
```bash

# 2. 创建并推送版本标签
git tag v1.0.0
git push origin v1.0.0

# 3. GitHub Actions 会自动创建 Release
```

## 🛠️ 清理和维护

```bash
# 清理构建产物
swift package clean

# 重新解析依赖
swift package resolve

# 强制重新构建
swift package clean && swift build
```

## 📚 相关文档

- [跨平台 CI/CD 详细指南](CROSS_PLATFORM_CI.md)
- [平台支持说明](PLATFORM_SUPPORT.md)
- [GitHub Actions 配置](.github/README.md)