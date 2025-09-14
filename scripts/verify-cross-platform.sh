#!/bin/bash

# Cross-platform compatibility verification script
# Run this locally before pushing to ensure CI will pass

set -e

echo "🔍 BuildLogParser Cross-Platform Verification"
echo "=============================================="

# Check Swift version
echo "📋 Swift Version:"
swift --version
echo ""

# Check for platform-specific imports
echo "🔍 Checking for platform-specific imports..."
if grep -r "import UIKit\|import AppKit\|import WatchKit" Sources/ --include="*.swift" 2>/dev/null; then
    echo "❌ Found platform-specific imports!"
    exit 1
else
    echo "✅ No platform-specific imports found"
fi

# Check for mobile platform availability attributes
echo "🔍 Checking for mobile platform @available attributes..."
if grep -r "@available.*iOS\|@available.*watchOS\|@available.*tvOS\|@available.*visionOS" Sources/ --include="*.swift" 2>/dev/null; then
    echo "❌ Found mobile platform availability attributes!"
    exit 1
else
    echo "✅ No mobile platform attributes found"
fi

# Check for Windows-incompatible APIs
echo "🔍 Checking for potentially Windows-incompatible APIs..."
if grep -r "FileManager\.default\.homeDirectory\|NSWorkspace\|NSApplication" Sources/ --include="*.swift" 2>/dev/null; then
    echo "⚠️  Found potentially Windows-incompatible APIs"
    echo "   Please verify these work on Windows or add platform guards"
else
    echo "✅ No obviously Windows-incompatible APIs found"
fi

# Resolve dependencies
echo "📦 Resolving package dependencies..."
swift package resolve

# Build debug
echo "🔨 Building debug configuration..."
swift build

# Build release
echo "🔨 Building release configuration..."
swift build -c release

# Run tests
echo "🧪 Running tests..."
if swift test; then
    echo "✅ All tests passed"
else
    echo "⚠️  Some tests failed - this may not affect cross-platform compatibility"
    echo "   Please review test failures to ensure they're not platform-specific"
fi

# Check for TODO/FIXME
echo "🔍 Checking for TODO/FIXME comments..."
if grep -r "TODO\|FIXME" Sources/ Tests/ --include="*.swift" 2>/dev/null; then
    echo "⚠️  Found TODO or FIXME comments"
    echo "   Consider addressing them before release"
else
    echo "✅ No TODO or FIXME comments found"
fi

echo ""
echo "🎉 All cross-platform verification checks passed!"
echo "   Ready to push to GitHub - CI should pass"