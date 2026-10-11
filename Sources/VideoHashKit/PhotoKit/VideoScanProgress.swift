import Foundation

/// Progress telemetry during video library scanning.
public struct VideoScanProgress: Sendable {
    public let processed: Int
    public let total: Int
    public let currentFilename: String
    public let thermalState: String
    public let currentGroupCount: Int
    
    public init(
        processed: Int,
        total: Int,
        currentFilename: String,
        thermalState: String,
        currentGroupCount: Int
    ) {
        self.processed = processed
        self.total = total
        self.currentFilename = currentFilename
        self.thermalState = thermalState
        self.currentGroupCount = currentGroupCount
    }
    
    public var processedCount: Int { processed }
    public var totalCount: Int { total }
    
    public var fractionCompleted: Double {
        total > 0 ? Double(processed) / Double(total) : 0
    }
}
