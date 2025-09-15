//
//  CompileErrorRule.swift (CompilerErrorRule)
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

// Generic compiler error rule - supports Swift, Objective-C, C/C++
// Matches format: file.ext:line:column: error/warning: message
public struct CompileErrorRule: DiagnosticRule {
    private let source: String
    private let categoryPrefix: String

    public init(source: String = "compiler", categoryPrefix: String = "") {
        self.source = source
        self.categoryPrefix = categoryPrefix
    }

    private let startRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^(.*\.(swift|m|mm|c|cpp|h|hpp)):(\d+):(\d+): (error|warning): (.*)$"#
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public func fastFail(line: String) -> Bool {
        // Quick checks to avoid regex if line definitely won't match
        // Must contain ":" and either "error:" or "warning:"
        line.contains(":") && (line.contains("error:") || line.contains("warning:"))
    }

    public func matchStart(line: String) -> Diagnostic? {
        guard let match = startRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        // Safely extract matched groups
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

        // Safely convert numbers
        guard
            let lineNum = Int(line[lineNumRange]),
            let colNum = Int(line[colNumRange])
        else {
            return nil
        }

        let severity: Diagnostic.Severity = (severityStr == "error" ? .error : .warning)

        let category = categoryPrefix.isEmpty ? severityStr : "\(categoryPrefix)_\(severityStr)"

        return Diagnostic(
            file: file,
            line: lineNum,
            column: colNum,
            severity: severity,
            message: message,
            relatedMessages: [],
            source: source,
            category: category,
            raw: line,
            buildTarget: nil
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current != nil else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Accept continuation lines:
        // - note: messages
        // - lines with caret indicators (^)
        // - source code lines (anything that's not a new diagnostic or build command)
        if trimmed.hasPrefix("note:") || trimmed.hasPrefix("^") {
            return true
        }

        // Don't accept build commands or new compilation units as continuation
        if trimmed.hasPrefix("SwiftCompile") ||
            trimmed.hasPrefix("cd ") ||
            trimmed.hasPrefix("** BUILD") ||
            trimmed.hasPrefix("---")
        {
            return false
        }

        // Don't accept lines that look like new diagnostics
        if fastFail(line: line) {
            return false
        }

        // Accept other lines as potential source code context
        return !trimmed.isEmpty
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current != nil else { return true }
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // End diagnostic when we encounter:
        // - Empty line (traditional separator)
        // - New compilation unit (SwiftCompile, etc.)
        // - Build commands (cd, etc.)
        // - Build status messages
        return trimmed.isEmpty ||
            trimmed.hasPrefix("SwiftCompile") ||
            trimmed.hasPrefix("cd ") ||
            trimmed.hasPrefix("** BUILD") ||
            trimmed.hasPrefix("---")
        // Removed fastFail check - let the parser handle new diagnostics
    }
}
