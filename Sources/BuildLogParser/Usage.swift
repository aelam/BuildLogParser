//
//  Usage.swift
//  BuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

import Foundation

public class BuildLogParserUsage {
    public static func demonstrateInputs() {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule()
        ]

        let parser = DiagnosticsParser(rules: rules)

        // Add print output
        parser.addOutput(PrintOutput())

        // 1. String input
        let stringInput = StringInput("""
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        """)

        do {
            let collectingOutput = CollectingOutput()
            parser.addOutput(collectingOutput)
            try parser.parse(input: stringInput)
            let result1 = collectingOutput.getAllDiagnostics()
            print("String input parsing result: \(result1.count) diagnostics")
        } catch {
            print("Parsing error: \(error)")
        }
    }

    // Example 2: Using different output sources
    public static func demonstrateOutputs() {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // Add multiple output processors
        parser.addOutput(PrintOutput())

        // Add callback output (only process errors)
        let errorOnlyOutput = CallbackOutput(onDiagnostic: { diagnostic in
            if diagnostic.severity == .error {
                print("🚨 Critical error found: \(diagnostic.message)")
            }
        })
        parser.addOutput(errorOnlyOutput)

        // Add collecting output (for subsequent analysis)
        let collectingOutput = CollectingOutput()
        parser.addOutput(collectingOutput)

        let input = StringInput("""
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        """)

        do {
            _ = try parser.parse(input: input)
            print("Collected diagnostics: \(collectingOutput.getAllDiagnostics().count) items")
        } catch {
            print("Parsing error: \(error)")
        }
    }

    // Example 3: Processing multiple types of input sources
    public static func demonstrateMultipleInputs() {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // Combine content from multiple input sources
        let combinedInput = StringInput("""
        main.swift:10:5: error: use of unresolved identifier 'foo'
        main.swift:15:3: warning: variable 'bar' was never used
        Undefined symbols for architecture x86_64:
          "_foo", referenced from:
        clang: error: linker command failed
        """)

        do {
            let collectingOutput = CollectingOutput()
            parser.addOutput(collectingOutput)
            try parser.parse(input: combinedInput)
            let result = collectingOutput.getAllDiagnostics()
            print("Multi-type input parsing result: \(result.count) diagnostics")
        } catch {
            print("Parsing error: \(error)")
        }
    }

    // Example 4: Custom input and output
    public static func demonstrateCustomInputOutput() {
        // Custom input: reading from network stream
        struct NetworkInput: DiagnosticInput {
            let url: URL

            func readLines() throws -> AnySequence<String> {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    throw DiagnosticError.invalidEncoding
                }
                let lines = content.components(separatedBy: .newlines)
                return AnySequence(lines)
            }
        }

        // Custom output: writing to file
        class FileOutput: DiagnosticOutput {
            let url: URL
            private var content = ""

            init(url: URL) {
                self.url = url
            }

            func write(_ diagnostic: Diagnostic) {
                content += "\(diagnostic.severity): \(diagnostic.message)\n"
            }

            func finish() {
                try? content.write(to: url, atomically: true, encoding: .utf8)
                print("Diagnostic results written to: \(url.path)")
            }
        }

        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)

        // Use custom output
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("diagnostics.txt")
        let fileOutput = FileOutput(url: outputURL)
        parser.addOutput(fileOutput)

        // Simulation usage
        let input = StringInput("main.swift:10:5: error: use of unresolved identifier 'foo'")

        do {
            _ = try parser.parse(input: input)
        } catch {
            print("Parsing error: \(error)")
        }
    }

    // Example 5: Async streaming processing (macOS 10.15+)
    @available(macOS 10.15, *)
    public static func demonstrateAsyncStreaming() async {
        let rules: [DiagnosticRule] = [
            CompileErrorRule(),
            XcodeBuildRule(),
        ]

        let parser = DiagnosticsParser(rules: rules)
        parser.addOutput(PrintOutput())

        // Simulate creating a pipe for streaming input
        let pipe = Pipe()
        let writeHandle = pipe.fileHandleForWriting
        let readHandle = pipe.fileHandleForReading

        // Create async input
        let asyncInput = AsyncFileHandleInput(readHandle)

        // Write data in background
        Task {
            let logData = Data("""
            main.swift:10:5: error: use of unresolved identifier 'foo'
            main.swift:15:3: warning: variable 'bar' was never used
            Undefined symbols for architecture x86_64:
              "_foo", referenced from:
            clang: error: linker command failed
            """.utf8)

            writeHandle.write(logData)
            writeHandle.closeFile()
        }

        do {
            let collectingOutput = CollectingOutput()
            parser.addOutput(collectingOutput)
            try await parser.parse(input: asyncInput)
            let diagnostics = collectingOutput.getAllDiagnostics()
            print("Async streaming processing completed: \(diagnostics.count) diagnostics")
        } catch {
            print("Async processing error: \(error)")
        }
    }
}
