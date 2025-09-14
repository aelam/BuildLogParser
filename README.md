# BuildLogParser

A Swift package for parsing Xcode and Swift build logs into structured diagnostic information. BuildLogParser can extract compilation errors, warnings, test failures, and other build issues from log files, making them easier to analyze programmatically.

## Features

- 🔍 **Multi-format Log Parsing**: Supports both `xcodebuild` and `swift build` log formats
- 📊 **Structured Output**: Parse logs into structured `Diagnostic` objects with file, line, severity, and message information
- 🧪 **Test Result Parsing**: Extract unit test results and failures using Swift Testing framework
- 🛠️ **Command Line Tool**: Built-in CLI for parsing logs from the command line
- 📝 **Multiple Output Formats**: Support for text, JSON, and summary output formats
- ⚡ **Performance Optimized**: Fast-fail optimization for efficient log processing
- 🔄 **Streaming Support**: Process large log files with streaming input/output
- 🌐 **Cross-platform**: Works on macOS and Linux

## Architecture

BuildLogParser follows a modular architecture with clear separation of concerns:

```mermaid
graph TB
    %% Input Sources
    subgraph "Input Sources"
        A1[File Input]
        A2[String Input]
        A3[FileHandle Input]
        A4[Stream Input]
    end

    %% Core Parser
    subgraph "Core Parser Engine"
        B1[DiagnosticsParser]
        B2[Rule Engine]
    end

    %% Diagnostic Rules
    subgraph "Diagnostic Rules"
        C1[CompileErrorRule]
        C2[SwiftCompileTaskFailedRule]
        C3[XcodeBuildWarningRule]
        C4[LinkerErrorRule]
        C5[XCTestRule]
        C6[SwiftBuildModuleFailedRule]
        C7[Custom Rules...]
    end

    %% Processing Flow
    subgraph "Processing Pipeline"
        D1[Line Processing]
        D2[Pattern Matching]
        D3[Multi-line Assembly]
        D4[Diagnostic Creation]
    end

    %% Output Handlers
    subgraph "Output Handlers"
        E1[TextOutput]
        E2[JSONOutput]
        E3[StreamingJSONOutput]
        E4[SummaryOutput]
        E5[CollectingOutput]
        E6[Custom Handlers...]
    end

    %% CLI Interface
    subgraph "Command Line Interface"
        F1[ArgumentParser]
        F2[Parse Command]
        F3[Validate Command]
    end

    %% Data Flow
    A1 --> B1
    A2 --> B1
    A3 --> B1
    A4 --> B1

    B1 --> B2
    B2 --> D1
    
    D1 --> D2
    D2 --> D3
    D3 --> D4

    C1 --> D2
    C2 --> D2
    C3 --> D2
    C4 --> D2
    C5 --> D2
    C6 --> D2
    C7 --> D2

    D4 --> E1
    D4 --> E2
    D4 --> E3
    D4 --> E4
    D4 --> E5
    D4 --> E6

    F1 --> F2
    F1 --> F3
    F2 --> B1
    F3 --> A1

    %% Styling
    classDef inputClass fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef coreClass fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef ruleClass fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef outputClass fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef cliClass fill:#fce4ec,stroke:#880e4f,stroke-width:2px

    class A1,A2,A3,A4 inputClass
    class B1,B2,D1,D2,D3,D4 coreClass
    class C1,C2,C3,C4,C5,C6,C7 ruleClass
    class E1,E2,E3,E4,E5,E6 outputClass
    class F1,F2,F3 cliClass
```

### Key Components:

- **Input Sources**: Multiple ways to provide log data (files, strings, streams)
- **Core Parser**: Central engine that orchestrates the parsing process
- **Diagnostic Rules**: Pluggable pattern matchers for different log formats
- **Processing Pipeline**: Multi-stage processing with line-by-line analysis
- **Output Handlers**: Flexible output formatting and destination options
- **CLI Interface**: Command-line tools for direct usage

### Diagnostic Processing Flow:

```mermaid
sequenceDiagram
    participant Input as Log Input
    participant Parser as DiagnosticsParser
    participant Rules as Diagnostic Rules
    participant Output as Output Handlers

    Note over Input,Output: Single Diagnostic Processing

    Input->>Parser: Raw log line
    Parser->>Rules: Check fastFail()
    
    alt Line matches pattern
        Rules-->>Parser: Returns true
        Parser->>Rules: Call matchStart()
        Rules-->>Parser: Returns Diagnostic
        Parser->>Parser: Set current diagnostic
    else Line is continuation
        Parser->>Rules: Call matchContinuation()
        Rules-->>Parser: Returns true/false
        alt Is continuation
            Parser->>Parser: Add to relatedMessages
        end
    else Line ends diagnostic
        Parser->>Rules: Call isEnd()
        Rules-->>Parser: Returns true
        Parser->>Output: Write diagnostic
        Output-->>Parser: Diagnostic processed
        Parser->>Parser: Clear current diagnostic
    end

    Note over Parser,Output: Multi-line Example
    Note over Input: "/path/file.swift:9:8: error: message"
    Note over Input: "import UIKitxx"  
    Note over Input: "       ^"
    Note over Output: Complete diagnostic with context
```

### Rule Processing Priority:

```mermaid
flowchart TD
    A[New Log Line] --> B{fastFail Check}
    B -->|Pass| C{matchStart?}
    B -->|Fail| D[Skip Line]
    
    C -->|Match| E[Create New Diagnostic]
    C -->|No Match| F{matchContinuation?}
    
    F -->|Yes| G[Add to relatedMessages]
    F -->|No| H{isEnd?}
    
    H -->|Yes| I[Flush Current Diagnostic]
    H -->|No| J[Process Next Line]
    
    E --> K[Set as Current Diagnostic]
    G --> J
    I --> L[Output to Handlers]
    K --> J
    L --> J
    
    style A fill:#e1f5fe
    style E fill:#c8e6c9
    style I fill:#ffcdd2
    style L fill:#fff3e0
```

## Installation

### Swift Package Manager

Add BuildLogParser to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aelam/BuildLogParser.git", from: "1.0.0")
]
```

### Command Line Tool

Build and install the CLI tool:

```bash
git clone https://github.com/aelam/BuildLogParser.git
cd BuildLogParser
swift build -c release
cp .build/release/buildlog-parser /usr/local/bin/
```

Or use Swift Package Manager directly:

```bash
swift package install buildlog-parser
```

## Quick Start

### Command Line Usage

Parse a build log file:

```bash
# Parse xcodebuild log
buildlog-parser parse build.log

# Parse with JSON output
buildlog-parser parse build.log --format json --output diagnostics.json

# Parse from stdin with summary
xcodebuild test | buildlog-parser parse - --format summary

# Show only errors
buildlog-parser parse build.log --errors-only

# Include statistics
buildlog-parser parse build.log --show-stats --format summary
```

### Programmatic Usage

```swift
import BuildLogParser

// Create parser with rules
let rules: [DiagnosticRule] = [
    SwiftBuildCompileErrorRule(),
    LinkerErrorRule(),
    XCTestRule()
]

let parser = DiagnosticsParser(rules: rules)

// Add output handler
parser.setDiagnosticHandler { diagnostic in
    print("Found \(diagnostic.severity): \(diagnostic.message)")
    if let file = diagnostic.file, let line = diagnostic.line {
        print("  at \(file):\(line)")
    }
}

// Parse from file
let input = FileInput(URL(fileURLWithPath: "build.log"))
try parser.parse(input: input)
```

## Supported Log Formats

### Build Errors and Warnings

BuildLogParser can extract diagnostics from various build tools:

- **Swift Compiler Errors**: Parse `swift build` compilation errors and warnings
- **Xcode Build Errors**: Extract diagnostics from `xcodebuild` output
- **Linker Errors**: Identify and parse linker error messages
- **Module Build Failures**: Parse Swift module compilation failures

### Test Results

- **XCTest Output**: Parse traditional XCTest results and failures
- **Swift Testing**: Extract results from Swift Testing framework output
- **Test Suites**: Organize test results by suite and individual test cases

## API Reference

### Core Classes

#### `DiagnosticsParser`

The main parser class that processes build logs using configurable rules.

```swift
public class DiagnosticsParser {
    public init(rules: [DiagnosticRule])
    public func addOutput(_ output: DiagnosticOutput)
    public func parse(input: DiagnosticInput) throws
    public func parse(input: AsyncDiagnosticInput) async throws // macOS 10.15+
}
```

#### `Diagnostic`

Represents a single diagnostic message (error, warning, etc.).

```swift
public struct Diagnostic {
    public let message: String
    public let severity: DiagnosticSeverity
    public let file: String?
    public let line: Int?
    public let column: Int?
    public var relatedMessages: [String]
}

public enum DiagnosticSeverity {
    case error, warning, info, note
}
```

### Input Sources

#### File Input
```swift
let input = FileInput(URL(fileURLWithPath: "build.log"))
try parser.parse(input: input)
```

#### String Input
```swift
let input = StringInput(logContent)
try parser.parse(input: input)
```

#### Streaming Input
```swift
let input = FileHandleInput(FileHandle.standardInput)
try parser.parse(input: input)
```

### Output Destinations

#### Callback Output
```swift
parser.setDiagnosticHandler { diagnostic in
    // Handle each diagnostic as it's parsed
    print("Found: \(diagnostic.message)")
}
```

#### Collecting Output
```swift
let collector = CollectingOutput()
parser.addOutput(collector)
try parser.parse(input: input)
let allDiagnostics = collector.getAllDiagnostics()
```

#### Print Output
```swift
let printOutput = PrintOutput()
parser.addOutput(printOutput)
```

### Custom Rules

Create custom diagnostic rules by implementing `DiagnosticRule`:

```swift
struct CustomRule: DiagnosticRule {
    func fastFail(line: String) -> Bool {
        // Quick check to avoid expensive regex
        return line.contains("MY_ERROR:")
    }
    
    func matchStart(line: String) -> Diagnostic? {
        // Parse the start of a diagnostic
        if line.hasPrefix("MY_ERROR:") {
            return Diagnostic(
                message: String(line.dropFirst("MY_ERROR:".count)),
                severity: .error,
                file: nil,
                line: nil,
                column: nil
            )
        }
        return nil
    }
    
    func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        // Check if this line continues the current diagnostic
        return line.hasPrefix("    ")
    }
    
    func isEnd(line: String, current: Diagnostic?) -> Bool {
        // Check if this line ends the current diagnostic
        return !line.hasPrefix("    ")
    }
}
```

## Command Line Interface

### Commands

#### `parse`
Parse build log files and extract diagnostics.

```bash
buildlog-parser parse [OPTIONS] <INPUT_FILE>
```

**Options:**
- `--output, -o <PATH>`: Output file path (default: stdout)
- `--format <FORMAT>`: Output format: text, json, summary (default: text)
- `--verbose`: Include verbose diagnostic information
- `--errors-only`: Only show errors (exclude warnings and info)
- `--show-stats`: Display statistics summary

#### `validate`
Validate that a build log file is readable and well-formed.

```bash
buildlog-parser validate [OPTIONS] <INPUT_FILE>
```

**Options:**
- `--verbose`: Show detailed validation information

### Examples

```bash
# Basic parsing
buildlog-parser parse build.log

# JSON output with statistics
buildlog-parser parse build.log --format json --show-stats --output result.json

# Process xcodebuild output directly
xcodebuild clean build test | buildlog-parser parse - --format summary

# Only errors with verbose output
buildlog-parser parse build.log --errors-only --verbose

# Validate log file
buildlog-parser validate build.log --verbose
```

## Output Formats

### Text Format
Human-readable output with emoji indicators:
```
❌ ViewController.swift:42: error - Use of undeclared identifier 'unknownVariable'
⚠️ DataManager.swift:15: warning - Variable 'data' was never used
```

### JSON Format
Structured output suitable for integration with other tools:
```json
{
  "diagnostics": [
    {
      "message": "Use of undeclared identifier 'unknownVariable'",
      "severity": "error",
      "file": "ViewController.swift",
      "line": 42,
      "column": 10,
      "relatedMessages": []
    }
  ],
  "metadata": {
    "totalCount": 1,
    "errorCount": 1,
    "warningCount": 0,
    "timestamp": "2025-09-15T10:30:00Z"
  }
}
```

### Summary Format
Brief overview with statistics:
```
📊 Build Log Analysis Summary
═══════════════════════════════════════════════════════════════

Total Issues Found: 3

❌ Errors: 1
⚠️ Warnings: 2

✅ Analysis completed
```

## Requirements

- **Swift**: 5.9 or later
- **Platforms**: macOS 10.15+, Linux
- **Dependencies**: Swift ArgumentParser (for CLI only)

## Testing

Run the test suite:

```bash
swift test
```

Run tests with verbose output:

```bash
swift test --verbose
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Clone the repository
2. Install dependencies: `swift package resolve`
3. Build: `swift build`
4. Run tests: `swift test`
5. Build CLI: `swift build -c release`

### Adding New Rules

To add support for new types of build errors:

1. Create a new rule class implementing `DiagnosticRule`
2. Add the rule to the default rule set in `BuildLogParserCommand.swift`
3. Add test cases in `BuildLogParserTests`
4. Update documentation

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### Version 1.0.0
- Initial release
- Support for Swift build and Xcode build log parsing
- Command line interface with multiple output formats
- Swift Testing framework integration
- Cross-platform support (macOS and Linux)
- Performance optimizations with fast-fail checking

## Related Projects

- [Swift ArgumentParser](https://github.com/apple/swift-argument-parser) - Command line argument parsing
- [Swift Testing](https://github.com/apple/swift-testing) - Modern testing framework for Swift 