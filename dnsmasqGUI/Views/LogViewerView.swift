import SwiftUI

struct LogViewerView: View {
    @EnvironmentObject var logReader: LogReader
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var showExportDialog = false

    private var filteredLogs: [LogReader.LogLine] {
        logReader.filteredLogs(searchText: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Log Viewer")
                    .font(.headline)

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(logReader.isMonitoring ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(logReader.isMonitoring ? "Monitoring" : "Stopped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 20)

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button(action: {
                    if logReader.isMonitoring {
                        logReader.stopMonitoring()
                    } else {
                        logReader.startMonitoring()
                    }
                }) {
                    Label(
                        logReader.isMonitoring ? "Stop" : "Start",
                        systemImage: logReader.isMonitoring ? "pause.fill" : "play.fill"
                    )
                }

                Button(action: {
                    logReader.clearLogs()
                }) {
                    Label("Clear", systemImage: "trash")
                }

                Button(action: {
                    showExportDialog = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(logReader.logLines.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter logs...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            // Log content
            if let error = logReader.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        logReader.startMonitoring()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Text("No log entries yet")
                            .foregroundColor(.secondary)
                        if !logReader.isMonitoring {
                            Button("Start Monitoring") {
                                logReader.startMonitoring()
                            }
                        }
                    } else {
                        Text("No matching log entries")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredLogs) { line in
                                LogLineView(line: line, searchText: searchText)
                                    .id(line.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: logReader.logLines.count) { _ in
                        if autoScroll, let lastLine = filteredLogs.last {
                            withAnimation {
                                proxy.scrollTo(lastLine.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer stats
            HStack {
                Text("\(filteredLogs.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !searchText.isEmpty {
                    Text("(filtered from \(logReader.logLines.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if logReader.isMonitoring {
                    Text("Last updated: \(formattedTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            if !logReader.isMonitoring {
                logReader.startMonitoring()
            }
        }
        .fileExporter(
            isPresented: $showExportDialog,
            document: LogDocument(content: logReader.exportLogs()),
            contentType: .plainText,
            defaultFilename: "dnsmasq-log-\(exportFilename).txt"
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct LogLineView: View {
    let line: LogReader.LogLine
    let searchText: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Type indicator
            Circle()
                .fill(typeColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            // Timestamp
            if let timestamp = line.timestamp {
                Text(formatTimestamp(timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
            }

            // Content
            Text(highlightedContent)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var typeColor: Color {
        switch line.type {
        case .query: return .blue
        case .reply: return .green
        case .dhcp: return .purple
        case .error: return .red
        case .info: return .gray
        }
    }

    private var highlightedContent: AttributedString {
        var content = AttributedString(line.content)

        if !searchText.isEmpty {
            // Highlight search matches
            var searchRange = content.startIndex..<content.endIndex
            while let range = content[searchRange].range(of: searchText, options: .caseInsensitive) {
                content[range].backgroundColor = .yellow.opacity(0.3)
                content[range].foregroundColor = .primary
                if range.upperBound < content.endIndex {
                    searchRange = range.upperBound..<content.endIndex
                } else {
                    break
                }
            }
        }

        return content
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// Document type for file export
struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            content = string
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

import UniformTypeIdentifiers

#Preview {
    LogViewerView()
        .environmentObject(LogReader())
}
