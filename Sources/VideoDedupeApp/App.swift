import SwiftUI
import VideoHashKit

@main
struct VideoDedupeApp: App {
    var body: some Scene {
        WindowGroup {
            MacOSVideoDedupeView()
        }
        .windowStyle(.titleBar)
    }
}

struct MacOSVideoDedupeView: View {
    @State private var result: VideoDedupeScanResult?
    @State private var isScanning = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Dedupe macOS")
                        .font(.title2.bold())
                    Text("Zero-thermal temporal perceptual hashing engine.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Run Synthetic Benchmark") {
                    runBenchmark()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            if let scanResult = result {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Reclaimable Storage: \(scanResult.formattedReclaimableSize)")
                            .font(.headline)
                        Spacer()
                        Text("Clusters: \(scanResult.totalGroups)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    List(scanResult.groups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(group.category.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                                
                                Spacer()
                                
                                Text("Reclaim \(group.formattedReclaimableSize)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(group.assets) { asset in
                                HStack {
                                    Text(asset.id == group.bestAssetId ? "⭐ [KEEPER]" : "   [TRASH]")
                                        .font(.caption.monospaced())
                                        .foregroundColor(asset.id == group.bestAssetId ? .green : .red)
                                    Text(asset.filename)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(asset.resolutionLabel) • \(asset.formattedDuration) • \(asset.formattedSize)")
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal)
            } else {
                Spacer()
                Text("Click 'Run Synthetic Benchmark' to test video deduplication.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .onAppear {
            runBenchmark()
        }
    }
    
    private func runBenchmark() {
        let dataset = SampleVideoGenerator.createBenchmarkDataset()
        let start = Date()
        let groups = VideoDuplicateGrouper.group(assets: dataset)
        let elapsed = Date().timeIntervalSince(start)
        
        self.result = VideoDedupeScanResult(
            scannedAt: Date(),
            durationSec: elapsed,
            totalScanned: dataset.count,
            groups: groups,
            peakThermalState: ThermalGovernor.shared.thermalStatusDescription
        )
    }
}
