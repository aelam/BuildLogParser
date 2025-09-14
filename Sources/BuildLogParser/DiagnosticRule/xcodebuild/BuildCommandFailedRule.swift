import Foundation

// MARK: - Build Command Failed Rule

public struct BuildCommandFailedRule: DiagnosticRule {
    private let buildCommandFailedRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\s*(.+) \(in target '(.+)' from project '(.+)'\)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard let match = buildCommandFailedRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let commandRange = Range(match.range(at: 1), in: line),
              let targetRange = Range(match.range(at: 2), in: line),
              let projectRange = Range(match.range(at: 3), in: line)
        else { return nil }

        let command = String(line[commandRange])
        let target = String(line[targetRange])
        let project = String(line[projectRange])

        // 跳过已经被 SwiftCompile 规则匹配的行
        if command.contains("SwiftCompile") {
            return nil
        }

        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .error,
            message: "Build command failed: \(command)",
            relatedMessages: [],
            source: "xcodebuild",
            category: "build_command_failed",
            raw: line,
            buildTarget: "\(target) (\(project))"
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "build_command_failed" else { return false }
        return false // Build command failures are typically single line
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "build_command_failed" else { return false }
        return line.trimmingCharacters(in: .whitespaces).isEmpty ||
            line.hasPrefix("** BUILD FAILED **") ||
            line.hasPrefix("---")
    }
}
