import Foundation
import VideoHashKit

print("===================================================================")
print("  🎥 VideoHashKit CLI — Zero-Thermal Video Duplicate Engine")
print("  Temporal dHash + pHash Fingerprinting • Sublinear Multi-Index")
print("===================================================================")

let startTime = Date()
print("\n[1/3] Generating synthetic video benchmark collection...")
let dataset = SampleVideoGenerator.createBenchmarkDataset()
print("  Generated \(dataset.count) simulated videos (4K, 1080p, WhatsApp re-encodes, and burst takes).")

print("\n[2/3] Clustering videos using Multi-Index Pigeonhole Hashing & DSU...")
let clusterStart = Date()
let groups = VideoDuplicateGrouper.group(assets: dataset)
let clusterTime = Date().timeIntervalSince(clusterStart)

print(String(format: "  Clustered in %.4f seconds.", clusterTime))

print("\n[3/3] Duplicate Findings:")
var totalReclaimable: Int64 = 0

for (i, group) in groups.enumerated() {
    print("-------------------------------------------------------------------")
    print(" Cluster #\(i + 1): [\(group.category.rawValue.uppercased())] - Similarity: \(Int(group.similarityScore * 100))%")
    print(" Reclaimable: \(group.formattedReclaimableSize) (Total Cluster Size: \(group.formattedTotalSize))")
    print(" Keeper: \(group.bestAssetId)")
    print(" Videos in cluster:")
    for asset in group.assets {
        let isKeeper = asset.id == group.bestAssetId
        print("   \(isKeeper ? "⭐ [KEEPER]" : "   [REMOVE]") \(asset.filename) | \(asset.resolutionLabel) | \(asset.formattedDuration) | \(asset.formattedSize)")
    }
    totalReclaimable += group.reclaimableSize
}

print("===================================================================")
let formattedTotal = ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file)
print("  🎉 Summary: Found \(groups.count) clusters.")
print("  💾 Total Reclaimable Video Storage: \(formattedTotal)")
print(String(format: "  ⏱️ Total Execution Time: %.3f seconds", Date().timeIntervalSince(startTime)))
print("  ❄️ Thermal State: \(ThermalGovernor.shared.thermalStatusDescription)")
print("===================================================================")
