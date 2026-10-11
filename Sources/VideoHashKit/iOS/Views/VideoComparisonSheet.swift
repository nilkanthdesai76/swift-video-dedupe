#if os(iOS)
import SwiftUI
#if canImport(Photos)
import Photos
#endif

/// Side-by-side video comparison sheet allowing users to compare duplicate videos,
/// inspect EXIF resolution, duration, bitrate differences, and select the optimal keeper.
public struct VideoComparisonSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let group: VideoDuplicateGroup
    public let onSelectKeeper: (String) -> Void
    public let onTrashGroup: () -> Void
    
    @State private var selectedAssetId: String
    
    public init(
        group: VideoDuplicateGroup,
        onSelectKeeper: @escaping (String) -> Void,
        onTrashGroup: @escaping () -> Void
    ) {
        self.group = group
        self.onSelectKeeper = onSelectKeeper
        self.onTrashGroup = onTrashGroup
        self._selectedAssetId = State(initialValue: group.bestAssetId)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video carousel / preview
                TabView(selection: $selectedAssetId) {
                    ForEach(group.assets) { asset in
                        VStack(spacing: 12) {
                            VideoAsyncThumbnail(localIdentifier: asset.id, durationText: asset.formattedDuration)
                                .frame(maxWidth: .infinity)
                                .frame(height: 320)
                                .clipped()
                                .cornerRadius(16)
                                .shadow(radius: 4)
                                .tag(asset.id)
                            
                            // Info card for current video
                            videoInfoCard(for: asset)
                        }
                        .padding(.horizontal)
                        .tag(asset.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // Bottom Action Bar
                HStack(spacing: 16) {
                    Button {
                        onSelectKeeper(selectedAssetId)
                    } label: {
                        let isKeeper = selectedAssetId == group.bestAssetId
                        Label(
                            isKeeper ? "Current Keeper" : "Set as Keeper",
                            systemImage: isKeeper ? "checkmark.circle.fill" : "star.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selectedAssetId == group.bestAssetId ? .green : .blue)
                    .controlSize(.large)
                    
                    Button(role: .destructive) {
                        onTrashGroup()
                        dismiss()
                    } label: {
                        Label("Trash Duplicates", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
                .background(Color.dedupeMainBackground)
            }
            .navigationTitle("Compare Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func videoInfoCard(for asset: VideoAssetSnapshot) -> some View {
        let isKeeper = asset.id == group.bestAssetId
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isKeeper ? "⭐ Best Pick (Keeper)" : "Duplicate Video")
                    .font(.subheadline.bold())
                    .foregroundColor(isKeeper ? .green : .secondary)
                
                Spacer()
                
                if asset.isFavorite {
                    Label("Favorited", systemImage: "heart.fill")
                        .font(.caption.bold())
                        .foregroundColor(.pink)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resolution")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(asset.pixelWidth) × \(asset.pixelHeight) (\(asset.resolutionLabel))")
                        .font(.caption.monospaced())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(asset.formattedDuration)
                        .font(.caption.monospaced())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("File Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(asset.formattedSize)
                        .font(.caption.monospaced())
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Captured")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(asset.creationDate.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color.dedupeCardBackground)
        .cornerRadius(12)
    }
}
#endif
