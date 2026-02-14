import Foundation

/// Represents a DHCP configuration entry in dnsmasq
struct DHCPLease: Identifiable, Codable, Equatable {
    let id: UUID
    var entryType: EntryType

    enum EntryType: Codable, Equatable {
        case range(DHCPRange)
        case host(DHCPHost)
        case option(DHCPOption)
    }

    init(id: UUID = UUID(), entryType: EntryType) {
        self.id = id
        self.entryType = entryType
    }
}

/// DHCP range configuration: dhcp-range=start,end,lease-time
struct DHCPRange: Codable, Equatable {
    var startIP: String
    var endIP: String
    var leaseTime: String
    var netmask: String?
    var comment: String?

    func toConfigLine() -> String {
        var parts = [startIP, endIP]
        if let netmask = netmask, !netmask.isEmpty {
            parts.append(netmask)
        }
        parts.append(leaseTime)
        var line = "dhcp-range=\(parts.joined(separator: ","))"
        if let comment = comment, !comment.isEmpty {
            line += " # \(comment)"
        }
        return line
    }

    static func fromConfigLine(_ line: String) -> DHCPRange? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("dhcp-range=") else { return nil }

        var mainPart = trimmed
        var comment: String? = nil
        if let commentIndex = trimmed.firstIndex(of: "#") {
            mainPart = String(trimmed[..<commentIndex]).trimmingCharacters(in: .whitespaces)
            comment = String(trimmed[trimmed.index(after: commentIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        let value = String(mainPart.dropFirst(11))
        let parts = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count >= 3 else { return nil }

        if parts.count == 3 {
            return DHCPRange(startIP: parts[0], endIP: parts[1], leaseTime: parts[2], netmask: nil, comment: comment)
        } else {
            return DHCPRange(startIP: parts[0], endIP: parts[1], leaseTime: parts[3], netmask: parts[2], comment: comment)
        }
    }
}

/// DHCP static host: dhcp-host=mac,ip,hostname
struct DHCPHost: Codable, Equatable {
    var macAddress: String
    var ipAddress: String
    var hostname: String?
    var leaseTime: String?
    var comment: String?

    func toConfigLine() -> String {
        var parts = [macAddress, ipAddress]
        if let hostname = hostname, !hostname.isEmpty {
            parts.append(hostname)
        }
        if let leaseTime = leaseTime, !leaseTime.isEmpty {
            parts.append(leaseTime)
        }
        var line = "dhcp-host=\(parts.joined(separator: ","))"
        if let comment = comment, !comment.isEmpty {
            line += " # \(comment)"
        }
        return line
    }

    static func fromConfigLine(_ line: String) -> DHCPHost? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("dhcp-host=") else { return nil }

        var mainPart = trimmed
        var comment: String? = nil
        if let commentIndex = trimmed.firstIndex(of: "#") {
            mainPart = String(trimmed[..<commentIndex]).trimmingCharacters(in: .whitespaces)
            comment = String(trimmed[trimmed.index(after: commentIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        let value = String(mainPart.dropFirst(10))
        let parts = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count >= 2 else { return nil }

        // Determine which parts are which based on format
        let mac = parts[0]
        let ip = parts[1]
        var hostname: String? = nil
        var leaseTime: String? = nil

        if parts.count > 2 {
            let third = parts[2]
            // If it looks like a time (contains h, m, s, or is "infinite")
            if third.contains(where: { "hms".contains($0) }) || third == "infinite" {
                leaseTime = third
            } else {
                hostname = third
                if parts.count > 3 {
                    leaseTime = parts[3]
                }
            }
        }

        return DHCPHost(macAddress: mac, ipAddress: ip, hostname: hostname, leaseTime: leaseTime, comment: comment)
    }
}

/// DHCP option: dhcp-option=option,value
struct DHCPOption: Codable, Equatable {
    var optionNumber: Int
    var value: String
    var comment: String?

    // Common DHCP options
    static let commonOptions: [(Int, String)] = [
        (1, "Subnet Mask"),
        (3, "Router/Gateway"),
        (6, "DNS Server"),
        (15, "Domain Name"),
        (28, "Broadcast Address"),
        (42, "NTP Server"),
        (44, "WINS Server"),
        (119, "Domain Search List")
    ]

    var optionName: String {
        Self.commonOptions.first { $0.0 == optionNumber }?.1 ?? "Option \(optionNumber)"
    }

    func toConfigLine() -> String {
        var line = "dhcp-option=\(optionNumber),\(value)"
        if let comment = comment, !comment.isEmpty {
            line += " # \(comment)"
        }
        return line
    }

    static func fromConfigLine(_ line: String) -> DHCPOption? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("dhcp-option=") else { return nil }

        var mainPart = trimmed
        var comment: String? = nil
        if let commentIndex = trimmed.firstIndex(of: "#") {
            mainPart = String(trimmed[..<commentIndex]).trimmingCharacters(in: .whitespaces)
            comment = String(trimmed[trimmed.index(after: commentIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        let value = String(mainPart.dropFirst(12))
        let parts = value.split(separator: ",", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count >= 2, let optionNum = Int(parts[0]) else { return nil }

        return DHCPOption(optionNumber: optionNum, value: parts[1], comment: comment)
    }
}
