//
//  NetworkPathMonitor.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Network
import Combine

// MARK: - NetworkStatus

/// Modern network reachability status using the Network framework.
///
/// This enum provides comprehensive network status information that goes
/// beyond simple connected/disconnected states, offering insight into
/// the quality and nature of network connectivity.
enum NetworkStatus: String, CaseIterable {
    /// Network path is available and ready for use
    case satisfied = "Connected"
    
    /// No network path is available
    case unsatisfied = "Not Connected"
    
    /// Network path may be available but requires user interaction
    /// (e.g., captive portal, VPN authentication)
    case requiresConnection = "Requires Connection"
    
    /// Network status could not be determined
    case unknown = "Unknown"
}

// MARK: - NetworkInterfaceType

/// Types of network interfaces available on iOS devices.
///
/// This enum categorizes the different ways a device can connect to networks,
/// providing insight into connection characteristics like speed, cost, and reliability.
enum NetworkInterfaceType: String {
    /// WiFi network connection (typically fastest, unlimited)
    case wifi = "WiFi"
    
    /// Cellular network connection (may be metered/expensive)
    case cellular = "Cellular"
    
    /// Wired Ethernet connection (rare on mobile devices)
    case wiredEthernet = "Ethernet"
    
    /// Loopback interface (localhost connections)
    case loopback = "Loopback"
    
    /// Other interface types not covered above
    case other = "Other"
    
    /// Interface type could not be determined
    case unknown = "Unknown"
}

// MARK: - NetworkPathMonitor

/// Advanced network connectivity monitoring using the modern Network framework.
///
/// This class provides comprehensive network monitoring capabilities that go far beyond
/// simple reachability checking. It offers detailed information about connection types,
/// cost characteristics, and quality indicators that are essential for modern app
/// networking decisions.
///
/// ## Key Features
/// - **Real-time Monitoring**: Continuous network status updates
/// - **Connection Type Detection**: WiFi, cellular, ethernet classification
/// - **Cost Awareness**: Expensive connection detection (cellular, hotspot)
/// - **Quality Indicators**: Constrained connection detection (low data mode)
/// - **Modern API**: Built on iOS 13+ Network framework
/// - **Combine Support**: SwiftUI and Combine integration ready
///
/// ## Usage Examples
///
/// ### Basic Connectivity Check
/// ```swift
/// let monitor = NetworkPathMonitor()
/// monitor.startMonitoring()
///
/// if monitor.isConnected {
///     // Proceed with network requests
/// }
/// ```
///
/// ### Adaptive Quality Based on Connection
/// ```swift
/// if monitor.isConnectedViaWiFi {
///     // High quality content, unlimited bandwidth
///     loadHighResolutionImages()
/// } else if monitor.isConnectedViaCellular && !monitor.isExpensive {
///     // Moderate quality on unlimited cellular
///     loadMediumResolutionImages()
/// } else {
///     // Conservative approach for expensive connections
///     loadLowResolutionImages()
/// }
/// ```
///
/// ### SwiftUI Integration
/// ```swift
/// @StateObject private var networkMonitor = NetworkPathMonitor()
///
/// var body: some View {
///     VStack {
///         if networkMonitor.isConnected {
///             OnlineContentView()
///         } else {
///             OfflineMessageView()
///         }
///     }
///     .onAppear {
///         networkMonitor.startMonitoring()
///     }
/// }
/// ```
class NetworkPathMonitor: ObservableObject {

    // MARK: - Private Properties

    /// Core Network framework monitor for path updates
    private let monitor = NWPathMonitor()
    
    /// Dedicated queue for network monitoring operations
    private let queue = DispatchQueue(label: "NetworkPathMonitor")

    // MARK: - Published Properties

    /// Whether the device currently has network connectivity
    /// - Note: Published property automatically triggers UI updates
    @Published var isConnected: Bool = false
    
    /// The type of network interface currently in use
    /// - Note: May be .unknown during initialization or transitions
    @Published var connectionType: NetworkInterfaceType = .unknown
    
    /// Detailed status of the network path
    /// - Note: Provides more granular information than simple connected/disconnected
    @Published var status: NetworkStatus = .unknown

    // MARK: - Legacy Support Properties

    /// Optional callback for legacy code that doesn't use Combine
    /// - Note: Called whenever network status changes
    var statusUpdateCallback: ((NetworkStatus) -> Void)?

    // MARK: - Private State

    /// Current network path for detailed analysis
    /// - Note: Provides access to advanced Network framework features
    private(set) var currentPath: NWPath?

    // MARK: - Computed Properties

    /// Whether the current connection is considered expensive.
    ///
    /// Expensive connections include:
    /// - Cellular data connections
    /// - Personal hotspot connections
    /// - Connections marked as expensive by the system
    ///
    /// ## Usage
    /// Use this property to make intelligent decisions about data usage:
    /// ```swift
    /// if !monitor.isExpensive {
    ///     downloadLargeFiles()
    /// } else {
    ///     showDataUsageWarning()
    /// }
    /// ```
    var isExpensive: Bool {
        return currentPath?.isExpensive ?? false
    }

    /// Whether the current connection is constrained (Low Data Mode).
    ///
    /// Constrained connections occur when:
    /// - User has enabled Low Data Mode in system settings
    /// - Connection is explicitly marked as constrained
    /// - System is conserving data usage for any reason
    ///
    /// ## Usage
    /// Respect user preferences by reducing data usage:
    /// ```swift
    /// if monitor.isConstrained {
    ///     disableAutoPlay()
    ///     reduceSyncFrequency()
    ///     useCompressedImages()
    /// }
    /// ```
    var isConstrained: Bool {
        return currentPath?.isConstrained ?? false
    }

    // MARK: - Initialization

    /// Initializes a NetworkPathMonitor for general network monitoring
    init() {
        setupMonitoring()
    }

    /// Initializes a NetworkPathMonitor for a specific interface type
    /// - Parameter interfaceType: The specific interface type to monitor
    ///
    /// ## Use Cases
    /// - Monitor only cellular connections for data usage tracking
    /// - Monitor only WiFi for high-bandwidth operations
    /// - Monitor ethernet for wired device scenarios
    ///
    /// ## Example
    /// ```swift
    /// let cellularMonitor = NetworkPathMonitor(interfaceType: .cellular)
    /// cellularMonitor.startMonitoring()
    /// ```
    ///
    /// - Note: Currently creates a general monitor but could be enhanced
    ///         to use NWPathMonitor(requiredInterfaceType:) for specific monitoring
    init(interfaceType: NWInterface.InterfaceType) {
        // Future enhancement: Use NWPathMonitor(requiredInterfaceType: interfaceType)
        setupMonitoring()
    }

    /// Cleanup monitoring resources when instance is deallocated
    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Begins network path monitoring
    ///
    /// This method starts the monitoring process and begins receiving
    /// network path updates. The monitor will continue running until
    /// `stopMonitoring()` is called or the instance is deallocated.
    ///
    /// ## Threading
    /// - Safe to call from any thread
    /// - Updates are delivered on the main thread for UI consistency
    /// - Uses dedicated background queue for network operations
    ///
    /// ## Performance
    /// - Minimal CPU and battery impact
    /// - Only active while monitoring is enabled
    /// - Automatic cleanup on deallocation
    func startMonitoring() {
        monitor.start(queue: queue)
    }

    /// Stops network path monitoring
    ///
    /// This method stops the monitoring process and releases system resources.
    /// Call this when you no longer need network status updates to conserve
    /// battery and system resources.
    ///
    /// ## Best Practices
    /// - Call when view disappears for view-specific monitoring
    /// - Use deinit for automatic cleanup
    /// - Safe to call multiple times
    func stopMonitoring() {
        monitor.cancel()
    }

    // MARK: - Private Methods

    /// Configures the network path monitoring system
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
    }

    /// Updates network status based on new path information
    /// - Parameter path: The new network path from Network framework
    ///
    /// ## Update Process
    /// 1. Stores current path for detailed analysis
    /// 2. Updates basic connectivity status
    /// 3. Determines detailed network status
    /// 4. Identifies connection type
    /// 5. Triggers UI updates via @Published properties
    /// 6. Calls legacy callback if configured
    private func updateNetworkStatus(path: NWPath) {
        currentPath = path

        // Update basic connectivity
        isConnected = (path.status == .satisfied)

        // Update detailed status
        switch path.status {
        case .satisfied:
            status = .satisfied
        case .unsatisfied:
            status = .unsatisfied
        case .requiresConnection:
            status = .requiresConnection
        @unknown default:
            status = .unknown
        }

        // Update connection type
        connectionType = determineConnectionType(path: path)

        // Notify legacy callback system
        statusUpdateCallback?(status)
    }

    /// Determines the primary connection type from network path
    /// - Parameter path: Network path to analyze
    /// - Returns: The primary interface type in use
    ///
    /// ## Priority Order
    /// Network interfaces are checked in priority order:
    /// 1. WiFi (preferred for speed and cost)
    /// 2. Cellular (mobile connectivity)
    /// 3. Wired Ethernet (rare on mobile)
    /// 4. Loopback (localhost)
    /// 5. Other (custom interfaces)
    /// 6. Unknown (fallback)
    ///
    /// ## Multi-Interface Handling
    /// - Returns the highest priority active interface
    /// - May not reflect all available interfaces
    /// - Prioritizes user-facing connectivity types
    private func determineConnectionType(path: NWPath) -> NetworkInterfaceType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }
}

// MARK: - Convenience Extensions

extension NetworkPathMonitor {

    /// Whether the device is connected specifically via WiFi
    /// - Returns: True if connected and using WiFi interface
    ///
    /// ## Use Cases
    /// - Enable automatic backups only on WiFi
    /// - Allow high-quality video streaming
    /// - Trigger bulk data synchronization
    ///
    /// ## Example
    /// ```swift
    /// if monitor.isConnectedViaWiFi {
    ///     startCloudBackup()
    /// }
    /// ```
    var isConnectedViaWiFi: Bool {
        return isConnected && connectionType == .wifi
    }

    /// Whether the device is connected specifically via cellular
    /// - Returns: True if connected and using cellular interface
    ///
    /// ## Use Cases
    /// - Show data usage warnings
    /// - Reduce background sync frequency
    /// - Compress media before upload
    ///
    /// ## Example
    /// ```swift
    /// if monitor.isConnectedViaCellular && monitor.isExpensive {
    ///     showDataSaverMode()
    /// }
    /// ```
    var isConnectedViaCellular: Bool {
        return isConnected && connectionType == .cellular
    }

    /// Comprehensive network information string for debugging
    /// - Returns: Multi-line string with detailed network status
    ///
    /// ## Output Format
    /// ```
    /// Status: Connected
    /// Type: WiFi
    /// â€¢ Expensive connection
    /// â€¢ Constrained connection
    /// ```
    ///
    /// ## Usage
    /// Perfect for debug logs, network status displays, or troubleshooting:
    /// ```swift
    /// print("Network Info:\n\(monitor.networkInfo)")
    /// ```
    var networkInfo: String {
        var info = "Status: \(status.rawValue)"
        
        if isConnected {
            info += "\nType: \(connectionType.rawValue)"
            
            if isExpensive {
                info += "\nâ€¢ Expensive connection"
            }
            if isConstrained {
                info += "\nâ€¢ Constrained connection"
            }
        }
        
        return info
    }
}
