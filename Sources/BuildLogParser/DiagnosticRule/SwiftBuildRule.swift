import Foundation

// MARK: - Composite Swift Build Rule

// Composite rule containing all swift build related sub-rules

public struct SwiftBuildRule: DiagnosticRule {
    private let subRules: [DiagnosticRule]

    public init() {
        subRules = [
            CompileErrorRule(source: "swift", categoryPrefix: "compile"),
            // Generic compiler error rule with swift-build source
            SwiftBuildModuleFailedRule(), // Swift Build module failure
            SwiftBuildProgressRule(), // Swift Build progress information
        ]
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
