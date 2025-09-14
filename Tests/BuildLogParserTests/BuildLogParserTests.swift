@testable import BuildLogParser
import Foundation
import Testing

struct BuildLogParserTests {
    @Test
    func batchProcessing() async throws {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            LinkerErrorRule(),
            XCTestRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "Undefined symbols for architecture x86_64:",
            "  \"_foo\", referenced from:",
            "clang: error: linker command failed",
        ]

        let input = StringArrayInput(logLines)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let diagnostics = collectingOutput.getAllDiagnostics()

        #expect(!diagnostics.isEmpty, "Should parse at least one diagnostic")
        print("Total diagnostics: \(diagnostics.count)")
    }

    @Test
    func streamProcessing() async throws {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            LinkerErrorRule(),
            XCTestRule()
        ]

        let parser = DiagnosticsParser(rules: rules)
        var receivedDiagnostics: [Diagnostic] = []

        // Setup real-time processor
        let output = CallbackOutput { diagnostic in
            receivedDiagnostics.append(diagnostic)
            print("🔍 Real-time diagnostic found: \(diagnostic.severity) - \(diagnostic.message)")

            // Handle different severity levels
            switch diagnostic.severity {
            case .error:
                print("❌ Error: \(diagnostic.file ?? "unknown"):\(diagnostic.line ?? 0)")
            case .warning:
                print("⚠️  Warning: \(diagnostic.message)")
            case .info:
                print("ℹ️  Info: \(diagnostic.message)")
            case .note:
                print("📝 Note: \(diagnostic.message)")
            }
        }

        parser.addOutput(output)

        // Simulate streaming input
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "main.swift:15:3: warning: variable 'bar' was never used",
            "Undefined symbols for architecture x86_64:",
            "  \"_foo\", referenced from:",
            "clang: error: linker command failed",
        ]

        let input = StringArrayInput(logLines)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let allDiagnostics = collectingOutput.getAllDiagnostics()

        #expect(!allDiagnostics.isEmpty, "Should parse at least one diagnostic")
        #expect(receivedDiagnostics.count == allDiagnostics.count, "Output should receive all diagnostics")
        print("✅ Processing completed, total: \(allDiagnostics.count) diagnostics")
    }

    @Test
    func filteredStreamProcessing() async throws {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            LinkerErrorRule(),
            XCTestRule()
        ]

        let parser = DiagnosticsParser(rules: rules)
        var errorDiagnostics: [Diagnostic] = []

        // Only focus on error-level diagnostics
        let output = CallbackOutput { diagnostic in
            guard diagnostic.severity == .error else { return }

            errorDiagnostics.append(diagnostic)
            print("🚨 Critical error: \(diagnostic.message)")
            if let file = diagnostic.file, let line = diagnostic.line {
                print("📍 Location: \(file):\(line)")
            }

            // Can immediately notify developer or interrupt build
            notifyDeveloper(diagnostic)
        }

        parser.addOutput(output)

        // Simulate logs containing errors and warnings
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "main.swift:15:3: warning: variable 'bar' was never used",
            "Undefined symbols for architecture x86_64:",
            "  \"_foo\", referenced from:",
            "clang: error: linker command failed",
        ]

        let input = StringArrayInput(logLines)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let allDiagnostics = collectingOutput.getAllDiagnostics()
        let actualErrors = allDiagnostics.filter { $0.severity == .error }

        #expect(errorDiagnostics.count == actualErrors.count, "Filtered error count should match")
        #expect(!errorDiagnostics.isEmpty, "Should have at least one error")
    }

    private func notifyDeveloper(_ diagnostic: Diagnostic) {
        // Send notifications, emails, etc.
        print("📧 Notified developer about error: \(diagnostic.message)")
    }

    @Test
    func multipleInputTypes() async throws {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            LinkerErrorRule(),
            XCTestRule()
        ]

        // Test string array input
        let parser1 = DiagnosticsParser(rules: rules)
        let logLines = [
            "main.swift:10:5: error: use of unresolved identifier 'foo'",
            "main.swift:15:3: warning: variable 'bar' was never used",
        ]
        let input1 = StringArrayInput(logLines)
        let collectingOutput1 = CollectingOutput()
        parser1.addOutput(collectingOutput1)
        _ = try parser1.parse(input: input1)
        let result1 = collectingOutput1.getAllDiagnostics()
        #expect(result1.count >= 1, "String array input should parse diagnostics")

        // Test text string input
        let parser2 = DiagnosticsParser(rules: rules)
        let logText = """
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        """
        let input2 = StringInput(logText)
        let collectingOutput2 = CollectingOutput()
        parser2.addOutput(collectingOutput2)
        _ = try parser2.parse(input: input2)
        let result2 = collectingOutput2.getAllDiagnostics()
        #expect(result2.count >= 1, "Text string input should parse diagnostics")

        // Test Data input
        let parser3 = DiagnosticsParser(rules: rules)
        let logData = logText.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
        let input3 = DataInput(logData)
        let collectingOutput3 = CollectingOutput()
        parser3.addOutput(collectingOutput3)
        _ = try parser3.parse(input: input3)
        let result3 = collectingOutput3.getAllDiagnostics()
        #expect(result3.count >= 1, "Data input should parse diagnostics")

        // Verify that all three methods produce consistent results
        #expect(result1.count == result2.count, "Different input methods should produce same diagnostic count")
        #expect(result2.count == result3.count, "Different input methods should produce same diagnostic count")
    }

    @Test
    func asyncInputProcessing() async throws {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            LinkerErrorRule(),
            XCTestRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)
        var receivedDiagnostics: [Diagnostic] = []

        let output = CallbackOutput { diagnostic in
            receivedDiagnostics.append(diagnostic)
        }
        parser.addOutput(output)

        // Test asynchronous streaming processing
        let logText = """
        main.swift:10:5: error: use of unresolved identifier 'foo'
        Undefined symbols for architecture x86_64:
          "_foo", referenced from:
        clang: error: linker command failed
        """

        let input = StringInput(logText)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)
        _ = try parser.parse(input: input)
        let allDiagnostics = collectingOutput.getAllDiagnostics()

        #expect(receivedDiagnostics.count == allDiagnostics.count, "Async processing should receive all diagnostics")
        #expect(allDiagnostics.isEmpty == false, "Should parse diagnostics")
    }

    @Test
    func swiftBuildErrorTest() async throws {
        print("\n🔍 Testing decomposed SwiftBuildRule parsing capability\n")

        let swiftBuildRule = SwiftBuildRule()
        let parser = DiagnosticsParser(rules: [swiftBuildRule])

        // Simulate real swift build error output
        let swiftBuildOutput = """
        [1/1] Planning build
        Building for debugging...
        error: emit-module command failed with exit code 1 (use -v to see invocation)
        /Users/test/TestError.swift:5:1: error: expressions are not allowed at the top level
        3 | // Intentionally create compilation error
        4 | let test = undefinedVariable
        5 | print("Hello")
          | `- error: expressions are not allowed at the top level

        /Users/test/TestError.swift:4:12: error: cannot find 'undefinedVariable' in scope
        2 |
        3 | // Intentionally create compilation error
        4 | let test = undefinedVariable
          |            `- error: cannot find 'undefinedVariable' in scope
        5 | print("Hello")

        [4/4] Compiling TestProject TestError.swift
        """

        let output = CollectingOutput()
        parser.addOutput(output)

        let input = StringInput(swiftBuildOutput)
        _ = try parser.parse(input: input)

        let diagnostics = output.getAllDiagnostics()

        print("📊 Swift Build decomposed rule parsing results:")
        print("Total diagnostics: \(diagnostics.count)")

        // Group by category for display
        let byCategory = Dictionary(grouping: diagnostics) { $0.category ?? "unknown" }
        for (category, diags) in byCategory.sorted(by: { $0.key < $1.key }) {
            print("  \(category): \(diags.count) items")
        }

        for (index, diagnostic) in diagnostics.enumerated() {
            let location = diagnostic.file.map { "\($0):\(diagnostic.line ?? 0):\(diagnostic.column ?? 0)" } ?? "N/A"
            print("[\(index + 1)] \(diagnostic.severity) (\(diagnostic.category ?? "unknown")) at \(location)")
            print("    Message: \(diagnostic.message)")
        }

        // Verify parsing results
        #expect(diagnostics.count >= 3, "Should parse at least 3 diagnostic messages")

        let swiftBuildDiagnostics = diagnostics.filter { $0.source == "swift-build" }
        #expect(swiftBuildDiagnostics.count >= 2, "Should have at least 2 swift-build source diagnostics")

        // Verify module failure errors
        let moduleErrors = diagnostics.filter { $0.category == "module_failed" }
        #expect(moduleErrors.count == 1, "Should have 1 module failure error")

        // Verify compilation errors
        let compileErrors = diagnostics.filter { $0.category?.hasPrefix("compile_") == true }
        #expect(compileErrors.count == 2, "Should have 2 compilation errors")

        // Verify progress information
        let progressInfo = diagnostics.filter { $0.category == "progress" }
        #expect(progressInfo.count >= 1, "Should have at least 1 progress info")

        print("\n✅ Swift Build decomposed rule parsing test passed")
        print("   - Module failures: \(moduleErrors.count) items")
        print("   - Compilation errors: \(compileErrors.count) items")
        print("   - Progress info: \(progressInfo.count) items")
    }
}
