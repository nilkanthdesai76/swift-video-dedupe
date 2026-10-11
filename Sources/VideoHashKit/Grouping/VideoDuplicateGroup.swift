import Foundation

/// A grouped cluster of duplicate or similar videos.
public struct VideoDuplicateGroup: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let category: VideoMatchCategory
    public let assets: [VideoAssetSnapshot]
    public let bestAssetId: String
    public let similarityScore: Double
    public let reclaimableSize: Int64
    public let totalSize: Int64
    
    public init(
        id: String = UUID().uuidString,
        category: VideoMatchCategory,
        assets: [VideoAssetSnapshot],
        bestAssetId: String,
        similarityScore: Double
    ) {
        self.id = id
        self.category = category
        self.assets = assets
        self.bestAssetId = bestAssetId
        self.similarityScore = similarityScore
        
        let total = assets.reduce(Int64(0)) { $0 + $1.fileSize }
        self.totalSize = total
        
        let reclaimable = assets
            .filter { $0.id != bestAssetId }
            .reduce(Int64(0)) { $0 + $1.fileSize }
        self.reclaimableSize = reclaimable
    }
    
    public var duplicateCount: Int {
        max(0, assets.count - 1)
    }
    
    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimableSize, countStyle: .file)
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var keeper: VideoAssetSnapshot? {
        assets.first { $0.id == bestAssetId }
    }
    
    public var nonKeepers: [VideoAssetSnapshot] {
        assets.filter { $0.id != bestAssetId }
    }
}

/// Comprehensive video scan outcome metadata.
public struct VideoDedupeScanResult: Codable, Sendable {
    public let scannedAt: Date
    public let durationSec: Double
    public let totalScanned: Int
    public var groups: [VideoDuplicateGroup]
    public let peakThermalState: String
    
    public init(
        scannedAt: Date = Date(),
        durationSec: Double,
        totalScanned: Int,
        groups: [VideoDuplicateGroup],
        peakThermalState: String = "Nominal"
    ) {
        self.scannedAt = scannedAt
        self.durationSec = durationSec
        self.totalScanned = totalScanned
        self.groups = groups
        self.peakThermalState = peakThermalState
    }
    
    public var totalGroups: Int {
        groups.count
    }
    
    public var exactDuplicatesCount: Int {
        groups.filter { $0.category == .exactDuplicate }.reduce(0) { $0 + $1.duplicateCount }
    }
    
    public var nearDuplicatesCount: Int {
        groups.filter { $0.category == .nearDuplicate }.reduce(0) { $0 + $1.duplicateCount }
    }
    
    public var similarCount: Int {
        groups.filter { $0.category == .similar }.reduce(0) { $0 + $1.duplicateCount }
    }
    
    public var totalReclaimableBytes: Int64 {
        groups.reduce(Int64(0)) { $0 + $1.reclaimableSize }
    }
    
    public var totalReclaimableSize: Int64 {
        totalReclaimableBytes
    }
    
    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
    }
    
    public var videosPerSecond: Double {
        durationSec > 0 ? Double(totalScanned) / durationSec : 0
    }
}
