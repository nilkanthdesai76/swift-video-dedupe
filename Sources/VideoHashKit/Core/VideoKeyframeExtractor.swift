import Foundation
import AVFoundation
import CoreGraphics

/// Hardware-accelerated sparse keyframe extractor using AVFoundation.
/// Decodes directly to tiny 64x64 surfaces via Apple Silicon's hardware media engine,
/// bypassing full-frame 4K/1080p memory allocations to prevent heat build-up.
public enum VideoKeyframeExtractor {
    
    /// Default normalized timestamp anchors across video duration (avoids fade-in/fade-out black frames).
    public static let defaultNormalizedTimestamps: [Double] = [0.15, 0.38, 0.62, 0.85]
    
    /// Extracts DualHash fingerprints for keyframes of an AVAsset.
    public static func extractKeyframeHashes(
        from asset: AVAsset,
        normalizedPositions: [Double] = defaultNormalizedTimestamps
    ) async throws -> (durationSeconds: Double, width: Int, height: Int, hashes: [DualHash]) {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 && !durationSeconds.isNaN else {
            throw VideoExtractError.invalidDuration
        }
        
        // Load natural video dimensions
        var width = 1920
        var height = 1080
        if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
            if let naturalSize = try? await videoTrack.load(.naturalSize) {
                width = Int(naturalSize.width)
                height = Int(naturalSize.height)
            }
        }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // Force hardware decoder to output directly at 64x64 thumbnail resolution
        generator.maximumSize = CGSize(width: 64, height: 64)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        let positions: [Double]
        if durationSeconds <= 2.0 {
            positions = [0.5] // Short clip: single anchor frame
        } else {
            positions = normalizedPositions
        }
        
        var hashes: [DualHash] = []
        hashes.reserveCapacity(positions.count)
        
        for pos in positions {
            let targetSeconds = max(0.05, min(durationSeconds - 0.05, durationSeconds * pos))
            let cmTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
            
            do {
                let (cgImage, _) = try await generator.image(at: cmTime)
                let dualHash = DualHash.compute(from: cgImage)
                hashes.append(dualHash)
            } catch {
                // If a specific frame fails, insert a blank/neutral fingerprint so sequence length remains aligned
                hashes.append(DualHash(dHash: 0, pHash: 0))
            }
        }
        
        return (durationSeconds, width, height, hashes)
    }
    
    /// Convenience method to extract keyframes directly from a file URL.
    public static func extractKeyframeHashes(
        from fileURL: URL,
        normalizedPositions: [Double] = defaultNormalizedTimestamps
    ) async throws -> (durationSeconds: Double, width: Int, height: Int, hashes: [DualHash]) {
        let asset = AVURLAsset(url: fileURL)
        return try await extractKeyframeHashes(from: asset, normalizedPositions: normalizedPositions)
    }
    
    public enum VideoExtractError: LocalizedError {
        case invalidDuration
        case tracksUnavailable
        case decodingFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidDuration:
                return "Video has zero or invalid duration."
            case .tracksUnavailable:
                return "No readable video tracks found in asset."
            case .decodingFailed:
                return "Failed to decode video keyframes."
            }
        }
    }
}
