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

    public init(includeCommonRules: Bool = true) {
        var rules: [DiagnosticRule] = []

        if includeCommonRules {
            rules.append(CompileErrorRule(source: "xcodebuild"))
        }

        // xcodebuild rules
        rules += [
            BuildFailedRule(),
            XcodeBuildWarningRule(),
            SwiftCompileTaskFailedRule(),
            BuildCommandFailedRule(),
            LinkerErrorRule(),
            XCTestRule(),
        ]

        subRules = rules
    }

    public func fastFail(line: String) -> Bool {
        // Check if any sub-rule might match
        subRules.contains { $0.fastFail(line: line) }
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
        // Check if any sub-rule indicates this is an end
        for subRule in subRules where subRule.isEnd(line: line, current: current) {
            return true
        }
        return false // Let continuation continue unless explicitly ended
    }
}
