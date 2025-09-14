# Swift Build 日志解析指南

## 🎯 使用 BuildLogParser 解析 swift build 输出

### 📋 推荐的规则组合

```swift
let rules: [DiagnosticRule] = [
    CompileErrorRule(),        // 解析编译器错误（主要）
    XcodeBuildRule(),         // 解析构建状态和任务失败（可选）
]
```

### 🔧 解析示例

#### 基本用法：
```swift
import BuildLogParser

let parser = DiagnosticsParser(rules: [
    CompileErrorRule(),
])

// 解析 swift build 的输出
let buildOutput = """
error: emit-module command failed with exit code 1 (use -v to see invocation)
/Users/test/TestError.swift:4:12: error: cannot find 'undefinedVariable' in scope
2 | 
3 | // 故意制造编译错误
4 | let test = undefinedVariable
  |            `- error: cannot find 'undefinedVariable' in scope
5 | print("Hello")
"""

let input = StringInput(buildOutput)
let output = CollectingOutput()
parser.addOutput(output)

try parser.parse(input: input)
let diagnostics = output.getAllDiagnostics()

// diagnostics 将包含：
// - 文件路径: /Users/test/TestError.swift
// - 行号: 4
// - 列号: 12
// - 错误类型: error
// - 消息: cannot find 'undefinedVariable' in scope
```

#### 实时解析：
```swift
let parser = DiagnosticsParser(rules: [CompileErrorRule()])

parser.setDiagnosticHandler { diagnostic in
    if diagnostic.severity == .error {
        print("❌ 编译错误: \(diagnostic.file ?? "unknown"):\(diagnostic.line ?? 0)")
        print("   \(diagnostic.message)")
    }
}

// 解析 swift build 的实时输出
let buildProcess = Process()
buildProcess.launchPath = "/usr/bin/swift"
buildProcess.arguments = ["build"]
// ... 设置管道和解析逻辑
```

### 📊 swift build vs xcodebuild

| 特性 | swift build | xcodebuild |
|------|-------------|------------|
| JSON 输出 | ❌ 无 | ❌ 无 |
| 错误格式 | `file:line:col: error: message` | `file:line:col: error: message` |
| 构建状态 | 简单文本 | 复杂的状态信息 |
| 任务信息 | 最小化 | 详细的任务列表 |
| 适用规则 | `CompileErrorRule` | `CompileErrorRule` + `XcodeBuildRule` |

### 🎯 最佳实践

1. **主要使用 CompileErrorRule**：
   - swift build 的错误格式与 xcodebuild 一致
   - 可以精确定位文件、行、列

2. **可选使用 XcodeBuildRule**：
   - 如果你想解析构建失败的总体状态
   - 某些子规则可能也适用于 swift build

3. **简化配置**：
   ```swift
   // 针对 swift build 的最简配置
   let parser = DiagnosticsParser(rules: [CompileErrorRule()])
   ```

4. **实时监控**：
   ```swift
   // 实时监控 swift build 过程
   let parser = DiagnosticsParser(rules: [CompileErrorRule()])
   parser.setDiagnosticHandler { diagnostic in
       // 立即处理每个诊断
       notifyIDE(diagnostic)
   }
   ```

### ✅ 结论

**你的 BuildLogParser 可以完美处理 swift build 的输出！**
- 无需额外修改
- 使用现有的 `CompileErrorRule` 即可
- 支持所有主要的编译错误格式