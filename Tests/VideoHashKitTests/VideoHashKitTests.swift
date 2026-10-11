import XCTest
import CoreGraphics
@testable import VideoHashKit

final class VideoHashKitTests: XCTestCase {
    
    // MARK: - Test Images Helper
    
    private func createSolidImage(color: CGColor, width: Int = 64, height: Int = 64) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
    
    private func createGradientImage(width: Int = 64, height: Int = 64) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let colors = [CGColor(red: 1, green: 0, blue: 0, alpha: 1), CGColor(red: 0, green: 0, blue: 1, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        return context.makeImage()!
    }
    
    // MARK: - Tests
    
    func testDHashIdenticalFramesHaveZeroDistance() {
        let img = createGradientImage()
        let hash1 = DHash.compute(from: img)
        let hash2 = DHash.compute(from: img)
        
        XCTAssertEqual(DHash.hammingDistance(hash1, hash2), 0)
    }
    
    func testPHashIdenticalFramesHaveZeroDistance() {
        let img = createGradientImage()
        let hash1 = PHash.compute(from: img)
        let hash2 = PHash.compute(from: img)
        
        XCTAssertEqual(PHash.hammingDistance(hash1, hash2), 0)
    }
    
    func testVideoFingerprintExactMatch() {
        let hashes = [
            DualHash(dHash: 0x1122334455667788, pHash: 0xAABBCCDDEEFF0011),
            DualHash(dHash: 0x2233445566778899, pHash: 0xBBCCDDEEFF001122),
            DualHash(dHash: 0x33445566778899AA, pHash: 0xCCDDEEFF00112233),
            DualHash(dHash: 0x445566778899AABB, pHash: 0xDDEEFF0011223344)
        ]
        
        let fpA = VideoFingerprint(durationSeconds: 15.0, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: hashes)
        let fpB = VideoFingerprint(durationSeconds: 15.05, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: hashes)
        
        XCTAssertEqual(fpA.matchCategory(to: fpB), .exactDuplicate)
        XCTAssertEqual(fpA.similarityScore(to: fpB), 1.0)
    }
    
    func testVideoFingerprintNearDuplicateWithCompressionNoise() {
        let hashesA = [
            DualHash(dHash: 0x1122334455667788, pHash: 0xAABBCCDDEEFF0011),
            DualHash(dHash: 0x2233445566778899, pHash: 0xBBCCDDEEFF001122)
        ]
        // 1-bit difference per frame simulating H.264 / WhatsApp compression
        let hashesB = [
            DualHash(dHash: 0x1122334455667789, pHash: 0xAABBCCDDEEFF0010),
            DualHash(dHash: 0x2233445566778898, pHash: 0xBBCCDDEEFF001120)
        ]
        
        let fpA = VideoFingerprint(durationSeconds: 10.0, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: hashesA)
        let fpB = VideoFingerprint(durationSeconds: 10.2, pixelWidth: 1280, pixelHeight: 720, keyframeHashes: hashesB)
        
        XCTAssertEqual(fpA.matchCategory(to: fpB), .nearDuplicate)
        XCTAssertGreaterThan(fpA.similarityScore(to: fpB), 0.90)
    }
    
    func testVideoFingerprintDifferentVideos() {
        let hashesA = [DualHash(dHash: 0x0000000000000000, pHash: 0x0000000000000000)]
        let hashesB = [DualHash(dHash: 0xFFFFFFFFFFFFFFFF, pHash: 0xFFFFFFFFFFFFFFFF)]
        
        let fpA = VideoFingerprint(durationSeconds: 5.0, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: hashesA)
        let fpB = VideoFingerprint(durationSeconds: 45.0, pixelWidth: 1920, pixelHeight: 1080, keyframeHashes: hashesB)
        
        XCTAssertEqual(fpA.matchCategory(to: fpB), .different)
    }
    
    func testBestVideoSelectorPrefersFavoriteAndHigherResolution() {
        let candidateA = VideoAssetSnapshot(
            id: "vid_1080p",
            filename: "1080p.mov",
            durationSeconds: 10.0,
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 50_000_000,
            isFavorite: false
        )
        let candidateB = VideoAssetSnapshot(
            id: "vid_4k_fav",
            filename: "4K.mov",
            durationSeconds: 10.0,
            pixelWidth: 3840,
            pixelHeight: 2160,
            fileSize: 200_000_000,
            isFavorite: true
        )
        
        let keeper = BestVideoSelector.pickKeeper(from: [candidateA, candidateB])
        XCTAssertEqual(keeper?.id, "vid_4k_fav")
    }
    
    func testSyntheticBenchmarkClustering() {
        let dataset = SampleVideoGenerator.createBenchmarkDataset()
        let groups = VideoDuplicateGrouper.group(assets: dataset)
        
        // Expected clusters: exact group, near duplicate group, similar take group
        XCTAssertGreaterThanOrEqual(groups.count, 2)
        
        let exactGroup = groups.first { $0.category == .exactDuplicate }
        XCTAssertNotNil(exactGroup)
        XCTAssertEqual(exactGroup?.assets.count, 3)
        XCTAssertEqual(exactGroup?.bestAssetId, "vid_exact_1") // favorited keeper
        
        let nearGroup = groups.first { $0.category == .nearDuplicate }
        XCTAssertNotNil(nearGroup)
        XCTAssertEqual(nearGroup?.assets.count, 2)
        XCTAssertEqual(nearGroup?.bestAssetId, "vid_near_original") // 1080p original over 720p WhatsApp
    }
}
