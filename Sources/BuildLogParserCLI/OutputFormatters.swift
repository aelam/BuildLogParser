//
//  OutputFormatters.swift
//  BuildLogParserCLI
//
//  Created by CLI Generator on 2025/09/15.
//

import BuildLogParser
import Foundation

// MARK: - Text Output

class TextOutput: DiagnosticOutput {
    private let outputPath: String
    private let verbose: Bool
    private let errorsOnly: Bool
    private let fileHandle: FileHandle?

    init(outputPath: String, verbose: Bool, errorsOnly: Bool) {
        self.outputPath = outputPath
        self.verbose = verbose
        self.errorsOnly = errorsOnly

        if outputPath == "-" {
            fileHandle = FileHandle.standardOutput
        } else {
            FileManager.default.createFile(atPath: outputPath, contents: nil)
            fileHandle = FileHandle(forWritingAtPath: outputPath)
        }
    }

    func write(_ diagnostic: Diagnostic) {
        if errorsOnly, diagnostic.severity != .error {
            return
        }

        let severity = diagnostic.severity
        let icon = switch severity {
        case .error: "❌"
        case .warning: "⚠️"
        case .info: "ℹ️"
        case .note: "📝"
        }

        var output = ""

        if let file = diagnostic.file, let line = diagnostic.line {
            output = "\(icon) \(file):\(line): \(severity) - \(diagnostic.message)\n"
        } else {
            output = "\(icon) \(severity) - \(diagnostic.message)\n"
        }

        if verbose, !diagnostic.relatedMessages.isEmpty {
            for relatedMessage in diagnostic.relatedMessages {
                output += "    📎 \(relatedMessage)\n"
            }
        }

        if let data = output.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    func finish() {
        let message = "✅ Parsing completed\n"
        if let data = message.data(using: .utf8) {
            fileHandle?.write(data)
        }

        if outputPath != "-" {
            fileHandle?.closeFile()
        }
    }
}

// MARK: - JSON Output

class JSONOutput: DiagnosticOutput {
    private let outputPath: String
    private let verbose: Bool
    private let errorsOnly: Bool
    private let fileHandle: FileHandle?
    private var diagnostics: [Diagnostic] = []

    init(outputPath: String, verbose: Bool, errorsOnly: Bool) {
        self.outputPath = outputPath
        self.verbose = verbose
        self.errorsOnly = errorsOnly

        if outputPath == "-" {
            fileHandle = FileHandle.standardOutput
        } else {
            FileManager.default.createFile(atPath: outputPath, contents: nil)
            fileHandle = FileHandle(forWritingAtPath: outputPath)
        }
    }

    func write(_ diagnostic: Diagnostic) {
        if errorsOnly, diagnostic.severity != .error {
            return
        }
        diagnostics.append(diagnostic)
    }

    func finish() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let output = DiagnosticOutputJSON(
            diagnostics: diagnostics,
            metadata: DiagnosticMetadata(
                totalCount: diagnostics.count,
                errorCount: diagnostics.count(where: { $0.severity == .error }),
                warningCount: diagnostics.count(where: { $0.severity == .warning }),
                infoCount: diagnostics.count(where: { $0.severity == .info }),
                noteCount: diagnostics.count(where: { $0.severity == .note }),
                timestamp: Date(),
                verbose: verbose
            )
        )

        do {
            let jsonData = try encoder.encode(output)
            fileHandle?.write(jsonData)
        } catch {
            let errorMessage = "Error encoding JSON: \(error.localizedDescription)\n"
            if let data = errorMessage.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
        }

        if outputPath != "-" {
            fileHandle?.closeFile()
        }
    }
}

// MARK: - Summary Output

class SummaryOutput: DiagnosticOutput {
    private let outputPath: String
    private let verbose: Bool
    private let errorsOnly: Bool
    private let fileHandle: FileHandle?
    private var diagnostics: [Diagnostic] = []

    init(outputPath: String, verbose: Bool, errorsOnly: Bool) {
        self.outputPath = outputPath
        self.verbose = verbose
        self.errorsOnly = errorsOnly

        if outputPath == "-" {
            fileHandle = FileHandle.standardOutput
        } else {
            FileManager.default.createFile(atPath: outputPath, contents: nil)
            fileHandle = FileHandle(forWritingAtPath: outputPath)
        }
    }

    func write(_ diagnostic: Diagnostic) {
        if errorsOnly, diagnostic.severity != .error {
            return
        }
        diagnostics.append(diagnostic)
    }

    func finish() {
        let output = generateSummaryOutput()

        if let data = output.data(using: .utf8) {
            fileHandle?.write(data)
        }

        if outputPath != "-" {
            fileHandle?.closeFile()
        }
    }

    private func generateSummaryOutput() -> String {
        let counts = calculateCounts()

        var output = """
        📊 Build Log Analysis Summary
        ═══════════════════════════════════════════════════════════════

        Total Issues Found: \(diagnostics.count)

        """

        output += formatCounts(counts)

        if diagnostics.isEmpty {
            output += "\n🎉 No issues found! Build log looks clean.\n"
        } else if verbose {
            output += generateFileBreakdown()
        }

        output += "\n✅ Analysis completed\n"
        return output
    }

    private func calculateCounts() -> DiagnosticCounts {
        let errorCount = diagnostics.count(where: { $0.severity == .error })
        let warningCount = diagnostics.count(where: { $0.severity == .warning })
        let infoCount = diagnostics.count(where: { $0.severity == .info })
        let noteCount = diagnostics.count(where: { $0.severity == .note })
        return DiagnosticCounts(errors: errorCount, warnings: warningCount, info: infoCount, notes: noteCount)
    }

    private func formatCounts(_ counts: DiagnosticCounts) -> String {
        var result = ""
        if counts.errors > 0 {
            result += "❌ Errors: \(counts.errors)\n"
        }
        if counts.warnings > 0 {
            result += "⚠️  Warnings: \(counts.warnings)\n"
        }
        if counts.info > 0 {
            result += "ℹ️  Info: \(counts.info)\n"
        }
        if counts.notes > 0 {
            result += "📝 Notes: \(counts.notes)\n"
        }
        return result
    }

    private func generateFileBreakdown() -> String {
        var output = "\n📋 Issue Breakdown by File:\n"
        let fileGroups = Dictionary(grouping: diagnostics) { $0.file ?? "Unknown" }

        for (file, fileDiagnostics) in fileGroups.sorted(by: { $0.key < $1.key }) {
            let fileErrors = fileDiagnostics.count(where: { $0.severity == .error })
            let fileWarnings = fileDiagnostics.count(where: { $0.severity == .warning })

            output += "\n📄 \(file):\n"
            if fileErrors > 0 {
                output += "   ❌ \(fileErrors) error(s)\n"
            }
            if fileWarnings > 0 {
                output += "   ⚠️  \(fileWarnings) warning(s)\n"
            }
        }
        return output
    }
}

// MARK: - Statistics Collector

class StatsCollector: DiagnosticOutput {
    private var diagnostics: [Diagnostic] = []

    func write(_ diagnostic: Diagnostic) {
        diagnostics.append(diagnostic)
    }

    func finish() {
        // Statistics are printed separately via printStats()
    }

    func printStats() {
        let errorCount = diagnostics.count(where: { $0.severity == .error })
        let warningCount = diagnostics.count(where: { $0.severity == .warning })
        let infoCount = diagnostics.count(where: { $0.severity == .info })
        let noteCount = diagnostics.count(where: { $0.severity == .note })

        print("\n📈 Detailed Statistics:")
        print("═══════════════════════════════════════════════════════════════")
        print("Total diagnostics processed: \(diagnostics.count)")
        print("❌ Errors: \(errorCount)")
        print("⚠️  Warnings: \(warningCount)")
        print("ℹ️  Information: \(infoCount)")
        print("📝 Notes: \(noteCount)")

        // File distribution
        let fileGroups = Dictionary(grouping: diagnostics) { $0.file ?? "Unknown" }
        print("\n📁 Files affected: \(fileGroups.count)")

        // Most problematic files
        if fileGroups.count > 1 {
            let sortedFiles = fileGroups.sorted { $0.value.count > $1.value.count }
            print("\n🔥 Most issues by file:")
            for (file, fileDiagnostics) in sortedFiles.prefix(5) {
                print("   \(file): \(fileDiagnostics.count) issue(s)")
            }
        }

        // Severity distribution
        if !diagnostics.isEmpty {
            let totalCount = diagnostics.count
            print("\n📊 Severity distribution:")
            if errorCount > 0 {
                let percentage = Double(errorCount) / Double(totalCount) * 100
                print("   ❌ Errors: \(String(format: "%.1f", percentage))%")
            }
            if warningCount > 0 {
                let percentage = Double(warningCount) / Double(totalCount) * 100
                print("   ⚠️  Warnings: \(String(format: "%.1f", percentage))%")
            }
            if infoCount > 0 {
                let percentage = Double(infoCount) / Double(totalCount) * 100
                print("   ℹ️  Information: \(String(format: "%.1f", percentage))%")
            }
            if noteCount > 0 {
                let percentage = Double(noteCount) / Double(totalCount) * 100
                print("   📝 Notes: \(String(format: "%.1f", percentage))%")
            }
        }

        print("═══════════════════════════════════════════════════════════════")
    }
}

// MARK: - Supporting Types

struct DiagnosticCounts {
    let errors: Int
    let warnings: Int
    let info: Int
    let notes: Int
}

// MARK: - JSON Models

struct DiagnosticOutputJSON: Codable {
    let diagnostics: [DiagnosticJSON]
    let metadata: DiagnosticMetadata

    init(diagnostics: [Diagnostic], metadata: DiagnosticMetadata) {
        self.diagnostics = diagnostics.map(DiagnosticJSON.init)
        self.metadata = metadata
    }
}

struct DiagnosticJSON: Codable {
    let message: String
    let severity: String
    let file: String?
    let line: Int?
    let column: Int?
    let relatedMessages: [String]

    init(_ diagnostic: Diagnostic) {
        message = diagnostic.message
        severity = "\(diagnostic.severity)"
        file = diagnostic.file
        line = diagnostic.line
        column = diagnostic.column
        relatedMessages = diagnostic.relatedMessages
    }
}

struct DiagnosticMetadata: Codable {
    let totalCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let noteCount: Int
    let timestamp: Date
    let verbose: Bool
}
