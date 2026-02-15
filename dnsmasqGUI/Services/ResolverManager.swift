import Foundation
import Combine

/// Manages macOS resolver files in /etc/resolver/
@MainActor
class ResolverManager: ObservableObject {
    @Published var resolverFiles: [ResolverFile] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var hasUnsavedChanges: Bool = false

    static let resolverDirectory = "/etc/resolver"

    /// Load all resolver files from /etc/resolver/
    func loadResolverFiles() async {
        isLoading = true
        error = nil

        do {
            // First check if directory exists
            let exists = try await directoryExists()

            if !exists {
                resolverFiles = []
                isLoading = false
                return
            }

            // List files in the directory
            let files = try await listResolverFiles()
            var loadedFiles: [ResolverFile] = []

            for filename in files {
                if let content = try? await readResolverFile(filename) {
                    let file = ResolverFile.parse(domain: filename, content: content)
                    loadedFiles.append(file)
                }
            }

            resolverFiles = loadedFiles.sorted { $0.domain < $1.domain }
            hasUnsavedChanges = false
        } catch {
            self.error = "Failed to load resolver files: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Create the /etc/resolver directory if it doesn't exist
    func createResolverDirectory() async -> Bool {
        do {
            let script = """
                do shell script "mkdir -p \(Self.resolverDirectory)" with administrator privileges
                """
            _ = try await runAppleScript(script)
            return true
        } catch {
            self.error = "Failed to create resolver directory: \(error.localizedDescription)"
            return false
        }
    }

    /// Save a resolver file
    func saveResolverFile(_ file: ResolverFile) async -> Bool {
        do {
            // First ensure directory exists
            let exists = try await directoryExists()
            if !exists {
                let created = await createResolverDirectory()
                if !created {
                    return false
                }
            }

            // Write the file content
            let content = file.toFileContent()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("resolver_temp_\(UUID().uuidString)")

            try content.write(to: tempURL, atomically: true, encoding: .utf8)

            let script = """
                do shell script "cp '\(tempURL.path)' '\(file.filePath)'" with administrator privileges
                """
            _ = try await runAppleScript(script)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)

            // Reload files
            await loadResolverFiles()
            return true
        } catch {
            self.error = "Failed to save resolver file: \(error.localizedDescription)"
            return false
        }
    }

    /// Delete a resolver file
    func deleteResolverFile(_ file: ResolverFile) async -> Bool {
        do {
            let script = """
                do shell script "rm -f '\(file.filePath)'" with administrator privileges
                """
            _ = try await runAppleScript(script)

            // Reload files
            await loadResolverFiles()
            return true
        } catch {
            self.error = "Failed to delete resolver file: \(error.localizedDescription)"
            return false
        }
    }

    /// Add a resolver file to the local list (pending save)
    func addResolverFile(_ file: ResolverFile) {
        resolverFiles.append(file)
        resolverFiles.sort { $0.domain < $1.domain }
        hasUnsavedChanges = true
    }

    /// Update a resolver file in the local list (pending save)
    func updateResolverFile(_ file: ResolverFile) {
        if let index = resolverFiles.firstIndex(where: { $0.id == file.id }) {
            resolverFiles[index] = file
            hasUnsavedChanges = true
        }
    }

    /// Remove a resolver file from the local list
    func removeResolverFile(_ file: ResolverFile) {
        resolverFiles.removeAll { $0.id == file.id }
        hasUnsavedChanges = true
    }

    // MARK: - Private Methods

    private func directoryExists() async throws -> Bool {
        return FileManager.default.fileExists(atPath: Self.resolverDirectory)
    }

    private func listResolverFiles() async throws -> [String] {
        // Try direct access first
        if FileManager.default.isReadableFile(atPath: Self.resolverDirectory) {
            let contents = try FileManager.default.contentsOfDirectory(atPath: Self.resolverDirectory)
            return contents.filter { !$0.hasPrefix(".") }
        }

        // Use sudo if needed
        let script = """
            do shell script "ls -1 '\(Self.resolverDirectory)' 2>/dev/null || echo ''" with administrator privileges
            """
        let output = try await runAppleScript(script)
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix(".") }
    }

    private func readResolverFile(_ filename: String) async throws -> String {
        let path = "\(Self.resolverDirectory)/\(filename)"

        // Try direct access first
        if FileManager.default.isReadableFile(atPath: path) {
            return try String(contentsOfFile: path, encoding: .utf8)
        }

        // Use sudo if needed
        let script = """
            do shell script "cat '\(path)'" with administrator privileges
            """
        return try await runAppleScript(script)
    }

    private func runAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: ResolverError.appleScriptError(message))
                } else {
                    continuation.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }

    enum ResolverError: LocalizedError {
        case appleScriptError(String)
        case directoryNotFound
        case fileNotFound(String)

        var errorDescription: String? {
            switch self {
            case .appleScriptError(let message):
                return "AppleScript error: \(message)"
            case .directoryNotFound:
                return "Resolver directory not found"
            case .fileNotFound(let path):
                return "File not found: \(path)"
            }
        }
    }
}
