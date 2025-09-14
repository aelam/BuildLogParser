import Foundation

// MARK: - Swift Build Module Failed Rule

// Parse module generation failure messages in swift build
// Match format: error: emit-module command failed with exit code N

public struct SwiftBuildModuleFailedRule: DiagnosticRule {
    private let moduleFailedRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^error: emit-module command failed with exit code (\d+)(.*)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard let match = moduleFailedRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let exitCodeRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let exitCode = String(line[exitCodeRange])
        let additionalInfo = if match.range(at: 2).location != NSNotFound,
                                let additionalRange = Range(match.range(at: 2), in: line)
        {
            String(line[additionalRange])
        } else {
            ""
        }

        let message = "Module compilation failed with exit code \(exitCode)\(additionalInfo)"

        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .error,
            message: message,
            relatedMessages: [],
            source: "swift-build",
            category: "module_failed",
            raw: line,
            buildTarget: nil
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "module_failed" else { return false }

        // Module failure information is usually single-line, but may contain hints
        if line.hasPrefix(" "), line.contains("use -v to see invocation") {
            return true
        }

        return false
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "module_failed" else { return false }

        // End when encountering specific compilation errors
        if line.contains(":"), line.contains(": error:") || line.contains(": warning:") {
            return true
        }

        // End when encountering empty lines
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }

        return false
    }
}
