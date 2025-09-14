//
//  Usage.swift
//  BuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

public class BuildLogParserUsage {
    public static func demonstrateInputs() {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule()
        ]

        let parser = DiagnosticsParser(rules: rules)

        // 添加打印输出
        parser.addOutput(PrintOutput())

        // 1. 字符串输入
        let stringInput = StringInput("""
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        """)

        do {
            let collectingOutput = CollectingOutput()
            parser.addOutput(collectingOutput)
            try parser.parse(input: stringInput)
            let result1 = collectingOutput.getAllDiagnostics()
            print("字符串输入解析结果: \(result1.count) 个诊断")
        } catch {
            print("解析错误: \(error)")
        }
    }

    // 示例2：使用不同的输出源
    public static func demonstrateOutputs() {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // 添加多个输出处理器
        parser.addOutput(PrintOutput())

        // 添加回调输出（只处理错误）
        let errorOnlyOutput = CallbackOutput(onDiagnostic: { diagnostic in
            if diagnostic.severity == .error {
                print("🚨 发现严重错误: \(diagnostic.message)")
            }
        })
        parser.addOutput(errorOnlyOutput)

        // 添加收集输出（用于后续分析）
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)

        let input = StringInput("""
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        """)

        do {
            _ = try parser.parse(input: input)
            print("收集到的诊断: \(collectingOutput.getAllDiagnostics().count) 个")
        } catch {
            print("解析错误: \(error)")
        }
    }

    // 示例3：处理多种类型的输入源
    public static func demonstrateMultipleInputs() {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // 合并多个输入源的内容
        let combinedInput = StringInput("""
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        Undefined symbols for architecture x86_64:
          "_foo", referenced from:
        clang: error: linker command failed
        """)

        do {
            let collectingOutput = CollectingOutput()
            parser.addOutput(collectingOutput)
            try parser.parse(input: combinedInput)
            let result = collectingOutput.getAllDiagnostics()
            print("多类型输入解析结果: \(result.count) 个诊断")
        } catch {
            print("解析错误: \(error)")
        }
    }

    // 示例4：自定义输入和输出
    public static func demonstrateCustomInputOutput() {
        // 自定义输入：从网络流读取
        struct NetworkInput: DiagnosticInput {
            let url: URL

            func readLines() throws -> AnySequence<String> {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    throw DiagnosticError.invalidEncoding
                }
                let lines = content.components(separatedBy: .newlines)
                return AnySequence(lines)
            }
        }

        // 自定义输出：写入文件
        class FileOutput: DiagnosticOutput {
            let url: URL
            private var content = ""

            init(url: URL) {
                self.url = url
            }

            func write(_ diagnostic: Diagnostic) {
                content += "\(diagnostic.severity): \(diagnostic.message)\n"
            }

            func finish() {
                try? content.write(to: url, atomically: true, encoding: .utf8)
                print("诊断结果已写入: \(url.path)")
            }
        }

        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // 使用自定义输出
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("diagnostics.txt")
        let fileOutput = FileOutput(url: outputURL)
        parser.addOutput(fileOutput)

        // 模拟使用
        let input = StringInput("main.swift:10:5: error: use of unresolved identifier 'foo'")

        do {
            _ = try parser.parse(input: input)
        } catch {
            print("解析错误: \(error)")
        }
    }

    // 示例5：异步流式处理 (macOS 10.15+)
    @available(macOS 10.15, iOS 13.0, *)
    public static func demonstrateAsyncStreaming() async {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)
        parser.addOutput(PrintOutput())

        // 模拟创建一个 pipe 用于流式输入
        let pipe = Pipe()
        let writeHandle = pipe.fileHandleForWriting
        let readHandle = pipe.fileHandleForReading

        // 创建异步输入
        let asyncInput = AsyncFileHandleInput(readHandle)

        // 在后台写入数据
        Task {
            let logData = Data("""
            main.swift:10:5: error: use of unresolved identifier 'foo'
            main.swift:15:3: warning: variable 'bar' was never used
            Undefined symbols for architecture x86_64:
              "_foo", referenced from:
            clang: error: linker command failed
            """.utf8)

            writeHandle.write(logData)
            writeHandle.closeFile()
        }

        do {
            let collectingOutput = CollectingOutput()
            parser.addOutput(collectingOutput)
            try await parser.parse(input: asyncInput)
            let diagnostics = collectingOutput.getAllDiagnostics()
            print("异步流式处理完成: \(diagnostics.count) 个诊断")
        } catch {
            print("异步处理错误: \(error)")
        }
    }
}
