import Foundation
#if canImport(Photos)
import Photos
#endif

/// Safe video deletion service utilizing Apple's PhotoKit change requests.
/// Trashing moves videos to the system "Recently Deleted" album with a native iOS confirmation prompt.
public enum VideoTrashService {
    
    public enum TrashError: LocalizedError {
        case photoKitUnavailable
        case authorizationDenied
        case assetsNotFound
        case deletionCancelled
        
        public var errorDescription: String? {
            switch self {
            case .photoKitUnavailable:
                return "PhotoKit is not available on this platform."
            case .authorizationDenied:
                return "Photo library access is not authorized."
            case .assetsNotFound:
                return "None of the specified video assets were found in the photo library."
            case .deletionCancelled:
                return "The video deletion was cancelled or rejected by the user."
            }
        }
    }
    
    #if canImport(Photos)
    /// Moves video assets to "Recently Deleted" by their local identifiers.
    @discardableResult
    public static func trashAssets(withLocalIdentifiers identifiers: [String]) async throws -> Bool {
        guard !identifiers.isEmpty else { return true }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw TrashError.authorizationDenied
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetchResult.count > 0 else {
            throw TrashError.assetsNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(fetchResult)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            })
        }
    }
    
    /// Trashes all non-keeper duplicates within a video cluster.
    @discardableResult
    public static func trashNonKeepers(in group: VideoDuplicateGroup) async throws -> Int {
        let nonKeeperIds = group.nonKeepers.map { $0.id }
        guard !nonKeeperIds.isEmpty else { return 0 }
        
        let success = try await trashAssets(withLocalIdentifiers: nonKeeperIds)
        return success ? nonKeeperIds.count : 0
    }
    #else
    @discardableResult
    public static func trashAssets(withLocalIdentifiers identifiers: [String]) async throws -> Bool {
        throw TrashError.photoKitUnavailable
    }
    #endif
}
