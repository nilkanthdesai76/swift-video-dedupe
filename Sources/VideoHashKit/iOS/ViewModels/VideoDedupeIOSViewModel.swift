import Foundation
import Combine
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Complete iOS ViewModel for managing video library scanning, duplicate grouping, keeper selection, and trashing.
@MainActor
public final class VideoDedupeIOSViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isScanning = false
    @Published public var scanProgress: VideoScanProgress?
    @Published public var scanResult: VideoDedupeScanResult?
    @Published public var selectedFilter: VideoMatchCategory? = nil
    @Published public var errorMessage: String?
    @Published public var isTrashing = false
    @Published public var thermalDescription: String = "Nominal"
    
    private let permissionManager = VideoPermissionManager.shared
    private let scanner = VideoLibraryScanner()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.thermalDescription = ThermalGovernor.shared.thermalStatusDescription
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    public var filteredGroups: [VideoDuplicateGroup] {
        guard let result = scanResult else { return [] }
        if let filter = selectedFilter {
            return result.groups.filter { $0.category == filter }
        }
        return result.groups
    }
    
    public var totalReclaimableSize: Int64 {
        scanResult?.totalReclaimableSize ?? 0
    }
    
    public var formattedReclaimableSize: String {
        scanResult?.formattedReclaimableSize ?? "0 B"
    }
    
    // MARK: - Scanning
    
    /// Starts real PhotoKit video library scanning with hardware thermal throttling.
    public func startLibraryScan(includeSimilar: Bool = true) async {
        guard !isScanning else { return }
        
        let hasAccess = await permissionManager.requestAuthorization()
        guard hasAccess else {
            self.errorMessage = "Video library access is required to find duplicates."
            return
        }
        
        self.isScanning = true
        self.errorMessage = nil
        self.scanProgress = nil
        
        #if canImport(Photos)
        let result = await scanner.scanVideoLibrary(includeSimilar: includeSimilar) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.scanProgress = progress
            }
        }
        
        self.scanResult = result
        self.isScanning = false
        
        #if canImport(UIKit)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        #endif
        #endif
    }
    
    /// Runs the built-in synthetic benchmark dataset for instant testing without touching user videos.
    public func runSyntheticBenchmark() {
        self.isScanning = true
        self.errorMessage = nil
        
        let startTime = Date()
        let dataset = SampleVideoGenerator.createBenchmarkDataset()
        let groups = VideoDuplicateGrouper.group(assets: dataset)
        let duration = Date().timeIntervalSince(startTime)
        
        self.scanResult = VideoDedupeScanResult(
            scannedAt: Date(),
            durationSec: duration,
            totalScanned: dataset.count,
            groups: groups,
            peakThermalState: ThermalGovernor.shared.thermalStatusDescription
        )
        self.isScanning = false
        
        #if canImport(UIKit)
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        #endif
    }
    
    // MARK: - Keeper Modification
    
    /// Updates the designated keeper for a duplicate group.
    public func setKeeper(groupId: String, newKeeperId: String) {
        guard var result = scanResult,
              let groupIndex = result.groups.firstIndex(where: { $0.id == groupId }) else {
            return
        }
        
        let oldGroup = result.groups[groupIndex]
        let updatedGroup = VideoDuplicateGroup(
            id: oldGroup.id,
            category: oldGroup.category,
            assets: oldGroup.assets,
            bestAssetId: newKeeperId,
            similarityScore: oldGroup.similarityScore
        )
        
        result.groups[groupIndex] = updatedGroup
        self.scanResult = result
        
        #if canImport(UIKit)
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
        #endif
    }
    
    // MARK: - Video Trashing
    
    /// Moves non-keepers of a specific duplicate group to Recently Deleted.
    public func trashDuplicates(in group: VideoDuplicateGroup) async {
        guard !isTrashing else { return }
        self.isTrashing = true
        
        do {
            #if canImport(Photos)
            _ = try await VideoTrashService.trashNonKeepers(in: group)
            #endif
            
            if var result = scanResult {
                result.groups.removeAll { $0.id == group.id }
                self.scanResult = result
            }
            
            #if canImport(UIKit)
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            #endif
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isTrashing = false
    }
    
    /// Moves all non-keepers across all groups to Recently Deleted.
    public func trashAllDuplicates() async {
        guard let result = scanResult, !result.groups.isEmpty, !isTrashing else { return }
        self.isTrashing = true
        
        var allNonKeeperIds: [String] = []
        for group in result.groups {
            allNonKeeperIds.append(contentsOf: group.nonKeepers.map { $0.id })
        }
        
        do {
            #if canImport(Photos)
            try await VideoTrashService.trashAssets(withLocalIdentifiers: allNonKeeperIds)
            #endif
            
            var updated = result
            updated.groups.removeAll()
            self.scanResult = updated
            
            #if canImport(UIKit)
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            #endif
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isTrashing = false
    }
}
