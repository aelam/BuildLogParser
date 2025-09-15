# Architecture

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

