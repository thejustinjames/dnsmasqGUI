import Foundation

/// Represents the current status of the dnsmasq service
struct ServiceStatus: Equatable {
    var state: ServiceState
    var pid: Int?
    var errorMessage: String?
    var lastChecked: Date

    enum ServiceState: String, Equatable {
        case running = "Running"
        case stopped = "Stopped"
        case error = "Error"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .running: return "circle.fill"
            case .stopped: return "circle"
            case .error: return "exclamationmark.circle.fill"
            case .unknown: return "questionmark.circle"
            }
        }

        var color: String {
            switch self {
            case .running: return "green"
            case .stopped: return "gray"
            case .error: return "red"
            case .unknown: return "orange"
            }
        }
    }

    init(state: ServiceState = .unknown, pid: Int? = nil, errorMessage: String? = nil) {
        self.state = state
        self.pid = pid
        self.errorMessage = errorMessage
        self.lastChecked = Date()
    }

    static let unknown = ServiceStatus(state: .unknown)
}
