import Foundation
import CoreGraphics
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Asynchronous, memory-bounded video poster thumbnail loader.
public final class VideoThumbnailLoader: @unchecked Sendable {
    
    public static let shared = VideoThumbnailLoader()
    
    private let cache = NSCache<NSString, PlatformImage>()
    
    public init() {
        cache.countLimit = 150 // Keep max 150 video posters in memory
        cache.totalCostLimit = 40 * 1024 * 1024 // 40MB memory ceiling
    }
    
    #if canImport(Photos)
    /// Loads a video thumbnail poster frame for a given PhotoKit local identifier.
    public func loadThumbnail(
        for localIdentifier: String,
        targetSize: CGSize = CGSize(width: 160, height: 160)
    ) async -> PlatformImage? {
        let cacheKey = "\(localIdentifier)_\(Int(targetSize.width))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true // allow cached local iCloud thumbnail poster
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    self.cache.setObject(image, forKey: cacheKey)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif
    
    public func clearCache() {
        cache.removeAllObjects()
    }
}
