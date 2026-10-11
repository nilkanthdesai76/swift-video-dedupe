import Foundation

/// Real-time thermal management governor tailored for continuous video decoding on iOS & macOS.
/// Automatically regulates concurrent decoder threads and injects micro-pauses based on SoC telemetry.
public final class ThermalGovernor: @unchecked Sendable {
    public static let shared = ThermalGovernor()
    
    public typealias ThermalStateChangeHandler = @Sendable (ProcessInfo.ThermalState) -> Void
    
    private let lock = NSLock()
    private var observers: [UUID: ThermalStateChangeHandler] = [:]
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func thermalStateChanged() {
        let current = thermalState
        lock.lock()
        let handlers = Array(observers.values)
        lock.unlock()
        
        for handler in handlers {
            handler(current)
        }
    }
    
    /// Current hardware thermal state reported by iOS / macOS kernel.
    public var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    
    /// Recommended maximum concurrent video decoding operations.
    /// Video decoding involves hardware VideoToolbox blocks; keeping worker count low preserves battery and zero heat.
    public var recommendedConcurrency: Int {
        switch thermalState {
        case .nominal:
            return min(2, max(1, ProcessInfo.processInfo.activeProcessorCount / 4))
        case .fair:
            return 1
        case .serious:
            return 1
        case .critical:
            return 1
        @unknown default:
            return 1
        }
    }
    
    /// Paces video decoding dynamically if the hardware shows any sign of thermal elevation.
    public func applyThermalPacing() async {
        switch thermalState {
        case .nominal:
            // Device is completely cool: micro-yield allows system UI to maintain 120Hz ProMotion
            try? await Task.sleep(nanoseconds: 2_000_000) // 2ms
        case .fair:
            // Slight warmth: pause 15ms between videos
            try? await Task.sleep(nanoseconds: 15_000_000)
        case .serious:
            // Moderate heat: pause 120ms to allow passive heat dissipation
            try? await Task.sleep(nanoseconds: 120_000_000)
        case .critical:
            // High heat: pause 500ms for cool-down
            try? await Task.sleep(nanoseconds: 500_000_000)
        @unknown default:
            break
        }
    }
    
    /// Human-readable description of current thermal posture.
    public var thermalStatusDescription: String {
        switch thermalState {
        case .nominal:
            return "Nominal (Cold / Optimal)"
        case .fair:
            return "Fair (Warm - Pacing 15ms)"
        case .serious:
            return "Serious (Hot - Throttled)"
        case .critical:
            return "Critical (Paused for Cool-down)"
        @unknown default:
            return "Normal"
        }
    }
    
    @discardableResult
    public func addObserver(_ handler: @escaping ThermalStateChangeHandler) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        observers[id] = handler
        return id
    }
    
    public func removeObserver(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeValue(forKey: id)
    }
}
