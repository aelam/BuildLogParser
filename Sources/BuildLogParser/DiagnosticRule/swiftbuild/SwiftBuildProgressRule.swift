import Foundation

// MARK: - Swift Build Progress Rule

// 解析 swift build 中的编译进度信息
// 匹配格式: [N/M] Compiling ModuleName file.swift

public struct SwiftBuildProgressRule: DiagnosticRule {
    private let progressRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\[(\d+)/(\d+)\] (Compiling|Linking|Building) (.+)$"#,
                options: []
            )
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }()

    public init() {}

    public func matchStart(line: String) -> Diagnostic? {
        guard let match = progressRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard
            let currentRange = Range(match.range(at: 1), in: line),
            let totalRange = Range(match.range(at: 2), in: line),
            let actionRange = Range(match.range(at: 3), in: line),
            let targetRange = Range(match.range(at: 4), in: line)
        else {
            return nil
        }

        let current = String(line[currentRange])
        let total = String(line[totalRange])
        let action = String(line[actionRange])
        let target = String(line[targetRange])

        let message = "\(action) \(target) (\(current)/\(total))"

        return Diagnostic(
            file: nil,
            line: nil,
            column: nil,
            severity: .info,
            message: message,
            relatedMessages: [],
            source: "swift-build",
            category: "progress",
            raw: line,
            buildTarget: target
        )
    }

    public func matchContinuation(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "progress" else { return false }

        // 进度信息通常是单行的
        return false
    }

    public func isEnd(line: String, current: Diagnostic?) -> Bool {
        guard current?.category == "progress" else { return false }

        // 进度信息总是单行结束
        return true
    }
}
