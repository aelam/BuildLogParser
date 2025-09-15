//
//  LinkerErrorRule.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

public struct LinkerErrorRule: DiagnosticRule {
    public init() {}

    public func fastFail(line: String) -> Bool {
        // Quick check for linker-related keywords
        line.contains("Undefined symbols") || line.contains("linker") || line.contains("ld:")
    }

    public func matchStart(line: String) -> Diagnostic? {
        guard line.hasPrefix("Undefined symbols for architecture") else {
            return nil
        }
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
            buildTarget: nil
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        current != nil && (line.hasPrefix("  ") || line.hasPrefix("ld:") || line.hasPrefix("clang:"))
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        line.hasPrefix("clang: error: linker command failed")
    }
}
