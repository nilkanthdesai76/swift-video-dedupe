import Foundation
import Accelerate
import CoreGraphics

/// Hardware-accelerated image scaling, grayscale conversion, and 2D Discrete Cosine Transform (DCT)
/// using Apple's Accelerate framework (vImage and vDSP).
public enum AccelerateImageOps {
    
    // MARK: - Precomputed 2D DCT Cosine Matrix (32x32)
    
    private static let dctMatrix: [Float] = {
        var matrix = [Float](repeating: 0, count: 32 * 32)
        let n: Float = 32.0
        let invSqrtN = 1.0 / sqrt(n)
        let sqrtTwoOverN = sqrt(2.0 / n)
        
        for u in 0..<32 {
            let alpha: Float = (u == 0) ? invSqrtN : sqrtTwoOverN
            for x in 0..<32 {
                let angle = (Float(2 * x + 1) * Float(u) * Float.pi) / (2.0 * n)
                matrix[u * 32 + x] = alpha * cos(angle)
            }
        }
        return matrix
    }()
    
    private static let dctMatrixTransposed: [Float] = {
        var transposed = [Float](repeating: 0, count: 32 * 32)
        for r in 0..<32 {
            for c in 0..<32 {
                transposed[r * 32 + c] = dctMatrix[c * 32 + r]
            }
        }
        return transposed
    }()
    
    /// Downsamples a CGImage to a grayscale buffer of the specified dimensions (e.g. 9x8 or 32x32)
    public static func renderGrayscaleBuffer(
        from cgImage: CGImage,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var buffer = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
    
    /// Computes an 8x8 2D Discrete Cosine Transform (DCT-II) over a 32x32 float matrix
    /// using vDSP separable matrix multiplications.
    public static func compute2DDCT8x8(from32x32Grayscale buffer: [UInt8]) -> [Float] {
        precondition(buffer.count == 32 * 32, "Input buffer must be 32x32")
        
        var floatMatrix = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 {
            floatMatrix[i] = Float(buffer[i])
        }
        
        // 2D DCT = Basis * Matrix * Basis^T
        var temp = [Float](repeating: 0, count: 1024)
        vDSP_mmul(
            dctMatrix, 1,
            floatMatrix, 1,
            &temp, 1,
            32, 32, 32
        )
        
        var dct = [Float](repeating: 0, count: 1024)
        vDSP_mmul(
            temp, 1,
            dctMatrixTransposed, 1,
            &dct, 1,
            32, 32, 32
        )
        
        // Extract top-left 8x8 low frequency coefficients
        var lowFreq = [Float](repeating: 0, count: 64)
        for r in 0..<8 {
            for c in 0..<8 {
                lowFreq[r * 8 + c] = dct[r * 32 + c]
            }
        }
        
        return lowFreq
    }
}
