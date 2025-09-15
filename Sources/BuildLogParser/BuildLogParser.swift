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

#if canImport(Darwin)
@available(macOS 10.15, *)
public protocol AsyncDiagnosticInput {
    func readLines() async throws -> AsyncThrowingStream<String, Error>
}
#endif

// MARK: - Output Abstraction

public protocol DiagnosticOutput {
    func write(_ diagnostic: Diagnostic)
    func finish() // No longer need to pass diagnostic list
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

            // Process complete lines
            while let newlineRange = buffer.range(of: Data([0x0A])) { // \n
                let lineData = buffer.subdata(in: 0 ..< newlineRange.lowerBound)
                if let lineString = String(data: lineData, encoding: .utf8) {
                    // Only trim newlines, preserve spaces for proper alignment
                    lines.append(lineString.trimmingCharacters(in: .newlines))
                }
                buffer.removeSubrange(0 ..< newlineRange.upperBound)
            }
        }

        // Process last line
        if !buffer.isEmpty, let lastLine = String(data: buffer, encoding: .utf8) {
            // Only trim newlines, preserve spaces for proper alignment
            lines.append(lastLine.trimmingCharacters(in: .newlines))
        }

        return AnySequence(lines)
    }
}

// Async version of FileHandle input
#if canImport(Darwin)
@available(macOS 10.15, *)
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

                    // Process complete lines
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
                    // EOF - process last line
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
#endif

// MARK: - Output Implementations

public struct CallbackOutput: DiagnosticOutput {
    private let onDiagnostic: (Diagnostic) -> Void
    private let onFinish: () -> Void

    public init(
        onDiagnostic: @escaping (Diagnostic) -> Void,
        onFinish: @escaping () -> Void = {}
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
        // Can perform final processing here
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
        print("✅ Parsing completed")
    }
}

// MARK: - Error Types

public enum DiagnosticError: Error {
    case invalidEncoding
    case fileNotFound
    case streamError
}

public protocol DiagnosticRule {
    /// Fast fail check to avoid expensive regex operations
    /// Return false if this line definitely won't match this rule
    /// Return true if this line might match (will proceed to matchStart)
    func fastFail(line: String) -> Bool

    func matchStart(line: String) -> Diagnostic?
    func matchContinuation(line: String, current: Diagnostic?) -> Bool
    func isEnd(line: String, current: Diagnostic?) -> Bool
}

public extension DiagnosticRule {
    /// Default implementation always returns true (no fast fail)
    func fastFail(line: String) -> Bool {
        true
    }
}

public class DiagnosticsParser {
    private let rules: [DiagnosticRule]
    private var current: Diagnostic?
    private var outputs: [DiagnosticOutput] = []

    public init(rules: [DiagnosticRule]) {
        self.rules = rules
    }

    // Add output processor
    public func addOutput(_ output: DiagnosticOutput) {
        outputs.append(output)
    }

    // Convenience method: set callback output
    public func setDiagnosticHandler(_ handler: @escaping (Diagnostic) -> Void) {
        let callbackOutput = CallbackOutput(onDiagnostic: handler)
        addOutput(callbackOutput)
    }

    // Process input source
    public func parse(input: DiagnosticInput) throws {
        let lines = try input.readLines()
        for line in lines {
            consumeLine(line)
        }
        finish()
    }

    // Async process input source (Darwin only due to DispatchSource limitations)
    #if canImport(Darwin)
    @available(macOS 10.15, *)
    public func parse(input: AsyncDiagnosticInput) async throws {
        let lineStream = try await input.readLines()

        for try await line in lineStream {
            consumeLine(line)
        }

        finish()
    }
    #endif

    private func consumeLine(_ line: String) {
        // Check if it's an end condition
        for rule in rules where rule.isEnd(line: line, current: current) {
            flush()
            // Check if this line is also the start of a new diagnostic
            for startRule in rules {
                if startRule.fastFail(line: line), let diag = startRule.matchStart(line: line) {
                    current = diag
                    return
                }
            }
            return
        }

        // Check if it's a continuation line
        for rule in rules where rule.matchContinuation(line: line, current: current) {
            current?.relatedMessages.append(line)
            return
        }

        // Check if it's the start of a new diagnostic
        for rule in rules {
            if rule.fastFail(line: line), let diag = rule.matchStart(line: line) {
                flush() // First save the current diagnostic
                current = diag
                return
            }
        }

        // If nothing matches and there's a current diagnostic, may need to end it
        if current != nil {
            // Check if all rules think it should end
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

        // Notify all output processors that processing is complete
        for output in outputs {
            output.finish()
        }
    }

    private func flush() {
        if let diag = current {
            // Notify all output processors
            for output in outputs {
                output.write(diag)
            }

            current = nil
        }
    }
}
