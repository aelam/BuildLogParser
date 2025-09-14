import Foundation

// MARK: - Swift Compilation Task Failed Rule

// Parse Swift compilation task failure messages in xcodebuild
// Match format: SwiftCompile normal arm64 /path/to/file.swift (in target '...' from project '...')

public struct SwiftCompileTaskFailedRule: DiagnosticRule {
    private let swiftCompileFailedRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\s*SwiftCompile normal (\w+) (.+) \(in target '(.+)' from project '(.+)'\)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard
            let match = swiftCompileFailedRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let archRange = Range(match.range(at: 1), in: line),
            let filesRange = Range(match.range(at: 2), in: line),
            let targetRange = Range(match.range(at: 3), in: line),
            let projectRange = Range(match.range(at: 4), in: line)
        else {
            return nil
        }

        let arch = String(line[archRange])
        let files = String(line[filesRange])
        let target = String(line[targetRange])
        let project = String(line[projectRange])

        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .error,
            message: "Swift compilation task failed for \(arch): \(files)",
            relatedMessages: [],
            source: "xcodebuild",
            category: "swift_compilation_task_failed",
            raw: line,
            buildTarget: "\(target) (\(project))"
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "swift_compilation_task_failed" else { return false }
        return false // Swift compilation task failures are typically single line
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "swift_compilation_task_failed" else { return false }
        return line.trimmingCharacters(in: .whitespaces).isEmpty ||
            line.hasPrefix("** BUILD FAILED **") ||
            line.hasPrefix("---")
    }
}
