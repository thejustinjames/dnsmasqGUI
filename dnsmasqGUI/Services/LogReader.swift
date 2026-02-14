import Foundation
import Combine

/// Reads and monitors the dnsmasq log file
@MainActor
class LogReader: ObservableObject {
    @Published var logLines: [LogLine] = []
    @Published var isMonitoring: Bool = false
    @Published var error: String?

    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let logPaths = [
        "/opt/homebrew/var/log/dnsmasq.log",
        "/var/log/dnsmasq.log",
        "/var/log/system.log"
    ]

    private var currentLogPath: String?
    private let maxLines = 1000

    struct LogLine: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date?
        let content: String
        let type: LogType

        enum LogType {
            case query
            case reply
            case dhcp
            case error
            case info

            var color: String {
                switch self {
                case .query: return "blue"
                case .reply: return "green"
                case .dhcp: return "purple"
                case .error: return "red"
                case .info: return "primary"
                }
            }
        }
    }

    deinit {
        stopMonitoring()
    }

    /// Start monitoring the log file
    func startMonitoring() {
        guard !isMonitoring else { return }

        // Find the first accessible log file
        for path in logPaths {
            if FileManager.default.fileExists(atPath: path) {
                currentLogPath = path
                break
            }
        }

        guard let logPath = currentLogPath else {
            error = "No log file found. Checked: \(logPaths.joined(separator: ", "))"
            return
        }

        do {
            // Read existing content
            let content = try readLogFile(at: logPath)
            parseLogContent(content)

            // Set up file monitoring
            setupFileMonitoring(path: logPath)
            isMonitoring = true
            error = nil
        } catch {
            self.error = "Failed to read log: \(error.localizedDescription)"
        }
    }

    /// Stop monitoring the log file
    func stopMonitoring() {
        dispatchSource?.cancel()
        dispatchSource = nil
        fileHandle?.closeFile()
        fileHandle = nil
        isMonitoring = false
    }

    /// Clear the log display
    func clearLogs() {
        logLines.removeAll()
    }

    /// Export logs to a file
    func exportLogs() -> String {
        logLines.map { line in
            let timestamp = line.timestamp.map { formatTimestamp($0) } ?? ""
            return "\(timestamp) \(line.content)"
        }.joined(separator: "\n")
    }

    /// Filter logs by search term
    func filteredLogs(searchText: String) -> [LogLine] {
        if searchText.isEmpty {
            return logLines
        }
        return logLines.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Private Methods

    private func readLogFile(at path: String) throws -> String {
        // Try direct read first
        if FileManager.default.isReadableFile(atPath: path) {
            return try String(contentsOfFile: path, encoding: .utf8)
        }

        // Fall back to sudo read
        return try runSudoCommand("cat '\(path)'")
    }

    private func setupFileMonitoring(path: String) {
        let fileDescriptor = open(path, O_RDONLY)
        guard fileDescriptor >= 0 else {
            error = "Could not open log file for monitoring"
            return
        }

        fileHandle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: true)

        // Seek to end for new content only
        fileHandle?.seekToEndOfFile()

        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend],
            queue: .main
        )

        dispatchSource?.setEventHandler { [weak self] in
            self?.readNewContent()
        }

        dispatchSource?.setCancelHandler { [weak self] in
            self?.fileHandle?.closeFile()
            self?.fileHandle = nil
        }

        dispatchSource?.resume()
    }

    private func readNewContent() {
        guard let handle = fileHandle else { return }

        let data = handle.readDataToEndOfFile()
        if let content = String(data: data, encoding: .utf8), !content.isEmpty {
            parseLogContent(content)
        }
    }

    private func parseLogContent(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .filter { $0.lowercased().contains("dnsmasq") || currentLogPath?.contains("dnsmasq") == true }

        let newLines = lines.map { parseLogLine($0) }
        logLines.append(contentsOf: newLines)

        // Trim to max lines
        if logLines.count > maxLines {
            logLines.removeFirst(logLines.count - maxLines)
        }
    }

    private func parseLogLine(_ line: String) -> LogLine {
        let timestamp = extractTimestamp(from: line)
        let type = determineLogType(line)
        return LogLine(timestamp: timestamp, content: line, type: type)
    }

    private func extractTimestamp(from line: String) -> Date? {
        // Common log timestamp formats
        let formats = [
            "MMM dd HH:mm:ss",  // syslog format
            "yyyy-MM-dd HH:mm:ss"
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            dateFormatter.dateFormat = format
            // Try to extract first part that might be a timestamp
            let components = line.split(separator: " ", maxSplits: 3)
            if components.count >= 3 {
                let potentialTimestamp = "\(components[0]) \(components[1]) \(components[2])"
                if let date = dateFormatter.date(from: potentialTimestamp) {
                    return date
                }
            }
        }

        return nil
    }

    private func determineLogType(_ line: String) -> LogLine.LogType {
        let lower = line.lowercased()

        if lower.contains("query[") {
            return .query
        } else if lower.contains("reply") || lower.contains("cached") || lower.contains("forwarded") {
            return .reply
        } else if lower.contains("dhcp") {
            return .dhcp
        } else if lower.contains("error") || lower.contains("failed") || lower.contains("refused") {
            return .error
        }

        return .info
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func runSudoCommand(_ command: String) throws -> String {
        let script = """
            do shell script "\(command)" with administrator privileges
            """

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)

        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw LogError.readError(message)
        }

        return result?.stringValue ?? ""
    }

    enum LogError: LocalizedError {
        case readError(String)
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .readError(let message):
                return "Log read error: \(message)"
            case .fileNotFound:
                return "Log file not found"
            }
        }
    }
}
