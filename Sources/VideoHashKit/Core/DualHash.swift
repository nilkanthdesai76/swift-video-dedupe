import Foundation
import CoreGraphics

/// 16-byte dual perceptual fingerprint combining structural gradient (dHash)
/// and frequency domain structure (pHash).
public struct DualHash: Hashable, Codable, Sendable {
    public let dHash: UInt64
    public let pHash: UInt64
    
    public init(dHash: UInt64, pHash: UInt64) {
        self.dHash = dHash
        self.pHash = pHash
    }
    
    public static func compute(from cgImage: CGImage) -> DualHash {
        let d = DHash.compute(from: cgImage)
        let p = PHash.compute(from: cgImage)
        return DualHash(dHash: d, pHash: p)
    }
    
    @inlinable
    public func dDistance(to other: DualHash) -> Int {
        DHash.hammingDistance(self.dHash, other.dHash)
    }
    
    @inlinable
    public func pDistance(to other: DualHash) -> Int {
        PHash.hammingDistance(self.pHash, other.pHash)
    }
    
    @inlinable
    public func compositeDistance(to other: DualHash) -> Int {
        dDistance(to: other) + pDistance(to: other)
    }
}
