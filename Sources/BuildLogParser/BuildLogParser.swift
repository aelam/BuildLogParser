//
//  BuildLogParser.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

// MARK: - Input Abstraction

public protocol DiagnosticInput {
    func readLines() throws -> AnySequence<String>
}

// 异步输入协议
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncDiagnosticInput {
    func readLines() async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - Output Abstraction

public protocol DiagnosticOutput {
    func write(_ diagnostic: Diagnostic)
    func finish() // 不再需要传递诊断列表
}

// MARK: - Input Implementations

public struct StringInput: DiagnosticInput {
    private let content: String

    public init(_ content: String) {
        self.content = content
    }

    public func readLines() throws -> AnySequence<String> {
        let lines = content.components(separatedBy: .newlines)
        return AnySequence(lines)
    }
}

public struct StringArrayInput: DiagnosticInput {
    private let lines: [String]

    public init(_ lines: [String]) {
        self.lines = lines
    }

    public func readLines() throws -> AnySequence<String> {
        AnySequence(lines)
    }
}

public struct DataInput: DiagnosticInput {
    private let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public func readLines() throws -> AnySequence<String> {
        guard let content = String(data: data, encoding: .utf8) else {
            throw DiagnosticError.invalidEncoding
        }
        let lines = content.components(separatedBy: .newlines)
        return AnySequence(lines)
    }
}

public struct FileInput: DiagnosticInput {
    private let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public func readLines() throws -> AnySequence<String> {
        let data = try Data(contentsOf: url)
        return try DataInput(data).readLines()
    }
}

public struct FileHandleInput: DiagnosticInput {
    private let fileHandle: FileHandle

    public init(_ fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    public func readLines() throws -> AnySequence<String> {
        var lines: [String] = []
        let bufferSize = 8192
        var buffer = Data()

        while true {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty { break }

            buffer.append(data)

            // 处理完整的行
            while let newlineRange = buffer.range(of: Data([0x0A])) { // \n
                let lineData = buffer.subdata(in: 0 ..< newlineRange.lowerBound)
                if let lineString = String(data: lineData, encoding: .utf8) {
                    lines.append(lineString.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                buffer.removeSubrange(0 ..< newlineRange.upperBound)
            }
        }

        // 处理最后一行
        if !buffer.isEmpty, let lastLine = String(data: buffer, encoding: .utf8) {
            lines.append(lastLine.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return AnySequence(lines)
    }
}

// 异步版本的 FileHandle 输入
@available(macOS 10.15, iOS 13.0, *)
public struct AsyncFileHandleInput: AsyncDiagnosticInput {
    private let fileHandle: FileHandle

    public init(_ fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    public func readLines() async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { continuation in
            let bufferSize = 8192
            var lineBuffer = Data()

            let source = DispatchSource.makeReadSource(fileDescriptor: fileHandle.fileDescriptor)

            source.setEventHandler {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }

                let bytesRead = read(fileHandle.fileDescriptor, buffer, bufferSize)
                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: bytesRead)
                    lineBuffer.append(data)

                    // 处理完整的行
                    while let newlineIndex = lineBuffer.firstIndex(of: 0x0A) {
                        let lineData = lineBuffer.prefix(through: newlineIndex)
                        lineBuffer.removeFirst(lineData.count)

                        if let string = String(data: lineData, encoding: .utf8) {
                            let trimmedLine = string.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedLine.isEmpty {
                                continuation.yield(trimmedLine)
                            }
                        }
                    }
                } else if bytesRead == 0 {
                    // EOF - 处理最后一行
                    if !lineBuffer.isEmpty, let string = String(data: lineBuffer, encoding: .utf8) {
                        let finalString = string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !finalString.isEmpty {
                            continuation.yield(finalString)
                        }
                    }
                    continuation.finish()
                } else {
                    continuation.finish(throwing: POSIXError(.EIO))
                }
            }

            source.setCancelHandler {
                continuation.finish()
            }

            continuation.onTermination = { _ in
                source.cancel()
            }

            source.resume()
        }
    }
}

// MARK: - Output Implementations

public struct CallbackOutput: DiagnosticOutput {
    private let onDiagnostic: (Diagnostic) -> Void
    private let onFinish: () -> Void

    public init(
        onDiagnostic: @escaping (Diagnostic) -> Void,
        onFinish: @escaping () -> Void = {},
    ) {
        self.onDiagnostic = onDiagnostic
        self.onFinish = onFinish
    }

    public func write(_ diagnostic: Diagnostic) {
        onDiagnostic(diagnostic)
    }

    public func finish() {
        onFinish()
    }
}

public class CollectingOutput: DiagnosticOutput {
    private var collectedDiagnostics: [Diagnostic] = []

    public init() {}

    public func write(_ diagnostic: Diagnostic) {
        collectedDiagnostics.append(diagnostic)
    }

    public func finish() {
        // 可以在这里做最终处理
    }

    public func getAllDiagnostics() -> [Diagnostic] {
        collectedDiagnostics
    }
}

public struct PrintOutput: DiagnosticOutput {
    public init() {}

    public func write(_ diagnostic: Diagnostic) {
        let severity = diagnostic.severity
        let icon = switch severity {
        case .error: "❌"
        case .warning: "⚠️"
        case .info: "ℹ️"
        case .note: "📝"
        }

        if let file = diagnostic.file, let line = diagnostic.line {
            print("\(icon) \(file):\(line): \(severity) - \(diagnostic.message)")
        } else {
            print("\(icon) \(severity) - \(diagnostic.message)")
        }
    }

    public func finish() {
        print("✅ 解析完成")
    }
}

// MARK: - Error Types

public enum DiagnosticError: Error {
    case invalidEncoding
    case fileNotFound
    case streamError
}

public protocol DiagnosticRule {
    func matchStart(line: String) -> Diagnostic?
    func matchContinuation(line: String, current: Diagnostic?) -> Bool
    func isEnd(line: String, current: Diagnostic?) -> Bool
}

public class DiagnosticsParser {
    private let rules: [DiagnosticRule]
    private var current: Diagnostic?
    private var outputs: [DiagnosticOutput] = []

    public init(rules: [DiagnosticRule]) {
        self.rules = rules
    }

    // 添加输出处理器
    public func addOutput(_ output: DiagnosticOutput) {
        outputs.append(output)
    }

    // 便捷方法：设置回调输出
    public func setDiagnosticHandler(_ handler: @escaping (Diagnostic) -> Void) {
        let callbackOutput = CallbackOutput(onDiagnostic: handler)
        addOutput(callbackOutput)
    }

    // 处理输入源
    public func parse(input: DiagnosticInput) throws {
        let lines = try input.readLines()
        for line in lines {
            consumeLine(line)
        }
        finish()
    }

    // 异步处理输入源
    @available(macOS 10.15, iOS 13.0, *)
    public func parse(input: AsyncDiagnosticInput) async throws {
        let lineStream = try await input.readLines()

        for try await line in lineStream {
            consumeLine(line)
        }

        finish()
    }

    private func consumeLine(_ line: String) {
        // 检查是否是结束条件
        for rule in rules where rule.isEnd(line: line, current: current) {
            flush()
            // 检查这一行是否同时是新诊断的开始
            for startRule in rules {
                if let diag = startRule.matchStart(line: line) {
                    current = diag
                    return
                }
            }
            return
        }

        // 检查是否是继续行
        for rule in rules where rule.matchContinuation(line: line, current: current) {
            current?.relatedMessages.append(line)
            return
        }

        // 检查是否是新诊断的开始
        for rule in rules {
            if let diag = rule.matchStart(line: line) {
                flush() // 先保存当前的诊断
                current = diag
                return
            }
        }

        // 如果都不匹配，且当前有诊断，可能需要结束当前诊断
        if current != nil {
            // 检查是否所有规则都认为应该结束
            let shouldEnd = rules.allSatisfy { rule in
                rule.isEnd(line: line, current: current)
            }
            if shouldEnd {
                flush()
            }
        }
    }

    public func finish() {
        flush()

        // 通知所有输出处理器处理完成
        for output in outputs {
            output.finish()
        }
    }

    private func flush() {
        if let diag = current {
            // 通知所有输出处理器
            for output in outputs {
                output.write(diag)
            }

            current = nil
        }
    }
}
