# BuildLogParser CI/CD

This repository includes comprehensive CI/CD workflows to ensure cross-platform compatibility.

## Workflows

### 🔄 CI Workflow (`.github/workflows/ci.yml`)

Runs on every push and pull request to `main` and `develop` branches.

**Matrix Testing:**
- **Platforms:** Ubuntu (Linux), macOS
- **Swift Versions:** 5.9, 5.10
- **Jobs:**
  - **test**: Build and test on both platforms
  - **compatibility-test**: Test on older macOS version
  - **lint**: Code quality checks
  - **cross-platform**: Verify cross-platform API usage

**What it checks:**
- ✅ Code builds successfully
- ✅ All tests pass
- ✅ Release build works
- ✅ No platform-specific imports (UIKit, AppKit, etc.)
- ✅ No mobile platform `@available` attributes
- ✅ Code quality and formatting

### 🚀 Release Workflow (`.github/workflows/release.yml`)

Triggered when you push a version tag (e.g., `v1.0.0`).

**Features:**
- Creates GitHub release
- Builds on both Linux and macOS
- Runs final verification tests
- Archives build artifacts

## Platform Support Status

| Platform | Status | CI Testing |
|----------|--------|------------|
| macOS 10.15+ | ✅ Fully Supported | ✅ Yes |
| Linux | ✅ Fully Supported | ✅ Yes |
| Windows | ✅ Supported* | ❌ Not tested in CI |

*Windows support is theoretical via Swift for Windows, but not currently tested in CI.

## Local Testing

To test locally before pushing:

```bash
# Test on current platform
swift test

# Build release
swift build -c release

# Check for platform-specific code
grep -r "import UIKit\|import AppKit" Sources/ || echo "No platform-specific imports found"
grep -r "@available.*iOS\|@available.*watchOS" Sources/ || echo "No mobile platform attributes found"
```

## Creating a Release

1. Ensure all tests pass locally
2. Update version in relevant files
3. Create and push a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. The release workflow will automatically run and create a GitHub release

## Badges

Add these to your main README:

```markdown
![CI](https://github.com/aelam/BuildLogParser/workflows/CI/badge.svg)
![Release](https://github.com/aelam/BuildLogParser/workflows/Release/badge.svg)
```