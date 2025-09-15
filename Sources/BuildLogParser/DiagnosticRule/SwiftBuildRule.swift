import Foundation

// MARK: - Composite Swift Build Rule

// Composite rule containing all swift build related sub-rules

public struct SwiftBuildRule: DiagnosticRule {
    private let subRules: [DiagnosticRule]

    public init(includeCommonRules: Bool = true) {
        var rules: [DiagnosticRule] = []

        // 可选择性包含通用编译错误规则
        if includeCommonRules {
            rules.append(CompileErrorRule(source: "swift", categoryPrefix: "compile"))
        }

        rules += [
            SwiftBuildCompileErrorRule(), // Swift build 特定的编译错误
            SwiftBuildModuleFailedRule(), // Swift Build module failure
            SwiftBuildProgressRule(), // Swift Build progress information
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
        for subRule in subRules where subRule.isEnd(line: line, current: current) {
            return true
        }
        return true // Default to end
    }
}
