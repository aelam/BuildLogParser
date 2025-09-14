//
//  LinkerErrorRule.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

public struct LinkerErrorRule: DiagnosticRule {
    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        if line.hasPrefix("Undefined symbols for architecture") {
            return Diagnostic(
                file: nil,
                line: nil,
                column: nil,
                severity: .error,
                message: line,
                relatedMessages: [],
                source: "linker",
                category: "undefined_symbols",
                raw: line,
                buildTarget: nil,
            )
        }
        return nil
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        current != nil && (line.hasPrefix("  ") || line.hasPrefix("ld:") || line.hasPrefix("clang:"))
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        line.hasPrefix("clang: error: linker command failed")
    }
}
