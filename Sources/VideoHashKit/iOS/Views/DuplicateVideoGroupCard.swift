#if os(iOS)
import SwiftUI

/// An iOS card displaying a cluster of duplicate or similar videos.
public struct DuplicateVideoGroupCard: View {
    public let group: VideoDuplicateGroup
    public let onSelectKeeper: (String) -> Void
    public let onCompare: () -> Void
    public let onTrashGroup: () -> Void
    
    public init(
        group: VideoDuplicateGroup,
        onSelectKeeper: @escaping (String) -> Void,
        onCompare: @escaping () -> Void,
        onTrashGroup: @escaping () -> Void
    ) {
        self.group = group
        self.onSelectKeeper = onSelectKeeper
        self.onCompare = onCompare
        self.onTrashGroup = onTrashGroup
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Category badge + Reclaimable size + Compare button
            HStack {
                categoryBadge
                
                Spacer()
                
                Text("Reclaim \(group.formattedReclaimableSize)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.dedupeSubBackground)
                    .cornerRadius(8)
                
                Button(action: onCompare) {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
            }
            
            // Horizontal scrolling video thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.assets) { asset in
                        videoCell(for: asset)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Footer: Trash duplicates action
            HStack {
                Text("\(group.duplicateCount) duplicate video\(group.duplicateCount == 1 ? "" : "s") to remove")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(role: .destructive, action: onTrashGroup) {
                    Label("Clean Duplicates", systemImage: "trash")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.dedupeCardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Subviews
    
    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
            Text(badgeText)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .foregroundColor(badgeColor)
        .cornerRadius(8)
    }
    
    private var badgeColor: Color {
        switch group.category {
        case .exactDuplicate: return .red
        case .nearDuplicate: return .orange
        case .similar: return .blue
        case .different: return .gray
        }
    }
    
    private var badgeIcon: String {
        switch group.category {
        case .exactDuplicate: return "film.stack.fill"
        case .nearDuplicate: return "sparkles.tv"
        case .similar: return "video.badge.plus"
        case .different: return "video"
        }
    }
    
    private var badgeText: String {
        switch group.category {
        case .exactDuplicate: return "Exact (100%)"
        case .nearDuplicate: return "Near (\(Int(group.similarityScore * 100))%)"
        case .similar: return "Similar / Scene"
        case .different: return "Distinct"
        }
    }
    
    private func videoCell(for asset: VideoAssetSnapshot) -> some View {
        let isKeeper = asset.id == group.bestAssetId
        
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                VideoAsyncThumbnail(localIdentifier: asset.id, durationText: asset.formattedDuration)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isKeeper ? Color.green : Color.clear, lineWidth: 3)
                    )
                
                if isKeeper {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white).padding(2))
                        .offset(x: -4, y: 4)
                        .font(.caption)
                }
            }
            
            // Resolution & size labels
            HStack(spacing: 4) {
                Text(asset.resolutionLabel)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.dedupeSubBackground)
                    .cornerRadius(4)
                
                Text(asset.formattedSize)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Keeper toggle button
            Button {
                onSelectKeeper(asset.id)
            } label: {
                Text(isKeeper ? "Keeper" : "Keep")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isKeeper ? .white : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(isKeeper ? Color.green : Color.dedupeChipBackground)
                    .cornerRadius(6)
            }
            .buttonStyle(.borderless)
        }
    }
}
#endif
