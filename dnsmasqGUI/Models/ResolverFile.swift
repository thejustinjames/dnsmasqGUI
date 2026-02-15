import Foundation

/// Represents a resolver file in /etc/resolver/
struct ResolverFile: Identifiable, Hashable {
    let id: UUID
    var domain: String  // Filename (e.g., "local" for /etc/resolver/local)
    var nameservers: [String]  // List of nameserver IPs
    var searchDomains: [String]  // Optional search domains
    var options: [String]  // Optional resolver options
    var comment: String?

    init(
        id: UUID = UUID(),
        domain: String,
        nameservers: [String] = ["127.0.0.1"],
        searchDomains: [String] = [],
        options: [String] = [],
        comment: String? = nil
    ) {
        self.id = id
        self.domain = domain
        self.nameservers = nameservers
        self.searchDomains = searchDomains
        self.options = options
        self.comment = comment
    }

    /// Path to the resolver file
    var filePath: String {
        "/etc/resolver/\(domain)"
    }

    /// Generate the resolver file content
    func toFileContent() -> String {
        var lines: [String] = []

        // Add comment if present
        if let comment = comment, !comment.isEmpty {
            lines.append("# \(comment)")
        }

        // Add nameservers
        for ns in nameservers {
            lines.append("nameserver \(ns)")
        }

        // Add search domains
        for sd in searchDomains {
            lines.append("search \(sd)")
        }

        // Add options
        for opt in options {
            lines.append(opt)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Parse resolver file content
    static func parse(domain: String, content: String) -> ResolverFile {
        var nameservers: [String] = []
        var searchDomains: [String] = []
        var options: [String] = []
        var comment: String?

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                continue
            }

            if trimmed.hasPrefix("#") {
                // First comment becomes the file comment
                if comment == nil {
                    comment = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("nameserver ") {
                let ns = String(trimmed.dropFirst("nameserver ".count)).trimmingCharacters(in: .whitespaces)
                if !ns.isEmpty {
                    nameservers.append(ns)
                }
            } else if trimmed.hasPrefix("search ") {
                let sd = String(trimmed.dropFirst("search ".count)).trimmingCharacters(in: .whitespaces)
                if !sd.isEmpty {
                    searchDomains.append(sd)
                }
            } else {
                // Other options
                options.append(trimmed)
            }
        }

        return ResolverFile(
            domain: domain,
            nameservers: nameservers.isEmpty ? ["127.0.0.1"] : nameservers,
            searchDomains: searchDomains,
            options: options,
            comment: comment
        )
    }
}
