import Foundation

/// Sublinear candidate retrieval for large video collections.
/// Combines duration bucketing with 16-bit pigeonhole partition tables on primary anchor keyframes.
public final class VideoMultiIndexHasher {
    
    // Duration bucket size in seconds (e.g. 2.0s)
    private let durationBucketSize: Double = 2.0
    
    // 4 tables corresponding to the 4 16-bit sub-words of the primary keyframe's 64-bit dHash
    private var table0: [UInt16: [String]] = [:]
    private var table1: [UInt16: [String]] = [:]
    private var table2: [UInt16: [String]] = [:]
    private var table3: [UInt16: [String]] = [:]
    
    private var fingerprints: [String: VideoFingerprint] = [:]
    
    public init() {}
    
    public func insert(id: String, fingerprint: VideoFingerprint) {
        fingerprints[id] = fingerprint
        
        guard let anchorHash = fingerprint.keyframeHashes.first?.dHash else {
            return
        }
        
        let chunk0 = UInt16((anchorHash >> 48) & 0xFFFF)
        let chunk1 = UInt16((anchorHash >> 32) & 0xFFFF)
        let chunk2 = UInt16((anchorHash >> 16) & 0xFFFF)
        let chunk3 = UInt16(anchorHash & 0xFFFF)
        
        table0[chunk0, default: []].append(id)
        table1[chunk1, default: []].append(id)
        table2[chunk2, default: []].append(id)
        table3[chunk3, default: []].append(id)
    }
    
    /// Finds candidate video IDs that share at least one 16-bit keyframe block and have compatible duration.
    public func findCandidates(for fingerprint: VideoFingerprint) -> [String] {
        guard let anchorHash = fingerprint.keyframeHashes.first?.dHash else {
            return []
        }
        
        let chunk0 = UInt16((anchorHash >> 48) & 0xFFFF)
        let chunk1 = UInt16((anchorHash >> 32) & 0xFFFF)
        let chunk2 = UInt16((anchorHash >> 16) & 0xFFFF)
        let chunk3 = UInt16(anchorHash & 0xFFFF)
        
        var candidateSet = Set<String>()
        if let ids = table0[chunk0] { candidateSet.formUnion(ids) }
        if let ids = table1[chunk1] { candidateSet.formUnion(ids) }
        if let ids = table2[chunk2] { candidateSet.formUnion(ids) }
        if let ids = table3[chunk3] { candidateSet.formUnion(ids) }
        
        // Filter candidates by duration tolerance
        return candidateSet.filter { candId in
            guard let otherFp = fingerprints[candId] else { return false }
            return fingerprint.durationDelta(to: otherFp) <= 3.0
        }
    }
}
