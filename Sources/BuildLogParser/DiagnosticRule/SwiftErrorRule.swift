//
//  SwiftErrorRule.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

public struct SwiftErrorRule: DiagnosticRule {
    public init() {}

    private let startRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^(.*\.(swift|m|mm|c|cpp|h|hpp)):(\d+):(\d+): (error|warning): (.*)$"#,
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

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
            source: "swift",
            category: severityStr,
            raw: line,
            buildTarget: nil,
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current != nil else { return false }
        return line.hasPrefix("note:") || line.trimmingCharacters(in: .whitespaces).hasPrefix("^")
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
