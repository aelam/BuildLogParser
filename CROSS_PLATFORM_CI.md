# Cross-Platform CI/CD Setup

BuildLogParser 现在配置了完整的跨平台 CI/CD 流水线，支持 macOS 和 Linux。

## 🎯 目标平台

- ✅ **macOS 10.15+** - 主要开发和测试平台
- ✅ **Linux** - 完全支持（Ubuntu, CentOS, 等）  
- ⚪ **Windows** - 理论支持（通过 Swift for Windows）

## 🔄 CI/CD 工作流

### 1. 持续集成 (CI) - `.github/workflows/ci.yml`

**触发条件:**
- 推送到 `main` 或 `develop` 分支
- 提交 Pull Request

**矩阵测试:**
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
    swift-version: ['5.9', '5.10']
```

**测试内容:**
- 🔨 构建测试（Debug 和 Release）
- 🧪 单元测试
- 🔍 跨平台 API 验证
- 📝 代码质量检查
- 🕰️ 兼容性测试（旧版 macOS）

### 2. 发布流程 (Release) - `.github/workflows/release.yml`

**触发条件:**
- 推送版本标签（如 `v1.0.0`）

**功能:**
- 自动创建 GitHub Release
- 在多平台验证构建
- 生成构建产物
- 最终验证测试

## 🛠️ 本地开发工具

### 常用命令

```bash
# 构建和测试
swift build                    # 构建 Debug 版本
swift build -c release        # 构建 Release 版本
swift test                     # 运行测试
swift package resolve         # 解析依赖
swift package clean           # 清理构建产物

# 跨平台验证
./scripts/verify-cross-platform.sh
```

### 跨平台验证脚本

```bash
./scripts/verify-cross-platform.sh
```

**检查内容:**
- ❌ 平台特定导入 (UIKit, AppKit, etc.)
- ❌ 移动平台 `@available` 属性
- ⚠️  潜在的 Windows 不兼容 API
- ✅ 构建成功
- ✅ 测试通过

## 📋 跨平台兼容性指南

### ✅ 推荐使用的 API

```swift
// 跨平台文件操作
import Foundation
let url = URL(fileURLWithPath: "/path/to/file")
let data = try Data(contentsOf: url)

// 跨平台字符串处理
let regex = try NSRegularExpression(pattern: "...", options: [])

// 跨平台进程通信
let pipe = Pipe()
let fileHandle = pipe.fileHandleForReading
```

### ❌ 避免使用的 API

```swift
// 平台特定 - 不要使用
import UIKit          // 仅 iOS
import AppKit          // 仅 macOS
import WatchKit        // 仅 watchOS

// 平台特定可用性 - 不要使用
@available(iOS 13.0, *)           // 移动平台
@available(watchOS 6.0, *)        // 手表平台
```

### ⚠️ 需要注意的 API

```swift
// 这些在 Windows 上可能有问题
FileManager.default.homeDirectory    // 可能不存在
Bundle.main                         // 行为可能不同
```

## 🚀 发布流程

1. **准备发布:**
   ```bash
   ./scripts/verify-cross-platform.sh    # 本地验证
   swift build -c release               # 构建 Release 版本
   swift test                          # 运行测试
   ```

2. **创建版本标签:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **自动化流程:**
   - GitHub Actions 自动运行
   - 多平台构建和测试
   - 创建 GitHub Release

## 📊 状态徽章

在主 README 中添加这些徽章：

```markdown
![CI](https://github.com/aelam/BuildLogParser/workflows/CI/badge.svg)
![Release](https://github.com/aelam/BuildLogParser/workflows/Release/badge.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue.svg)
![Swift](https://img.shields.io/badge/swift-5.9%20%7C%205.10-orange.svg)
```

## 🐛 故障排除

### CI 失败常见原因:

1. **平台特定代码:**
   ```bash
   # 检查是否使用了平台特定 API
   grep -r "import UIKit\|import AppKit" Sources/
   ```

2. **移动平台属性:**
   ```bash
   # 检查是否有移动平台的 @available
   grep -r "@available.*iOS" Sources/
   ```

3. **测试失败:**
   - 检查测试是否依赖平台特定功能
   - 确保测试数据在所有平台上都可用

### 本地测试 Linux 兼容性:

```bash
# 使用 Docker 模拟 Linux 环境
docker run --rm -v "$PWD":/workspace swift:5.10 bash -c "cd /workspace && swift test"
```

## 📚 相关文件

- `.github/workflows/ci.yml` - 主要 CI 工作流
- `.github/workflows/ci.yml` - 主要 CI 工作流
- `.github/workflows/release.yml` - 发布工作流
- `scripts/verify-cross-platform.sh` - 跨平台验证脚本
- `Package.swift` - 包配置（只声明 macOS 最低版本）