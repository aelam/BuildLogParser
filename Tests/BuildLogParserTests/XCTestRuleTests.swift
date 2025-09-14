//
//  XCTestRuleTests.swift
//  BuildLogParserTests
//
//  Created by wang.lun on 2025/09/14.
//

@testable import BuildLogParser
import Testing

@Suite("XCTestRule Tests")
struct XCTestRuleTests {
    let rule = XCTestRule()

    @Test("Test Case Started")
    func caseStarted() {
        let line = "Test Case '-[MyTests testExample]' started."
        let diagnostic = rule.matchStart(line: line)

        #expect(diagnostic != nil)
        #expect(diagnostic?.severity == .info)
        #expect(diagnostic?.category == "test_start")
        #expect(diagnostic?.source == "xctest")
        #expect(diagnostic?.message.contains("testExample") == true)
    }

    @Test("Test Case Passed")
    func casePassed() {
        let line = "Test Case '-[MyTests testExample]' passed (0.001 seconds)."
        let diagnostic = rule.matchStart(line: line)

        #expect(diagnostic != nil)
        #expect(diagnostic?.severity == .info)
        #expect(diagnostic?.category == "test_success")
        #expect(diagnostic?.source == "xctest")
    }

    @Test("Test Case Failed")
    func caseFailed() {
        let line = "Test Case '-[MyTests testExample]' failed (0.001 seconds)."
        let diagnostic = rule.matchStart(line: line)

        #expect(diagnostic != nil)
        #expect(diagnostic?.severity == .error)
        #expect(diagnostic?.category == "test_failure")
        #expect(diagnostic?.source == "xctest")
    }

    @Test("Test Suite Started")
    func suiteStarted() {
        let line = "Test Suite 'MyTests' started at 2023-01-01 12:00:00.000"
        let diagnostic = rule.matchStart(line: line)

        #expect(diagnostic != nil)
        #expect(diagnostic?.severity == .info)
        #expect(diagnostic?.category == "test_suite_start")
        #expect(diagnostic?.buildTarget == "MyTests")
    }

    @Test("Assertion Failure")
    func assertionFailure() {
        let line = "/Users/test/MyTests.swift:25: error: -[MyTests testExample] : XCTAssertEqual failed: (\"expected\") is not equal to (\"actual\")"
        let diagnostic = rule.matchStart(line: line)

        #expect(diagnostic != nil)
        #expect(diagnostic?.severity == .error)
        #expect(diagnostic?.category == "assertion_failure")
        #expect(diagnostic?.file == "/Users/test/MyTests.swift")
        #expect(diagnostic?.line == 25)
        #expect(diagnostic?.message.contains("XCTAssertEqual") == true)
    }

    @Test("Fast Fail Positive Cases")
    func fastFailPositive() {
        #expect(rule.fastFail(line: "Test Case '-[MyTests testExample]' started.") == true)
        #expect(rule.fastFail(line: "Test Suite 'MyTests' started") == true)
        #expect(rule.fastFail(line: "XCTAssertEqual failed") == true)
        #expect(rule.fastFail(line: "error: test failed") == true)
    }

    @Test("Fast Fail Negative Cases")
    func fastFailNegative() {
        #expect(rule.fastFail(line: "Compiling Swift source files") == false)
        #expect(rule.fastFail(line: "Build succeeded") == false)
        #expect(rule.fastFail(line: "Random log line") == false)
    }

    @Test("Continuation Lines")
    func continuationLines() {
        // 创建一个测试失败的 diagnostic
        let diagnostic = Diagnostic(
            file: "/test.swift",
            line: 10,
            column: nil,
            severity: .error,
            message: "Test failed",
            relatedMessages: [],
            source: "xctest",
            category: "test_failure",
            raw: "original line",
            buildTarget: nil
        )

        // 测试续行识别
        #expect(rule.matchContinuation(line: "    Expected: 42", current: diagnostic) == true)
        #expect(rule.matchContinuation(line: "    Actual: 24", current: diagnostic) == true)
        #expect(rule.matchContinuation(line: "XCTAssertEqual failed", current: diagnostic) == true)

        // 非续行
        #expect(rule.matchContinuation(line: "Test Case started", current: diagnostic) == false)
    }

    @Test("End Condition")
    func endCondition() {
        let diagnostic = Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .error,
            message: "Test failed",
            relatedMessages: [],
            source: "xctest",
            category: "test_failure",
            raw: "original line",
            buildTarget: nil
        )

        // 应该在新的测试案例或测试套件开始时结束
        #expect(rule.isEnd(line: "Test Case '-[NextTest testMethod]' started.", current: diagnostic) == true)
        #expect(rule.isEnd(line: "Test Suite 'NextSuite' started", current: diagnostic) == true)

        // 不应该在其他行结束
        #expect(rule.isEnd(line: "    Additional details", current: diagnostic) == false)
    }
}
