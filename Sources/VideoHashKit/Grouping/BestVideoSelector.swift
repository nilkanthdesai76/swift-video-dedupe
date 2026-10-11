import Foundation

/// Heuristic engine to automatically select the optimal video to keep from a cluster of duplicates.
public enum BestVideoSelector {
    
    /// Evaluates video candidates and picks the highest-quality original.
    public static func pickKeeper(from assets: [VideoAssetSnapshot]) -> VideoAssetSnapshot? {
        guard !assets.isEmpty else { return nil }
        if assets.count == 1 { return assets[0] }
        
        return assets.max { a, b in
            // 1. Favorited videos strictly take priority
            if a.isFavorite != b.isFavorite {
                return !a.isFavorite && b.isFavorite
            }
            
            // 2. Higher resolution (e.g. 4K over 1080p, 1080p over 720p)
            let pixelsA = a.pixelWidth * a.pixelHeight
            let pixelsB = b.pixelWidth * b.pixelHeight
            if abs(pixelsA - pixelsB) > 50_000 {
                return pixelsA < pixelsB
            }
            
            // 3. Completeness: Longer duration takes priority over truncated/trimmed snippet
            if abs(a.durationSeconds - b.durationSeconds) > 0.5 {
                return a.durationSeconds < b.durationSeconds
            }
            
            // 4. Higher file size (preserves original bitrate vs compressed re-encodes)
            if abs(a.fileSize - b.fileSize) > 100_000 {
                return a.fileSize < b.fileSize
            }
            
            // 5. Older creation date (original capture precedes downloaded copy)
            return a.creationDate > b.creationDate
        }
    }
}
