# Platform Support

BuildLogParser supports multiple platforms:

## Supported Platforms

### ✅ Officially Supported
- **macOS 10.15+** - Full support with all features
- **Linux** - Full support (Ubuntu 18.04+, CentOS 7+, etc.)
- **Windows** - Full support via Swift for Windows


## Platform-Specific Notes

### Linux
- No explicit platform declaration needed in Package.swift
- Swift Package Manager includes Linux support by default
- All Foundation APIs used are cross-platform compatible

### Windows
- Supported via Swift for Windows
- No Windows-specific code modifications needed
- Foundation framework provides cross-platform compatibility

### Testing on Different Platforms

```bash
# Test on current platform
swift test

# Build for release
swift build -c release

# Run on Linux (via Docker)
docker run --rm -v "$PWD":/workspace swift:5.9 bash -c "cd /workspace && swift test"
```

## Cross-Platform Compatibility

The codebase uses only cross-platform APIs:
- Foundation framework
- Standard Swift library
- Regular expressions
- File I/O operations

No platform-specific conditionals (`#if os(...)`) are required.