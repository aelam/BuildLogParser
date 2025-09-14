@testable import BuildLogParser
import Foundation
import Testing

struct BuildLogParserTests {
    @Test
    func batchProcessing() async throws {
        let rules: [DiagnosticRule] = [
            SwiftErrorRule(),
            LinkerErrorRule(),
            XCTestRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // 模拟日志行
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "Undefined symbols for architecture x86_64:",
            "  \"_foo\", referenced from:",
            "clang: error: linker command failed",
        ]

        let input = StringArrayInput(logLines)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let diagnostics = collectingOutput.getAllDiagnostics()

        #expect(!diagnostics.isEmpty, "应该解析出至少一个诊断")
        print("Total diagnostics: \(diagnostics.count)")
    }

    @Test
    func streamProcessing() async throws {
        let rules: [DiagnosticRule] = [
            SwiftErrorRule(),
            LinkerErrorRule(),
            XCTestRule()
        ]

        let parser = DiagnosticsParser(rules: rules)
        var receivedDiagnostics: [Diagnostic] = []

        // 设置实时处理器
        let output = CallbackOutput { diagnostic in
            receivedDiagnostics.append(diagnostic)
            print("🔍 实时发现诊断: \(diagnostic.severity) - \(diagnostic.message)")

            // 可以根据严重程度做不同处理
            switch diagnostic.severity {
            case .error:
                print("❌ 错误: \(diagnostic.file ?? "unknown"):\(diagnostic.line ?? 0)")
            case .warning:
                print("⚠️  警告: \(diagnostic.message)")
            case .info:
                print("ℹ️  信息: \(diagnostic.message)")
            case .note:
                print("📝 注释: \(diagnostic.message)")
            }
        }

        parser.addOutput(output)

        // 模拟流式输入
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "main.swift:15:3: warning: variable 'bar' was never used",
            "Undefined symbols for architecture x86_64:",
            "  \"_foo\", referenced from:",
            "clang: error: linker command failed",
        ]

        let input = StringArrayInput(logLines)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let allDiagnostics = collectingOutput.getAllDiagnostics()

        #expect(!allDiagnostics.isEmpty, "应该解析出至少一个诊断")
        #expect(receivedDiagnostics.count == allDiagnostics.count, "输出应该接收到所有诊断")
        print("✅ 处理完成，总共: \(allDiagnostics.count) 个诊断")
    }

    @Test
    func filteredStreamProcessing() async throws {
        let rules: [DiagnosticRule] = [
            SwiftErrorRule(),
            LinkerErrorRule(),
            XCTestRule()
        ]

        let parser = DiagnosticsParser(rules: rules)
        var errorDiagnostics: [Diagnostic] = []

        // 只关注错误级别的诊断
        let output = CallbackOutput { diagnostic in
            guard diagnostic.severity == .error else { return }

            errorDiagnostics.append(diagnostic)
            print("🚨 严重错误: \(diagnostic.message)")
            if let file = diagnostic.file, let line = diagnostic.line {
                print("📍 位置: \(file):\(line)")
            }

            // 可以立即通知开发者或中断构建
            notifyDeveloper(diagnostic)
        }

        parser.addOutput(output)

        // 模拟包含错误和警告的日志
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "main.swift:15:3: warning: variable 'bar' was never used",
            "Undefined symbols for architecture x86_64:",
            "  \"_foo\", referenced from:",
            "clang: error: linker command failed",
        ]

        let input = StringArrayInput(logLines)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let allDiagnostics = collectingOutput.getAllDiagnostics()
        let actualErrors = allDiagnostics.filter { $0.severity == .error }

        #expect(errorDiagnostics.count == actualErrors.count, "过滤后的错误数量应该匹配")
        #expect(!errorDiagnostics.isEmpty, "应该至少有一个错误")
    }

    private func notifyDeveloper(_ diagnostic: Diagnostic) {
        // 发送通知、邮件等
        print("📧 已通知开发者关于错误: \(diagnostic.message)")
    }

    @Test
    func multipleInputTypes() async throws {
        let rules: [DiagnosticRule] = [
            SwiftErrorRule(),
            LinkerErrorRule(),
            XCTestRule()
        ]

        // 测试字符串数组输入
        let parser1 = DiagnosticsParser(rules: rules)
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "main.swift:15:3: warning: variable 'bar' was never used",
        ]
        let input1 = StringArrayInput(logLines)
        let collectingOutput1 = CollectingOutput()
        parser1.addOutput(collectingOutput1)
        _ = try parser1.parse(input: input1)
        let result1 = collectingOutput1.getAllDiagnostics()
        #expect(result1.count >= 1, "字符串数组输入应该解析出诊断")

        // 测试文本字符串输入
        let parser2 = DiagnosticsParser(rules: rules)
        let logText = """
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        """
        let input2 = StringInput(logText)
        let collectingOutput2 = CollectingOutput()
        parser2.addOutput(collectingOutput2)
        _ = try parser2.parse(input: input2)
        let result2 = collectingOutput2.getAllDiagnostics()
        #expect(result2.count >= 1, "文本字符串输入应该解析出诊断")

        // 测试 Data 输入
        let parser3 = DiagnosticsParser(rules: rules)
        let logData = logText.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
        let input3 = DataInput(logData)
        let collectingOutput3 = CollectingOutput()
        parser3.addOutput(collectingOutput3)
        _ = try parser3.parse(input: input3)
        let result3 = collectingOutput3.getAllDiagnostics()
        #expect(result3.count >= 1, "Data 输入应该解析出诊断")

        // 验证三种方式结果一致
        #expect(result1.count == result2.count, "不同输入方式应该产生相同数量的诊断")
        #expect(result2.count == result3.count, "不同输入方式应该产生相同数量的诊断")
    }

    @Test
    func asyncInputProcessing() async throws {
        let rules: [DiagnosticRule] = [
            SwiftErrorRule(),
            LinkerErrorRule(),
            XCTestRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)
        var receivedDiagnostics: [Diagnostic] = []

        let output = CallbackOutput { diagnostic in
            receivedDiagnostics.append(diagnostic)
        }
        parser.addOutput(output)

        // 测试异步流式处理
        let logText = """
        main.swift:10:5: error: use of unresolved identifier 'foo'
        Undefined symbols for architecture x86_64:
          "_foo", referenced from:
        clang: error: linker command failed
        """

        let input = StringInput(logText)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let allDiagnostics = collectingOutput.getAllDiagnostics()

        #expect(receivedDiagnostics.count == allDiagnostics.count, "异步处理应该接收到所有诊断")
        #expect(allDiagnostics.isEmpty == false, "应该解析出诊断")
    }
}
