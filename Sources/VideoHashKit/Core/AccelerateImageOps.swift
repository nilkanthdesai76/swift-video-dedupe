import Foundation
import Accelerate
import CoreGraphics

/// Hardware-accelerated image scaling, grayscale conversion, and 2D Discrete Cosine Transform (DCT)
/// using Apple's Accelerate framework (vImage and vDSP).
public enum AccelerateImageOps {
    
    /// Downsamples a CGImage to a grayscale buffer of the specified dimensions (e.g. 9x8 or 32x32)
    /// using vImage hardware-accelerated scaling and color conversion.
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
    /// using vDSP matrix multiplications.
    public static func compute2DDCT8x8(from32x32Grayscale buffer: [UInt8]) -> [Float] {
        let n = 32
        var floatMatrix = [Float](repeating: 0, count: n * n)
        for i in 0..<(n * n) {
            floatMatrix[i] = Float(buffer[i])
        }
        
        // Build 32x32 DCT-II basis matrix once
        var basis = [Float](repeating: 0, count: n * n)
        let factor = Float.pi / Float(n)
        let c0 = 1.0 / sqrt(Float(n))
        let c1 = sqrt(2.0 / Float(n))
        
        for u in 0..<n {
            let scale = (u == 0) ? c0 : c1
            for x in 0..<n {
                basis[u * n + x] = scale * cos(Float(2 * x + 1) * Float(u) * factor * 0.5)
            }
        }
        
        // 2D DCT = Basis * Matrix * Basis^T
        var temp = [Float](repeating: 0, count: n * n)
        vDSP_mmul(basis, 1, floatMatrix, 1, &temp, 1, vDSP_Length(n), vDSP_Length(n), vDSP_Length(n))
        
        var dct = [Float](repeating: 0, count: n * n)
        vDSP_mmul(temp, 1, basis, n, &dct, 1, vDSP_Length(n), vDSP_Length(n), vDSP_Length(n))
        
        // Extract top-left 8x8 low frequency coefficients
        var lowFreq = [Float](repeating: 0, count: 64)
        for r in 0..<8 {
            for c in 0..<8 {
                lowFreq[r * 8 + c] = dct[r * n + c]
            }
        }
        
        return lowFreq
    }
}
