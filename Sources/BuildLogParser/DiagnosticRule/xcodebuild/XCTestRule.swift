//
//  XCTestRule.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

public struct XCTestRule: DiagnosticRule {
    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard line.hasPrefix("Test Case") else { return nil }
        let severity: Diagnostic.Severity = line.contains("failed") ? .error : .info
        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: severity,
            message: line,
            relatedMessages: [],
            source: "xctest",
            category: line.contains("failed") ? "test_failure" : "test_info",
            raw: line,
            buildTarget: nil,
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool { false }
    public func isEnd(line: String, current: Diagnostic?) -> Bool { false }
}
