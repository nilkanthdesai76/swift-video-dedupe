import Foundation

/// Generator for synthetic video benchmark datasets.
/// Simulates realistic video durations, resolutions, file sizes, and multi-temporal keyframe fingerprints.
public enum SampleVideoGenerator {
    
    public static func createBenchmarkDataset() -> [VideoAssetSnapshot] {
        var dataset: [VideoAssetSnapshot] = []
        let now = Date()
        
        // --- Group 1: Exact Duplicates (3 takes, 4K 60fps ProRes / HEVC) ---
        // Same duration, same keyframes, keeper is favorited
        let g1Duration = 18.42
        let g1Hashes = [
            DualHash(dHash: 0xA1B2C3D4E5F60718, pHash: 0x1122334455667788),
            DualHash(dHash: 0xB2C3D4E5F60718A1, pHash: 0x2233445566778811),
            DualHash(dHash: 0xC3D4E5F60718A1B2, pHash: 0x3344556677881122),
            DualHash(dHash: 0xD4E5F60718A1B2C3, pHash: 0x4455667788112233)
        ]
        let g1Fp = VideoFingerprint(durationSeconds: g1Duration, pixelWidth: 3840, pixelHeight: 2160, keyframeHashes: g1Hashes)
        
        dataset.append(VideoAssetSnapshot(
            id: "vid_exact_1",
            filename: "IMG_4920.MOV",
            durationSeconds: g1Duration,
            creationDate: now.addingTimeInterval(-3600),
            pixelWidth: 3840,
            pixelHeight: 2160,
            fileSize: 310_000_000, // 310 MB
            isFavorite: true,
            fingerprint: g1Fp
        ))
        dataset.append(VideoAssetSnapshot(
            id: "vid_exact_2",
            filename: "IMG_4920_copy.MOV",
            durationSeconds: g1Duration,
            creationDate: now.addingTimeInterval(-1800),
            pixelWidth: 3840,
            pixelHeight: 2160,
            fileSize: 310_000_000,
            isFavorite: false,
            fingerprint: g1Fp
        ))
        dataset.append(VideoAssetSnapshot(
            id: "vid_exact_3",
            filename: "IMG_4920(1).MOV",
            durationSeconds: g1Duration,
            creationDate: now.addingTimeInterval(-900),
            pixelWidth: 3840,
            pixelHeight: 2160,
            fileSize: 310_000_000,
            isFavorite: false,
            fingerprint: g1Fp
        ))
        
        // --- Group 2: Near Duplicates (Original 1080p vs WhatsApp Re-compressed) ---
        let g2Duration = 12.8
        let g2HashesA = [
            DualHash(dHash: 0x9988776655443322, pHash: 0xFEEDFACECAFEBABE),
            DualHash(dHash: 0x8877665544332299, pHash: 0xEDFACECAFEBABEF0),
            DualHash(dHash: 0x7766554433229988, pHash: 0xDFACECAFEBABEF0E),
            DualHash(dHash: 0x6655443322998877, pHash: 0xFACECAFEBABEF0ED)
        ]
        // 1-2 bit noise from compression
        let g2HashesB = [
            DualHash(dHash: 0x9988776655443323, pHash: 0xFEEDFACECAFEBABA),
            DualHash(dHash: 0x8877665544332298, pHash: 0xEDFACECAFEBABEF1),
            DualHash(dHash: 0x7766554433229989, pHash: 0xDFACECAFEBABEF0C),
            DualHash(dHash: 0x6655443322998876, pHash: 0xFACECAFEBABEF0EC)
        ]
        
        dataset.append(VideoAssetSnapshot(
            id: "vid_near_original",
            filename: "RPReplay_Final.MP4",
            durationSeconds: g2Duration,
            creationDate: now.addingTimeInterval(-7200),
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 145_000_000, // 145 MB (higher quality)
            isFavorite: false,
            fingerprint: VideoFingerprint(durationSeconds: g2Duration, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: g2HashesA)
        ))
        dataset.append(VideoAssetSnapshot(
            id: "vid_near_whatsapp",
            filename: "WhatsApp_Video_2026.mp4",
            durationSeconds: g2Duration + 0.1,
            creationDate: now.addingTimeInterval(-300),
            pixelWidth: 1280,
            pixelHeight: 720,
            fileSize: 22_000_000, // 22 MB (recompressed)
            isFavorite: false,
            fingerprint: VideoFingerprint(durationSeconds: g2Duration + 0.1, pixelWidth: 1280, pixelHeight: 720, keyframeHashes: g2HashesB)
        ))
        
        // --- Group 3: Similar Takes / Burst Video (Multiple takes of same scene) ---
        let g3Duration = 24.5
        let g3HashesA = [
            DualHash(dHash: 0x1111222233334444, pHash: 0xAAAABBBBCCCCDDDD),
            DualHash(dHash: 0x2222333344445555, pHash: 0xBBBBCCCCDDDDEEEE),
            DualHash(dHash: 0x3333444455556666, pHash: 0xCCCCDDDDEEEEFFFF),
            DualHash(dHash: 0x4444555566667777, pHash: 0xDDDDEEEEFFFFAAAA)
        ]
        // ~8 bits difference (camera shift / alternate scene take)
        let g3HashesB = [
            DualHash(dHash: 0x11112222333344FF, pHash: 0xAAAABBBBCCCCDDFF),
            DualHash(dHash: 0x22223333444455FF, pHash: 0xBBBBCCCCDDDDEEFF),
            DualHash(dHash: 0x33334444555566FF, pHash: 0xCCCCDDDDEEEEFFFF),
            DualHash(dHash: 0x44445555666677FF, pHash: 0xDDDDEEEEFFFFAAFF)
        ]
        
        dataset.append(VideoAssetSnapshot(
            id: "vid_similar_take1",
            filename: "Take_1_Sunset.MOV",
            durationSeconds: g3Duration,
            creationDate: now.addingTimeInterval(-14000),
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 180_000_000,
            isFavorite: false,
            fingerprint: VideoFingerprint(durationSeconds: g3Duration, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: g3HashesA)
        ))
        dataset.append(VideoAssetSnapshot(
            id: "vid_similar_take2",
            filename: "Take_2_Sunset.MOV",
            durationSeconds: g3Duration + 0.6,
            creationDate: now.addingTimeInterval(-13800),
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 195_000_000,
            isFavorite: false,
            fingerprint: VideoFingerprint(durationSeconds: g3Duration + 0.6, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: g3HashesB)
        ))
        
        // --- Distinct Unrelated Videos ---
        let distinctConfigs: [(String, Double, UInt64, Int64)] = [
            ("CityWalk.mov", 45.2, 0x0F0F0F0F0F0F0F0F, 420_000_000),
            ("DroneFlight.mp4", 128.0, 0x55AA55AA55AA55AA, 950_000_000),
            ("DogPark.mov", 6.8, 0x1234123412341234, 52_000_000),
            ("CookingRecipe.mp4", 82.5, 0x89AB89AB89AB89AB, 510_000_000)
        ]
        
        for (i, config) in distinctConfigs.enumerated() {
            let fp = VideoFingerprint(
                durationSeconds: config.1,
                pixelWidth: 1920,
                pixelHeight: 1080,
                keyframeHashes: [
                    DualHash(dHash: config.2, pHash: ~config.2),
                    DualHash(dHash: config.2 << 1, pHash: ~config.2 >> 1),
                    DualHash(dHash: config.2 << 2, pHash: ~config.2 >> 2),
                    DualHash(dHash: config.2 << 3, pHash: ~config.2 >> 3)
                ]
            )
            dataset.append(VideoAssetSnapshot(
                id: "vid_distinct_\(i)",
                filename: config.0,
                durationSeconds: config.1,
                creationDate: now.addingTimeInterval(Double(-20000 - i * 5000)),
                pixelWidth: 1920,
                pixelHeight: 1080,
                fileSize: config.3,
                isFavorite: false,
                fingerprint: fp
            ))
        }
        
        return dataset
    }
}
