import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif
import Combine

/// Manages PhotoKit authorization states for videos on iOS and macOS.
@MainActor
public final class VideoPermissionManager: ObservableObject {
    
    public static let shared = VideoPermissionManager()
    
    #if canImport(Photos)
    @Published public private(set) var status: PHAuthorizationStatus = .notDetermined
    #else
    @Published public private(set) var status: Int = 0
    #endif
    
    public init() {
        #if canImport(Photos)
        self.status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        #endif
    }
    
    /// True if the app has full or limited access to the photo library.
    public var hasAccess: Bool {
        #if canImport(Photos)
        return status == .authorized || status == .limited
        #else
        return true
        #endif
    }
    
    /// Requests photo library authorization from the user.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        #if canImport(Photos)
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            self.status = current
            return true
        }
        
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.status = newStatus
        return newStatus == .authorized || newStatus == .limited
        #else
        return true
        #endif
    }
    
    #if canImport(UIKit) && canImport(PhotosUI)
    /// Presents the iOS system photo/video picker for users with `.limited` photo library access.
    public func presentLimitedLibraryPicker(from viewController: UIViewController) {
        #if canImport(Photos)
        guard status == .limited else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
        #endif
    }
    #endif
}
