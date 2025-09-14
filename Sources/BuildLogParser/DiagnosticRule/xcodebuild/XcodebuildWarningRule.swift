import Foundation

// MARK: - XcodeBuild Warning Rule

// Parse xcodebuild tool-level warning messages
// Match format: --- xcodebuild: WARNING: message

public struct XcodeBuildWarningRule: DiagnosticRule {
    private let warningRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^--- xcodebuild: WARNING: (.+)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard
            let match = warningRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let messageRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }

        let message = String(line[messageRange])
        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .warning,
            message: message,
            relatedMessages: [],
            source: "xcodebuild",
            category: "warning",
            raw: line,
            buildTarget: nil
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "warning" else { return false }
        return line.hasPrefix("{ platform:") || line.hasPrefix("}")
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "warning" else { return false }
        return line.trimmingCharacters(in: .whitespaces).isEmpty ||
            line.hasPrefix("** BUILD FAILED **")
    }
}
