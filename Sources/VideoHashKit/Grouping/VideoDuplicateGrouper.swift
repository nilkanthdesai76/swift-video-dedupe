import Foundation

/// Fast video clustering engine using Disjoint-Set Union (DSU) and Multi-Index Hashing.
public enum VideoDuplicateGrouper {
    
    private final class DisjointSetUnion {
        private var parent: [Int]
        private var rank: [Int]
        
        init(count: Int) {
            self.parent = Array(0..<count)
            self.rank = Array(repeating: 0, count: count)
        }
        
        func find(_ i: Int) -> Int {
            if parent[i] == i {
                return i
            }
            parent[i] = find(parent[i])
            return parent[i]
        }
        
        func union(_ i: Int, _ j: Int) {
            let rootI = find(i)
            let rootJ = find(j)
            if rootI != rootJ {
                if rank[rootI] < rank[rootJ] {
                    parent[rootI] = rootJ
                } else if rank[rootI] > rank[rootJ] {
                    parent[rootJ] = rootI
                } else {
                    parent[rootJ] = rootI
                    rank[rootI] += 1
                }
            }
        }
    }
    
    /// Groups video snapshots into clusters of duplicates and similar takes.
    public static func group(
        assets: [VideoAssetSnapshot],
        includeSimilar: Bool = true
    ) -> [VideoDuplicateGroup] {
        guard assets.count >= 2 else { return [] }
        
        let count = assets.count
        let dsu = DisjointSetUnion(count: count)
        let mih = VideoMultiIndexHasher()
        
        // Populate index
        for (idx, asset) in assets.enumerated() {
            if let fp = asset.fingerprint {
                mih.insert(id: "\(idx)", fingerprint: fp)
            }
        }
        
        var pairCategories: [String: VideoMatchCategory] = [:]
        var pairScores: [String: Double] = [:]
        
        // Find duplicate & similar pairs
        for i in 0..<count {
            guard let fpA = assets[i].fingerprint else { continue }
            let candidateIndices = mih.findCandidates(for: fpA)
            
            for candStr in candidateIndices {
                guard let j = Int(candStr), j > i else { continue }
                guard let fpB = assets[j].fingerprint else { continue }
                
                let category = fpA.matchCategory(to: fpB)
                if category == .exactDuplicate || category == .nearDuplicate || (includeSimilar && category == .similar) {
                    dsu.union(i, j)
                    let pairKey = "\(i)_\(j)"
                    pairCategories[pairKey] = category
                    pairScores[pairKey] = fpA.similarityScore(to: fpB)
                }
            }
        }
        
        // Collect clusters by root
        var clusters: [Int: [Int]] = [:]
        for i in 0..<count {
            let root = dsu.find(i)
            clusters[root, default: []].append(i)
        }
        
        var result: [VideoDuplicateGroup] = []
        for (_, indices) in clusters where indices.count > 1 {
            let clusterAssets = indices.map { assets[$0] }
            
            // Determine representative category and score
            var highestCategory = VideoMatchCategory.similar
            var totalScore = 0.0
            var scoreCount = 0
            
            for a in 0..<indices.count {
                for b in (a + 1)..<indices.count {
                    let idxA = min(indices[a], indices[b])
                    let idxB = max(indices[a], indices[b])
                    let key = "\(idxA)_\(idxB)"
                    if let cat = pairCategories[key] {
                        if cat == .exactDuplicate {
                            highestCategory = .exactDuplicate
                        } else if cat == .nearDuplicate && highestCategory != .exactDuplicate {
                            highestCategory = .nearDuplicate
                        }
                    }
                    if let score = pairScores[key] {
                        totalScore += score
                        scoreCount += 1
                    }
                }
            }
            
            let keeper = BestVideoSelector.pickKeeper(from: clusterAssets) ?? clusterAssets[0]
            let avgScore = scoreCount > 0 ? (totalScore / Double(scoreCount)) : 0.95
            
            let group = VideoDuplicateGroup(
                category: highestCategory,
                assets: clusterAssets,
                bestAssetId: keeper.id,
                similarityScore: avgScore
            )
            result.append(group)
        }
        
        // Sort groups: exact duplicates first, then near duplicates, then largest reclaimable size
        result.sort { g1, g2 in
            if g1.category != g2.category {
                if g1.category == .exactDuplicate { return true }
                if g2.category == .exactDuplicate { return false }
                if g1.category == .nearDuplicate { return true }
                if g2.category == .nearDuplicate { return false }
            }
            return g1.reclaimableSize > g2.reclaimableSize
        }
        
        return result
    }
}
