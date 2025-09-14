import Foundation

// MARK: - Build Failed Rule

public struct BuildFailedRule: DiagnosticRule {
    private let buildFailedRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\*\* BUILD FAILED \*\*$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard buildFailedRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil else {
            return nil
        }
        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .error,
            message: "BUILD FAILED",
            relatedMessages: [],
            source: "xcodebuild",
            category: "build_failed",
            raw: line,
            buildTarget: nil
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "build_failed" else { return false }
        return line.hasPrefix("The following build commands failed:") ||
            line.hasPrefix("\t") ||
            line.contains("failures)")
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "build_failed" else { return false }
        return line.contains("failures)")
    }
}
