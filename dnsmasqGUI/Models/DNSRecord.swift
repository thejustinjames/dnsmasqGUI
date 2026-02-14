import Foundation

/// Represents a DNS record entry in dnsmasq configuration
struct DNSRecord: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var recordType: RecordType
    var domain: String
    var value: String
    var comment: String?

    enum RecordType: String, Codable, CaseIterable {
        case address = "address"      // address=/domain/ip - Local DNS override
        case server = "server"        // server=/domain/ip - Upstream server for domain
        case local = "local"          // local=/domain/ - Answer locally only

        var displayName: String {
            switch self {
            case .address: return "Address Override"
            case .server: return "Upstream Server"
            case .local: return "Local Only"
            }
        }

        var description: String {
            switch self {
            case .address: return "Override DNS resolution for a domain to a specific IP"
            case .server: return "Use a specific DNS server for a domain"
            case .local: return "Only answer from local configuration, never forward"
            }
        }
    }

    init(id: UUID = UUID(), recordType: RecordType, domain: String, value: String, comment: String? = nil) {
        self.id = id
        self.recordType = recordType
        self.domain = domain
        self.value = value
        self.comment = comment
    }

    /// Convert to dnsmasq config line format
    func toConfigLine() -> String {
        var line: String
        switch recordType {
        case .address:
            line = "address=/\(domain)/\(value)"
        case .server:
            if domain.isEmpty {
                line = "server=\(value)"
            } else {
                line = "server=/\(domain)/\(value)"
            }
        case .local:
            line = "local=/\(domain)/"
        }

        if let comment = comment, !comment.isEmpty {
            line += " # \(comment)"
        }
        return line
    }

    /// Parse from dnsmasq config line
    static func fromConfigLine(_ line: String) -> DNSRecord? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Extract comment if present
        var mainPart = trimmed
        var comment: String? = nil
        if let commentIndex = trimmed.firstIndex(of: "#") {
            mainPart = String(trimmed[..<commentIndex]).trimmingCharacters(in: .whitespaces)
            comment = String(trimmed[trimmed.index(after: commentIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        // Parse address=/domain/ip
        if mainPart.hasPrefix("address=") {
            let parts = mainPart.dropFirst(8).split(separator: "/", omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let domain = String(parts[0].isEmpty ? parts[1] : parts[0])
                let ip = parts.count > 2 ? String(parts[2]) : String(parts[1])
                return DNSRecord(recordType: .address, domain: domain, value: ip, comment: comment)
            }
        }

        // Parse server=/domain/ip or server=ip
        if mainPart.hasPrefix("server=") {
            let value = String(mainPart.dropFirst(7))
            if value.contains("/") {
                let parts = value.split(separator: "/", omittingEmptySubsequences: false)
                if parts.count >= 2 {
                    let domain = String(parts[0].isEmpty ? parts[1] : parts[0])
                    let ip = parts.count > 2 ? String(parts[2]) : ""
                    return DNSRecord(recordType: .server, domain: domain, value: ip, comment: comment)
                }
            } else {
                return DNSRecord(recordType: .server, domain: "", value: value, comment: comment)
            }
        }

        // Parse local=/domain/
        if mainPart.hasPrefix("local=") {
            let value = String(mainPart.dropFirst(6))
            let domain = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return DNSRecord(recordType: .local, domain: domain, value: "", comment: comment)
        }

        return nil
    }
}
