//
//  Diagnostic.swift
//  XcodebuildLogParser
//
//  Created by wang.lun on 2025/09/14.
//

// return Diagnostic(file: nil, line: nil, column: nil, severity: .error, message: line, relatedMessages: [])

public struct Diagnostic {
    public enum Severity {
        case error
        case warning
        case note
        case info
    }

    public let file: String?
    public let line: Int?
    public let column: Int?
    public let severity: Severity
    public let message: String
    public var relatedMessages: [String]
    public let source: String?
    public let category: String?
    public let raw: String
    public let buildTarget: String?
}
