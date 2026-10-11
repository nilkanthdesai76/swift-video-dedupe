import Foundation
#if canImport(Photos)
import Photos
#endif

/// Lightweight metadata snapshot of a video in the user's library or filesystem.
public struct VideoAssetSnapshot: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let filename: String
    public let durationSeconds: Double
    public let creationDate: Date
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let fileSize: Int64
    public let isFavorite: Bool
    public let isLocallyAvailable: Bool
    public let fingerprint: VideoFingerprint?
    
    public init(
        id: String,
        filename: String,
        durationSeconds: Double,
        creationDate: Date = Date(),
        pixelWidth: Int,
        pixelHeight: Int,
        fileSize: Int64,
        isFavorite: Bool = false,
        isLocallyAvailable: Bool = true,
        fingerprint: VideoFingerprint? = nil
    ) {
        self.id = id
        self.filename = filename
        self.durationSeconds = durationSeconds
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.isFavorite = isFavorite
        self.isLocallyAvailable = isLocallyAvailable
        self.fingerprint = fingerprint
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var formattedDuration: String {
        let totalSeconds = Int(durationSeconds.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var resolutionLabel: String {
        let maxDim = max(pixelWidth, pixelHeight)
        if maxDim >= 3840 {
            return "4K"
        } else if maxDim >= 1920 {
            return "1080p"
        } else if maxDim >= 1280 {
            return "720p"
        } else {
            return "\(pixelWidth)×\(pixelHeight)"
        }
    }
}
