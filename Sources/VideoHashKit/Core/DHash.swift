import Foundation
import CoreGraphics

/// 64-bit gradient difference hash (dHash).
/// Downsamples image to 9x8 grayscale and computes horizontal pixel intensity gradients.
/// Extremely fast (~10 microseconds) and resilient to global brightness changes.
public enum DHash {
    
    public static func compute(from cgImage: CGImage) -> UInt64 {
        guard let buffer = AccelerateImageOps.renderGrayscaleBuffer(from: cgImage, width: 9, height: 8) else {
            return 0
        }
        
        var hash: UInt64 = 0
        var bitIndex = 0
        
        for row in 0..<8 {
            let rowOffset = row * 9
            for col in 0..<8 {
                let left = buffer[rowOffset + col]
                let right = buffer[rowOffset + col + 1]
                if left > right {
                    hash |= (1 << (63 - bitIndex))
                }
                bitIndex += 1
            }
        }
        
        return hash
    }
    
    @inlinable
    public static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
