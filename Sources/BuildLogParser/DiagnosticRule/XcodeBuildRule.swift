//
//  XcodeBuildRule.swift
//  BuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

// MARK: - Composite XcodeBuildRule

public struct XcodeBuildRule: DiagnosticRule {
    private let subRules: [DiagnosticRule]

    public init() {
        subRules = [
            BuildFailedRule(),
            XcodebuildWarningRule(),
            SwiftCompileFailedRule(),
            BuildCommandFailedRule(),
            LinkerErrorRule(),
            XCTestRule(),
        ]
    }

    public func matchStart(line: String) -> Diagnostic? {
        for subRule in subRules {
            if let diagnostic = subRule.matchStart(line: line) {
                return diagnostic
            }
        }
        return nil
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        for subRule in subRules where subRule.matchContinuation(line: line, current: current) {
            return true
        }
        return false
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        for subRule in subRules where subRule.isEnd(line: line, current: current) {
            return true
        }
        return true // 默认结束
    }
}
