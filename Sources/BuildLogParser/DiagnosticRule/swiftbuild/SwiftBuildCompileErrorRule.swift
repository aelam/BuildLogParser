import Foundation

// MARK: - Swift Build Compile Error Rule

// 解析 swift build 中编译器错误的格式
// 匹配格式: /path/file.swift:line:col: error/warning: message
// 包含后续的上下文行和错误指示符

public struct SwiftBuildCompileErrorRule: DiagnosticRule {
    private let startRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^(.*\.(swift|m|mm|c|cpp|h|hpp)):(\d+):(\d+): (error|warning): (.*)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    private let contextLineRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\s*(\d+)\s*\|\s*(.*)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    private let errorPointerRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\s*\|\s*`-\s*(error|warning):\s*(.*)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard let match = startRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        // 安全地提取匹配的组
        guard
            let fileRange = Range(match.range(at: 1), in: line),
            let lineNumRange = Range(match.range(at: 3), in: line),
            let colNumRange = Range(match.range(at: 4), in: line),
            let severityRange = Range(match.range(at: 5), in: line),
            let messageRange = Range(match.range(at: 6), in: line)
        else {
            return nil
        }

        let file = String(line[fileRange])
        let severityStr = String(line[severityRange])
        let message = String(line[messageRange])

        // 安全地转换数字
        guard
            let lineNum = Int(line[lineNumRange]),
            let colNum = Int(line[colNumRange])
        else {
            return nil
        }

        let severity: Diagnostic.Severity = (severityStr == "error" ? .error : .warning)

        return Diagnostic(
            file: file,
            line: lineNum,
            column: colNum,
            severity: severity,
            message: message,
            relatedMessages: [],
            source: "swift-build",
            category: "compile_\(severityStr)",
            raw: line,
            buildTarget: nil
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.source == "swift-build",
              current?.category?.hasPrefix("compile_") == true else { return false }

        // 匹配上下文行 (数字 | 代码)
        if contextLineRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }

        // 匹配错误指示行 (| `- error: message)
        if errorPointerRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }

        // 匹配空白行
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }

        return false
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard
            current?.source == "swift-build",
            current?.category?.hasPrefix("compile_") == true
        else { return false }

        // 如果是新的错误开始，结束当前诊断
        if startRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }

        // 如果遇到其他类型的消息，结束当前诊断
        if line.hasPrefix("error: "), line.contains("command failed") {
            return true
        }

        // 如果遇到编译进度行，结束当前诊断
        if line.hasPrefix("["), line.contains("]"), line.contains("Compiling") {
            return true
        }

        return false
    }
}
