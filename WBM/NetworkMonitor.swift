//
//  NetworkMonitor.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/31/25.
//

// NetworkMonitor.swift (Create new file)
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private var status: NWPath.Status = .requiresConnection
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.status = path.status
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    func isConnected() -> Bool {
        return status == .satisfied
    }
}
