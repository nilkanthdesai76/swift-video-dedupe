import SwiftUI
import VideoHashKit

/// Primary container view for the VideoHashKit iOS Demo App.
struct DemoContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                VideoDedupeIOSView()
            }
            .tabItem {
                Label("Video Dedupe", systemImage: "film.stack.fill")
            }
            .tag(0)
            
            NavigationStack {
                VideoAlgorithmLabView()
            }
            .tabItem {
                Label("Algorithm Lab", systemImage: "cpu.fill")
            }
            .tag(1)
        }
    }
}

/// Interactive testing environment for exploring the math and performance behind VideoHashKit.
struct VideoAlgorithmLabView: View {
    @State private var benchmarkStats: String = "Tap 'Run Speed Test' to benchmark."
    @State private var isBenchmarking = false
    @State private var sampleFp1: VideoFingerprint?
    @State private var sampleFp2: VideoFingerprint?
    @State private var sampleTier: VideoMatchCategory?
    
    var body: some View {
        List {
            Section("Hardware Thermal Telemetry") {
                HStack {
                    Text("Kernel Thermal State")
                    Spacer()
                    Text(ThermalGovernor.shared.thermalStatusDescription)
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Active CPU Cores")
                    Spacer()
                    Text("\(ProcessInfo.processInfo.activeProcessorCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Recommended Concurrency")
                    Spacer()
                    Text("\(ThermalGovernor.shared.recommendedConcurrency) threads")
                        .foregroundColor(.blue)
                }
            }
            
            Section("Temporal Video Hashing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test 2 Synthetic Video Takes")
                        .font(.headline)
                    
                    Button {
                        computeSampleVideoHashes()
                    } label: {
                        Label("Compare Video Fingerprints", systemImage: "waveform.path")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if let f1 = sampleFp1, let f2 = sampleFp2, let tier = sampleTier {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Video A: \(f1.formattedDuration) • \(f1.resolutionLabel) (4 keyframes)")
                                .font(.caption.bold())
                            Text("Video B: \(f2.formattedDuration) • \(f2.resolutionLabel) (4 keyframes)")
                                .font(.caption.bold())
                            
                            Divider()
                            
                            Text("Duration Delta: \(String(format: "%.2f", f1.durationDelta(to: f2)))s")
                                .font(.caption.monospaced())
                            Text("Mean Keyframe Distance: \(String(format: "%.1f", f1.meanKeyframeDistance(to: f2))) bits")
                                .font(.caption.monospaced())
                            Text("Similarity: \(Int(f1.similarityScore(to: f2) * 100))%")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Classified Tier:")
                                    .font(.subheadline)
                                Text(tier.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(tierColor(for: tier))
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Clustering Throughput Benchmark") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Benchmarks Multi-Index Hashing & DSU clustering on simulated video datasets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        runBenchmark()
                    } label: {
                        HStack {
                            if isBenchmarking {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(isBenchmarking ? "Benchmarking..." : "Run Speed Test")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBenchmarking)
                    
                    Text(benchmarkStats)
                        .font(.footnote.monospaced())
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            
            Section("About") {
                Text("VideoHashKit Demo App")
                    .font(.footnote)
                Text("Zero-thermal temporal perceptual video duplicate engine for iOS.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Algorithm Lab")
    }
    
    private func computeSampleVideoHashes() {
        let dataset = SampleVideoGenerator.createBenchmarkDataset()
        guard dataset.count >= 5 else { return }
        
        let f1 = dataset[3].fingerprint ?? VideoFingerprint(durationSeconds: 12.8, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: [])
        let f2 = dataset[4].fingerprint ?? VideoFingerprint(durationSeconds: 12.9, pixelWidth: 1280, pixelHeight: 720, keyframeHashes: [])
        
        self.sampleFp1 = f1
        self.sampleFp2 = f2
        self.sampleTier = f1.matchCategory(to: f2)
    }
    
    private func runBenchmark() {
        isBenchmarking = true
        benchmarkStats = "Clustering 100 benchmark batches..."
        
        Task {
            let start = Date()
            let dataset = SampleVideoGenerator.createBenchmarkDataset()
            for _ in 0..<100 {
                _ = VideoDuplicateGrouper.group(assets: dataset)
            }
            let elapsed = Date().timeIntervalSince(start)
            let totalVideos = dataset.count * 100
            let rate = Double(totalVideos) / elapsed
            
            await MainActor.run {
                self.isBenchmarking = false
                self.benchmarkStats = "Clustered \(totalVideos) videos in \(String(format: "%.3f", elapsed))s (\(Int(rate)) videos/sec) with zero heat."
            }
        }
    }
    
    private func tierColor(for tier: VideoMatchCategory) -> Color {
        switch tier {
        case .exactDuplicate: return .red
        case .nearDuplicate: return .orange
        case .similar: return .blue
        case .different: return .gray
        }
    }
}
