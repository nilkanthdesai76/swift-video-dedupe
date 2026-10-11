import Foundation
import CoreGraphics

/// 64-bit perceptual hash (pHash) based on 2D Discrete Cosine Transform (DCT).
/// Extracts human-visible low-frequency structures from 32x32 grayscale representations.
/// Resilient to compression noise, scaling, color adjustments, and minor cropping.
public enum PHash {
    
    public static func compute(from cgImage: CGImage) -> UInt64 {
        guard let buffer = AccelerateImageOps.renderGrayscaleBuffer(from: cgImage, width: 32, height: 32) else {
            return 0
        }
        
        let dct8x8 = AccelerateImageOps.compute2DDCT8x8(from32x32Grayscale: buffer)
        
        // Compute median of AC frequencies (exclude DC component at index 0)
        var acTerms = Array(dct8x8[1..<64])
        acTerms.sort()
        let median = acTerms[acTerms.count / 2]
        
        var hash: UInt64 = 0
        for i in 0..<64 {
            if dct8x8[i] > median {
                hash |= (1 << (63 - i))
            }
        }
        
        return hash
    }
    
    @inlinable
    public static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
