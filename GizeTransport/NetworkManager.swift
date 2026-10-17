import Combine
import Network

/// Shares one path monitor across the app instead of opening a diagnostic
/// clear-text connection to an unrelated website.
final class NetworkManager: ObservableObject {
    static let shared = NetworkManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkManagerQueue")

    @Published private(set) var isConnected = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
