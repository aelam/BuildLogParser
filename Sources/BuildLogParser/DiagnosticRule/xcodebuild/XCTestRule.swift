//
//  XCTestRule.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

public struct XCTestRule: DiagnosticRule {
    public init() {}

    public func fastFail(line: String) -> Bool {
        line.hasPrefix("Test Case") ||
            line.hasPrefix("Test Suite") ||
            line.contains("failed") ||
            line.contains("passed") ||
            line.contains("XCTAssert") ||
            line.contains("error:") && line.contains("test")
    }

    public func matchStart(line: String) -> Diagnostic? {
        // Test Case results
        if line.hasPrefix("Test Case") {
            return parseTestCase(line)
        }

        // Test Suite results
        if line.hasPrefix("Test Suite") {
            return parseTestSuite(line)
        }

        // XCTest assertion failures
        if line.contains("XCTAssert"), line.contains("failed") {
            return parseAssertionFailure(line)
        }

        // Generic test failures
        if line.contains("error:"), line.contains("test") {
            return parseTestError(line)
        }

        return nil
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard let current else { return false }

        // Continuation lines for test failures often contain more details
        return (current.category?.contains("test") ?? false) &&
            (line.hasPrefix("    ") || // Indented details
                line.contains("XCTAssert") ||
                line.contains("Expected:") ||
                line.contains("Actual:") ||
                line.contains("Difference:")
            )
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard let current else { return false }

        // End when we hit another test case or test suite
        return (current.category?.contains("test") ?? false) &&
            (line.hasPrefix("Test Case") || line.hasPrefix("Test Suite"))
    }

    // MARK: - Private Parsing Methods

    private func parseTestCase(_ line: String) -> Diagnostic? {
        // Parse: "Test Case '-[MyTests testMethod]' started."
        // Parse: "Test Case '-[MyTests testMethod]' passed (0.001 seconds)."
        // Parse: "Test Case '-[MyTests testMethod]' failed (0.001 seconds)."

        let severity: Diagnostic.Severity
        let category: String

        if line.contains("failed") {
            severity = .error
            category = "test_failure"
        } else if line.contains("passed") {
            severity = .info
            category = "test_success"
        } else if line.contains("started") {
            severity = .info
            category = "test_start"
        } else {
            severity = .info
            category = "test_info"
        }

        // Extract test method name
        let testName = extractTestName(from: line) ?? "Unknown Test"

        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: severity,
            message: "Test: \(testName) - \(extractStatus(from: line))",
            relatedMessages: [],
            source: "xctest",
            category: category,
            raw: line,
            buildTarget: extractTestTarget(from: line)
        )
    }

    private func parseTestSuite(_ line: String) -> Diagnostic? {
        // Parse: "Test Suite 'MyTests' started at 2023-01-01 12:00:00.000"
        // Parse: "Test Suite 'MyTests' passed at 2023-01-01 12:00:00.000."
        // Parse: "Test Suite 'MyTests' failed at 2023-01-01 12:00:00.000."

        let severity: Diagnostic.Severity
        let category: String

        if line.contains("failed") {
            severity = .error
            category = "test_suite_failure"
        } else if line.contains("passed") {
            severity = .info
            category = "test_suite_success"
        } else if line.contains("started") {
            severity = .info
            category = "test_suite_start"
        } else {
            severity = .info
            category = "test_suite_info"
        }

        let suiteName = extractSuiteName(from: line) ?? "Unknown Suite"

        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: severity,
            message: "Test Suite: \(suiteName) - \(extractStatus(from: line))",
            relatedMessages: [],
            source: "xctest",
            category: category,
            raw: line,
            buildTarget: suiteName
        )
    }

    private func parseAssertionFailure(_ line: String) -> Diagnostic? {
        // Parse XCTest assertion failures
        // "/path/to/test/MyTests.swift:25: error: -[MyTests testMethod] : XCTAssertEqual failed: (\"expected\") is not equal to (\"actual\")"

        let fileInfo = extractFileInfo(from: line)

        return Diagnostic(
            file: fileInfo.file,
            line: fileInfo.line,
            column: nil,
            severity: .error,
            message: extractAssertionMessage(from: line),
            relatedMessages: [],
            source: "xctest",
            category: "assertion_failure",
            raw: line,
            buildTarget: extractTestTarget(from: line)
        )
    }

    private func parseTestError(_ line: String) -> Diagnostic? {
        let fileInfo = extractFileInfo(from: line)

        return Diagnostic(
            file: fileInfo.file,
            line: fileInfo.line,
            column: nil,
            severity: .error,
            message: extractErrorMessage(from: line),
            relatedMessages: [],
            source: "xctest",
            category: "test_error",
            raw: line,
            buildTarget: nil
        )
    }

    // MARK: - Helper Methods

    private func extractTestName(from line: String) -> String? {
        // Extract from: "Test Case '-[MyTests testMethod]' ..."
        let pattern = #"-\[([^\]]+)\]"#
        return extractMatch(pattern: pattern, from: line, group: 1)
    }

    private func extractSuiteName(from line: String) -> String? {
        // Extract from: "Test Suite 'MyTests' ..."
        let pattern = #"Test Suite '([^']+)'"#
        return extractMatch(pattern: pattern, from: line, group: 1)
    }

    private func extractStatus(from line: String) -> String {
        if line.contains("failed") { return "Failed" }
        if line.contains("passed") { return "Passed" }
        if line.contains("started") { return "Started" }
        return "Info"
    }

    private func extractTestTarget(from line: String) -> String? {
        // Try to extract test class name from test method
        if let testName = extractTestName(from: line) {
            let components = testName.components(separatedBy: " ")
            return components.first
        }
        return nil
    }

    private func extractFileInfo(from line: String) -> (file: String?, line: Int?) {
        // Parse: "/path/to/file.swift:25: error: ..."
        let pattern = #"([^:]+):(\d+):"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else {
            return (nil, nil)
        }

        guard let fileRange = Range(match.range(at: 1), in: line),
              let lineRange = Range(match.range(at: 2), in: line)
        else {
            return (nil, nil)
        }

        let filePath = String(line[fileRange])
        let lineNumber = Int(String(line[lineRange]))

        return (filePath, lineNumber)
    }

    private func extractAssertionMessage(from line: String) -> String {
        // Extract the XCTAssert message after the method name
        if let range = line.range(of: "XCTAssert") {
            return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private func extractErrorMessage(from line: String) -> String {
        // Extract error message after "error:"
        if let range = line.range(of: "error:") {
            let startIndex = line.index(range.upperBound, offsetBy: 1, limitedBy: line.endIndex) ?? range.upperBound
            return String(line[startIndex...]).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private func extractMatch(pattern: String, from line: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > group
        else {
            return nil
        }

        let range = match.range(at: group)
        guard let swiftRange = Range(range, in: line) else { return nil }
        return String(line[swiftRange])
    }
}
