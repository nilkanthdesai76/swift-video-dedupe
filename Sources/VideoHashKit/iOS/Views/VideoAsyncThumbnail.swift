#if os(iOS)
import SwiftUI
#if canImport(Photos)
import Photos
#endif

/// Asynchronous video poster thumbnail view with duration overlay.
public struct VideoAsyncThumbnail: View {
    public let localIdentifier: String
    public let durationText: String
    @State private var image: PlatformImage?
    
    public init(localIdentifier: String, durationText: String = "") {
        self.localIdentifier = localIdentifier
        self.durationText = durationText
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
            }
            
            // Duration pill
            if !durationText.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                    Text(durationText)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.65))
                .cornerRadius(4)
                .padding(4)
            }
        }
        .task(id: localIdentifier) {
            #if canImport(Photos)
            self.image = await VideoThumbnailLoader.shared.loadThumbnail(for: localIdentifier)
            #endif
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Color.dedupeChipBackground
            Image(systemName: "video")
                .foregroundColor(.secondary)
                .font(.title3)
        }
    }
}
#endif
