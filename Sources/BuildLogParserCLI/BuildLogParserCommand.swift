import ArgumentParser
import BuildLogParser
import Foundation

@available(macOS 10.15, *)
@main
struct BuildLogParserCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "buildlog-parser",
        abstract: "Parse Xcode build logs and extract diagnostics",
        version: "0.1.0",
        subcommands: [
            ParseCommand.self,
            ValidateCommand.self
        ],
        defaultSubcommand: ParseCommand.self
    )
}

@available(macOS 10.15, *)
struct ParseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "parse",
        abstract: "Parse build log files and extract diagnostics"
    )

    @Argument(help: "The build log file to parse. Use '-' for stdin.")
    var inputFile: String

    @Option(name: .shortAndLong, help: "Output file path. Use '-' for stdout.")
    var output: String = "-"

    @Option(help: "Output format: text, json, or summary")
    var format: OutputFormat = .text

    @Flag(help: "Include verbose diagnostic information")
    var verbose: Bool = false

    @Flag(help: "Only show errors (exclude warnings and info)")
    var errorsOnly: Bool = false

    @Flag(help: "Show statistics summary")
    var showStats: Bool = false

    @Flag(help: "Enable streaming output (output diagnostics as they are found)")
    var stream: Bool = false

    func run() async throws {
        // Create input source
        let input: DiagnosticInput
        if inputFile == "-" {
            input = FileHandleInput(FileHandle.standardInput)
        } else {
            let url = URL(fileURLWithPath: inputFile)
            guard FileManager.default.fileExists(atPath: inputFile) else {
                throw ValidationError("Input file not found: \(inputFile)")
            }
            input = FileInput(url)
        }

        // Create output destination
        let outputHandler: DiagnosticOutput = switch format {
        case .text:
            TextOutput(
                outputPath: output,
                verbose: verbose,
                errorsOnly: errorsOnly
            )
        case .json:
            if stream {
                StreamingJSONOutput(
                    outputPath: output,
                    verbose: verbose,
                    errorsOnly: errorsOnly
                )
            } else {
                JSONOutput(
                    outputPath: output,
                    verbose: verbose,
                    errorsOnly: errorsOnly
                )
            }
        case .summary:
            SummaryOutput(
                outputPath: output,
                verbose: verbose,
                errorsOnly: errorsOnly
            )
        }

        // Create parser with organized rule sets
        let rules: [DiagnosticRule] = [
            CompileErrorRule(source: "compiler"),

            // Composite rules without common rules to avoid conflicts
            XcodeBuildRule(includeCommonRules: false), // Xcode build specific diagnostics
            SwiftBuildRule(includeCommonRules: false), // Swift build specific diagnostics
        ]

        let parser = DiagnosticsParser(rules: rules)
        parser.addOutput(outputHandler)

        // Add statistics collection if requested
        let statsCollector = StatsCollector()
        if showStats {
            parser.addOutput(statsCollector)
        }

        // Parse the input
        do {
            try parser.parse(input: input)

            // Show statistics if requested
            if showStats {
                statsCollector.printStats()
            }

        } catch {
            throw RuntimeError("Failed to parse build log: \(error.localizedDescription)")
        }
    }
}

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate that a build log file is readable and well-formed"
    )

    @Argument(help: "The build log file to validate")
    var inputFile: String

    @Flag(help: "Show verbose validation output")
    var verbose: Bool = false

    func run() throws {
        let url = URL(fileURLWithPath: inputFile)
        guard FileManager.default.fileExists(atPath: inputFile) else {
            throw ValidationError("Input file not found: \(inputFile)")
        }

        do {
            let input = FileInput(url)
            let lines = try input.readLines()
            var lineCount = 0
            var byteCount = 0

            for line in lines {
                lineCount += 1
                byteCount += line.utf8.count + 1 // +1 for newline
            }

            if verbose {
                print("✅ File validation successful")
                print("📊 Statistics:")
                print("   • Lines: \(lineCount)")
                print("   • Size: \(ByteCountFormatter().string(fromByteCount: Int64(byteCount)))")
                print("   • Encoding: UTF-8")
            } else {
                print("✅ Valid build log file")
            }

        } catch {
            throw RuntimeError("File validation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Output Formats

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case json
    case summary

    var description: String {
        switch self {
        case .text: "Human-readable text format"
        case .json: "Structured JSON format"
        case .summary: "Brief summary with statistics"
        }
    }
}

// MARK: - Error Types

struct ValidationError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}

struct RuntimeError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}
