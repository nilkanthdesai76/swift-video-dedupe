import Foundation
import CoreGraphics
#if canImport(Photos)
import Photos
#endif
import AVFoundation

/// Zero-thermal video library scanner.
/// Extracts multi-temporal 64x64 keyframes directly through the hardware media engine
/// without loading uncompressed video frames into memory, and skips high-bandwidth iCloud downloads.
public final class VideoLibraryScanner: @unchecked Sendable {
    
    public init() {}
    
    #if canImport(Photos)
    /// Scans the system Photo Library for duplicate and similar videos.
    public func scanVideoLibrary(
        includeSimilar: Bool = true,
        progressHandler: (@Sendable (VideoScanProgress) -> Void)? = nil
    ) async -> VideoDedupeScanResult {
        let startTime = Date()
        let governor = ThermalGovernor.shared
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        let totalCount = fetchResult.count
        
        guard totalCount > 0 else {
            return VideoDedupeScanResult(
                scannedAt: Date(),
                durationSec: 0,
                totalScanned: 0,
                groups: [],
                peakThermalState: governor.thermalStatusDescription
            )
        }
        
        var snapshots: [VideoAssetSnapshot] = []
        snapshots.reserveCapacity(totalCount)
        
        var peakThermal = governor.thermalState
        
        for index in 0..<totalCount {
            let phAsset = fetchResult.object(at: index)
            let localId = phAsset.localIdentifier
            
            // Check thermal state and pace
            let currentThermal = governor.thermalState
            if currentThermal.rawValue > peakThermal.rawValue {
                peakThermal = currentThermal
            }
            await governor.applyThermalPacing()
            
            // Extract filename and resource size
            var filename = "video_\(index).mov"
            var fileSize: Int64 = 0
            var isLocallyAvailable = true
            
            let resources = PHAssetResource.assetResources(for: phAsset)
            if let videoRes = resources.first(where: { $0.type == .video }) ?? resources.first {
                filename = videoRes.originalFilename
                if let sizeVal = videoRes.value(forKey: "fileSize") as? Int64 {
                    fileSize = sizeVal
                }
                if let locVal = videoRes.value(forKey: "locallyAvailable") as? Bool {
                    isLocallyAvailable = locVal
                }
            }
            
            // Extract AVAsset and keyframes
            let fingerprint = await extractFingerprint(for: phAsset, isLocal: isLocallyAvailable)
            
            let snapshot = VideoAssetSnapshot(
                id: localId,
                filename: filename,
                durationSeconds: phAsset.duration,
                creationDate: phAsset.creationDate ?? Date(),
                pixelWidth: phAsset.pixelWidth,
                pixelHeight: phAsset.pixelHeight,
                fileSize: fileSize > 0 ? fileSize : Int64(phAsset.duration * 2_500_000), // ~20 Mbps fallback estimate
                isFavorite: phAsset.isFavorite,
                isLocallyAvailable: isLocallyAvailable,
                fingerprint: fingerprint
            )
            snapshots.append(snapshot)
            
            if let handler = progressHandler {
                let progress = VideoScanProgress(
                    processed: index + 1,
                    total: totalCount,
                    currentFilename: filename,
                    thermalState: governor.thermalStatusDescription,
                    currentGroupCount: 0
                )
                handler(progress)
            }
        }
        
        // Group the snapshots
        let groups = VideoDuplicateGrouper.group(assets: snapshots, includeSimilar: includeSimilar)
        let duration = Date().timeIntervalSince(startTime)
        
        return VideoDedupeScanResult(
            scannedAt: Date(),
            durationSec: duration,
            totalScanned: totalCount,
            groups: groups,
            peakThermalState: governor.thermalStatusDescription
        )
    }
    
    private func extractFingerprint(for phAsset: PHAsset, isLocal: Bool) async -> VideoFingerprint? {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false // strictly avoid huge cellular/Wi-Fi downloads
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, _, _ in
                guard let avAsset = asset else {
                    continuation.resume(returning: nil)
                    return
                }
                
                Task {
                    do {
                        let (dur, w, h, hashes) = try await VideoKeyframeExtractor.extractKeyframeHashes(from: avAsset)
                        let fp = VideoFingerprint(
                            durationSeconds: dur,
                            pixelWidth: w,
                            pixelHeight: h,
                            keyframeHashes: hashes
                        )
                        continuation.resume(returning: fp)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    #endif
}
