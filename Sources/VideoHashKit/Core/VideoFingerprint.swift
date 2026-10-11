import Foundation

/// Compact, multi-temporal perceptual fingerprint of a video.
/// Consists of normalized duration plus a sequence of keyframe DualHashes.
public struct VideoFingerprint: Hashable, Codable, Sendable {
    public let durationSeconds: Double
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let keyframeHashes: [DualHash]
    
    public init(
        durationSeconds: Double,
        pixelWidth: Int,
        pixelHeight: Int,
        keyframeHashes: [DualHash]
    ) {
        self.durationSeconds = durationSeconds
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.keyframeHashes = keyframeHashes
    }
    
    /// Human-friendly duration string (e.g. "0:45", "2:15").
    public var formattedDuration: String {
        let totalSeconds = Int(durationSeconds.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Short resolution label (e.g. "4K", "1080p", "720p").
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
    
    /// Computes the mean composite Hamming distance across corresponding keyframes.
    public func meanKeyframeDistance(to other: VideoFingerprint) -> Double {
        guard !self.keyframeHashes.isEmpty, !other.keyframeHashes.isEmpty else {
            return 128.0
        }
        
        let count = min(self.keyframeHashes.count, other.keyframeHashes.count)
        var totalDist = 0
        for i in 0..<count {
            totalDist += self.keyframeHashes[i].compositeDistance(to: other.keyframeHashes[i])
        }
        
        return Double(totalDist) / Double(count)
    }
    
    /// Absolute difference in video duration in seconds.
    public func durationDelta(to other: VideoFingerprint) -> Double {
        abs(self.durationSeconds - other.durationSeconds)
    }
    
    /// Ratio of shorter duration to longer duration (1.0 = identical length).
    public func durationRatio(to other: VideoFingerprint) -> Double {
        let maxD = max(self.durationSeconds, other.durationSeconds)
        guard maxD > 0 else { return 0 }
        let minD = min(self.durationSeconds, other.durationSeconds)
        return minD / maxD
    }
    
    /// Classifies the relationship between two video fingerprints into match tiers.
    public func matchCategory(to other: VideoFingerprint) -> VideoMatchCategory {
        let deltaDuration = durationDelta(to: other)
        let meanDist = meanKeyframeDistance(to: other)
        
        // Exact duplicate: Same duration (within 0.2s) and 0 perceptual distance
        if deltaDuration <= 0.2 && meanDist == 0 {
            return .exactDuplicate
        }
        
        // Near duplicate: Duration within 0.75s, mean composite distance <= 5 (transcoded/compressed)
        if deltaDuration <= 0.75 && meanDist <= 5.0 {
            return .nearDuplicate
        }
        
        // Similar video / alternate take: duration within 2.0s or ratio >= 0.85, mean composite distance <= 12.0
        if (deltaDuration <= 2.0 || durationRatio(to: other) >= 0.85) && meanDist <= 12.0 {
            return .similar
        }
        
        return .different
    }
    
    /// Normalized visual similarity score between 0.0 (unrelated) and 1.0 (identical).
    public func similarityScore(to other: VideoFingerprint) -> Double {
        let meanDist = meanKeyframeDistance(to: other)
        let score = max(0.0, min(1.0, 1.0 - (meanDist / 32.0)))
        return score
    }
}
