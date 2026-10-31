import Foundation

/// Fast, multi-phase video clustering engine ported from the production PhotoCleaner VideoDedupeEngine.
///
/// Features:
/// 1. Exact Video Matching: Keyframe hash equality (meanKeyframeDistance == 0) within 1.0s duration window.
/// 2. Promoted Re-Encoded Matching: Same resolution (pixelWidth & pixelHeight) within tight duration (0.2s)
///    and keyframe hamming distance within `videoSimilarBitBudget` (14 bits) are promoted to exact duplicates.
/// 3. Near Duplicates: Transcoded/compressed videos (duration within 0.75s, mean composite distance <= 5.0).
/// 4. Similar Takes Clustering: Chronological lookahead within `similarVideoCreationWindow` (~4 hours),
///    relative duration delta (30% or 3.0s floor), and bit budget (14 bits).
/// 5. Disjoint-Set Union (DSU) with path compression and union-by-rank.
/// 6. Incremental `mergeNewVideos` API for non-blocking live library updates.
public enum VideoDuplicateGrouper {
    
    // MARK: - Constants & Thresholds
    
    /// Fixed bit budget for similar video takes and exact promotion.
    public static let videoSimilarBitBudget = 14
    
    /// Max duration difference for identical poster equality (0 distance).
    public static let exactVideoDurationWindow: TimeInterval = 1.0
    
    /// Max duration difference for promoted re-encoded copies (same resolution + same recording).
    public static let exactPromotionDurationWindow: TimeInterval = 0.2
    
    /// Creation-date proximity window between similar takes (~4 hours).
    public static let similarVideoCreationWindow: TimeInterval = 4 * 60 * 60
    
    /// Relative duration slack for similar video takes.
    public static let similarVideoDurationRelativeDelta: Double = 0.30
    
    /// Absolute duration floor used with the relative gate.
    public static let similarVideoDurationAbsoluteFloor: TimeInterval = 3.0
    
    // MARK: - Helper Predicates
    
    /// Checks if duration difference qualifies under similar video rules.
    @inlinable
    public static func isSimilarDuration(_ a: TimeInterval, _ b: TimeInterval) -> Bool {
        let diff = abs(a - b)
        let maxDuration = max(1.0, max(a, b))
        return diff <= max(similarVideoDurationAbsoluteFloor, similarVideoDurationRelativeDelta * maxDuration)
    }
    
    /// Returns true when two videos share identical pixel dimensions and tight duration (0.2s)
    /// and their mean keyframe distance is within the similar bit budget, indicating a re-encoded / compressed copy.
    @inlinable
    public static func isPromotedExactMatch(
        _ fpA: VideoFingerprint,
        _ fpB: VideoFingerprint
    ) -> Bool {
        guard fpA.pixelWidth == fpB.pixelWidth, fpA.pixelHeight == fpB.pixelHeight else {
            return false
        }
        guard fpA.durationDelta(to: fpB) <= exactPromotionDurationWindow else {
            return false
        }
        let dist = fpA.meanKeyframeDistance(to: fpB)
        return dist > 0 && dist <= Double(videoSimilarBitBudget)
    }
    
    // MARK: - Disjoint-Set Union
    
    private final class DisjointSetUnion {
        private var parent: [Int]
        private var rank: [Int]
        
        init(count: Int) {
            self.parent = Array(0..<count)
            self.rank = Array(repeating: 0, count: count)
        }
        
        func find(_ i: Int) -> Int {
            var root = i
            while parent[root] != root {
                root = parent[root]
            }
            var curr = i
            while parent[curr] != root {
                let nxt = parent[curr]
                parent[curr] = root
                curr = nxt
            }
            return root
        }
        
        func union(_ i: Int, _ j: Int) {
            let rootI = find(i)
            let rootJ = find(j)
            guard rootI != rootJ else { return }
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
    
    // MARK: - Main Clustering Engine
    
    public static func group(
        assets: [VideoAssetSnapshot],
        includeSimilar: Bool = true
    ) -> [VideoDuplicateGroup] {
        guard assets.count >= 2 else { return [] }
        
        // De-duplicate any repeat asset IDs
        var seenIDs = Set<String>()
        var uniqueAssets: [VideoAssetSnapshot] = []
        uniqueAssets.reserveCapacity(assets.count)
        for a in assets {
            if seenIDs.insert(a.id).inserted {
                uniqueAssets.append(a)
            }
        }
        
        let totalCount = uniqueAssets.count
        guard totalCount >= 2 else { return [] }
        
        // -------------------------------------------------------------------------
        // PHASE 1: Exact Duplicates & Near Duplicates (Sorted by Duration)
        // -------------------------------------------------------------------------
        let sortedByDuration = uniqueAssets.enumerated().sorted { $0.element.durationSeconds < $1.element.durationSeconds }
        let dsuExact = DisjointSetUnion(count: totalCount)
        var pairCategories: [String: VideoMatchCategory] = [:]
        var pairScores: [String: Double] = [:]
        
        @inline(__always)
        func pairKey(_ i: Int, _ j: Int) -> String {
            i < j ? "\(i)_\(j)" : "\(j)_\(i)"
        }
        
        for i in 0..<totalCount {
            let current = sortedByDuration[i].element
            guard let fpCurrent = current.fingerprint, !fpCurrent.keyframeHashes.isEmpty else { continue }
            
            var j = i + 1
            while j < totalCount {
                let candidate = sortedByDuration[j].element
                let durationDiff = candidate.durationSeconds - current.durationSeconds
                if durationDiff > exactVideoDurationWindow { break }
                
                guard let fpCandidate = candidate.fingerprint, !fpCandidate.keyframeHashes.isEmpty else {
                    j += 1
                    continue
                }
                
                let meanDist = fpCurrent.meanKeyframeDistance(to: fpCandidate)
                let isExactZero = (meanDist == 0)
                let isPromoted = isPromotedExactMatch(fpCurrent, fpCandidate)
                
                let origI = sortedByDuration[i].offset
                let origJ = sortedByDuration[j].offset
                let key = pairKey(origI, origJ)
                
                if isExactZero || isPromoted {
                    dsuExact.union(i, j)
                    pairCategories[key] = .exactDuplicate
                    pairScores[key] = isExactZero ? 1.0 : fpCurrent.similarityScore(to: fpCandidate)
                } else if durationDiff <= 0.75 && meanDist <= 5.0 {
                    dsuExact.union(i, j)
                    if pairCategories[key] == nil {
                        pairCategories[key] = .nearDuplicate
                    }
                    pairScores[key] = fpCurrent.similarityScore(to: fpCandidate)
                }
                
                j += 1
            }
        }
        
        var exactClusters: [Int: [Int]] = [:]
        for i in 0..<totalCount {
            guard let fp = sortedByDuration[i].element.fingerprint, !fp.keyframeHashes.isEmpty else { continue }
            exactClusters[dsuExact.find(i), default: []].append(i)
        }
        
        var claimedOriginalIndices = Set<Int>()
        var exactAndNearGroups: [VideoDuplicateGroup] = []
        
        for (_, members) in exactClusters where members.count >= 2 {
            let groupAssets = members.map { sortedByDuration[$0].element }
            for m in members {
                claimedOriginalIndices.insert(sortedByDuration[m].offset)
            }
            
            var hasExact = false
            var totalScore = 0.0
            var scoreCount = 0
            
            for a in 0..<members.count {
                for b in (a + 1)..<members.count {
                    let origA = sortedByDuration[members[a]].offset
                    let origB = sortedByDuration[members[b]].offset
                    let key = pairKey(origA, origB)
                    if let cat = pairCategories[key], cat == .exactDuplicate {
                        hasExact = true
                    }
                    if let score = pairScores[key] {
                        totalScore += score
                        scoreCount += 1
                    }
                }
            }
            
            let keeper = BestVideoSelector.pickKeeper(from: groupAssets) ?? groupAssets[0]
            let avgScore = scoreCount > 0 ? (totalScore / Double(scoreCount)) : 0.95
            
            exactAndNearGroups.append(
                VideoDuplicateGroup(
                    category: hasExact ? .exactDuplicate : .nearDuplicate,
                    assets: groupAssets,
                    bestAssetId: keeper.id,
                    similarityScore: avgScore
                )
            )
        }
        
        // -------------------------------------------------------------------------
        // PHASE 2: Similar Takes Pass (Sorted by Creation Date)
        // -------------------------------------------------------------------------
        var similarGroups: [VideoDuplicateGroup] = []
        
        if includeSimilar {
            let sortedByDate = uniqueAssets.enumerated().sorted { $0.element.creationDate < $1.element.creationDate }
            let dsuSimilar = DisjointSetUnion(count: totalCount)
            
            for left in 0..<totalCount {
                let currentItem = sortedByDate[left]
                let origLeft = currentItem.offset
                if claimedOriginalIndices.contains(origLeft) { continue }
                guard let fpLeft = currentItem.element.fingerprint, !fpLeft.keyframeHashes.isEmpty else { continue }
                
                var right = left + 1
                while right < totalCount {
                    let candidateItem = sortedByDate[right]
                    let origRight = candidateItem.offset
                    let timeGap = candidateItem.element.creationDate.timeIntervalSince(currentItem.element.creationDate)
                    if timeGap > similarVideoCreationWindow { break }
                    
                    if !claimedOriginalIndices.contains(origRight),
                       let fpRight = candidateItem.element.fingerprint,
                       !fpRight.keyframeHashes.isEmpty,
                       isSimilarDuration(currentItem.element.durationSeconds, candidateItem.element.durationSeconds) {
                        
                        let meanDist = fpLeft.meanKeyframeDistance(to: fpRight)
                        if meanDist > 0 && meanDist <= Double(videoSimilarBitBudget) {
                            dsuSimilar.union(left, right)
                            let key = pairKey(origLeft, origRight)
                            pairCategories[key] = .similar
                            pairScores[key] = fpLeft.similarityScore(to: fpRight)
                        }
                    }
                    right += 1
                }
            }
            
            var similarClusters: [Int: [Int]] = [:]
            for i in 0..<totalCount {
                let orig = sortedByDate[i].offset
                if !claimedOriginalIndices.contains(orig),
                   let fp = sortedByDate[i].element.fingerprint,
                   !fp.keyframeHashes.isEmpty {
                    similarClusters[dsuSimilar.find(i), default: []].append(i)
                }
            }
            
            for (_, members) in similarClusters where members.count >= 2 {
                let groupAssets = members.map { sortedByDate[$0].element }
                var totalScore = 0.0
                var scoreCount = 0
                
                for a in 0..<members.count {
                    for b in (a + 1)..<members.count {
                        let origA = sortedByDate[members[a]].offset
                        let origB = sortedByDate[members[b]].offset
                        let key = pairKey(origA, origB)
                        if let score = pairScores[key] {
                            totalScore += score
                            scoreCount += 1
                        }
                    }
                }
                
                let keeper = BestVideoSelector.pickKeeper(from: groupAssets) ?? groupAssets[0]
                let avgScore = scoreCount > 0 ? (totalScore / Double(scoreCount)) : 0.85
                
                similarGroups.append(
                    VideoDuplicateGroup(
                        category: .similar,
                        assets: groupAssets,
                        bestAssetId: keeper.id,
                        similarityScore: avgScore
                    )
                )
            }
        }
        
        // Combine results
        var combined = exactAndNearGroups + similarGroups
        
        // Sort groups: exact duplicates first, then near duplicates, then largest reclaimable size
        combined.sort { g1, g2 in
            if g1.category != g2.category {
                if g1.category == .exactDuplicate { return true }
                if g2.category == .exactDuplicate { return false }
                if g1.category == .nearDuplicate { return true }
                if g2.category == .nearDuplicate { return false }
            }
            return g1.reclaimableSize > g2.reclaimableSize
        }
        
        return combined
    }
    
    // MARK: - Incremental Merging
    
    /// Incrementally folds newly-added videos into existing dedupe groups without full library rescans.
    public static func mergeNewVideos(
        _ newVideos: [VideoAssetSnapshot],
        into existingGroups: [VideoDuplicateGroup],
        includeSimilar: Bool = true
    ) -> (groups: [VideoDuplicateGroup], merged: Bool) {
        guard !newVideos.isEmpty else { return (existingGroups, false) }
        
        var groups = existingGroups
        var didMerge = false
        var unassignedNewcomers: [VideoAssetSnapshot] = []
        
        for newVideo in newVideos {
            guard let newFp = newVideo.fingerprint, !newFp.keyframeHashes.isEmpty else { continue }
            var mergedIntoGroupIndex: Int? = nil
            
            for (gIdx, group) in groups.enumerated() {
                var matchesGroup = false
                for member in group.assets {
                    guard let memberFp = member.fingerprint, !memberFp.keyframeHashes.isEmpty else { continue }
                    let durationDiff = abs(newVideo.durationSeconds - member.durationSeconds)
                    let meanDist = newFp.meanKeyframeDistance(to: memberFp)
                    
                    // Exact / Promoted match
                    if (durationDiff <= exactVideoDurationWindow && meanDist == 0) ||
                        isPromotedExactMatch(newFp, memberFp) {
                        matchesGroup = true
                        break
                    }
                    
                    // Near match
                    if durationDiff <= 0.75 && meanDist <= 5.0 {
                        matchesGroup = true
                        break
                    }
                    
                    // Similar match
                    if includeSimilar && isSimilarDuration(newVideo.durationSeconds, member.durationSeconds) {
                        let timeGap = abs(newVideo.creationDate.timeIntervalSince(member.creationDate))
                        if timeGap <= similarVideoCreationWindow && meanDist > 0 && meanDist <= Double(videoSimilarBitBudget) {
                            matchesGroup = true
                            break
                        }
                    }
                }
                
                if matchesGroup {
                    mergedIntoGroupIndex = gIdx
                    break
                }
            }
            
            if let gIdx = mergedIntoGroupIndex {
                var updatedAssets = groups[gIdx].assets
                updatedAssets.append(newVideo)
                let keeper = BestVideoSelector.pickKeeper(from: updatedAssets) ?? updatedAssets[0]
                groups[gIdx] = VideoDuplicateGroup(
                    id: groups[gIdx].id,
                    category: groups[gIdx].category,
                    assets: updatedAssets,
                    bestAssetId: keeper.id,
                    similarityScore: groups[gIdx].similarityScore
                )
                didMerge = true
            } else {
                unassignedNewcomers.append(newVideo)
            }
        }
        
        // Cluster unassigned newcomers among themselves
        if unassignedNewcomers.count >= 2 {
            let newClusters = group(assets: unassignedNewcomers, includeSimilar: includeSimilar)
            if !newClusters.isEmpty {
                groups.append(contentsOf: newClusters)
                didMerge = true
            }
        }
        
        if didMerge {
            groups.sort { g1, g2 in
                if g1.category != g2.category {
                    if g1.category == .exactDuplicate { return true }
                    if g2.category == .exactDuplicate { return false }
                    if g1.category == .nearDuplicate { return true }
                    if g2.category == .nearDuplicate { return false }
                }
                return g1.reclaimableSize > g2.reclaimableSize
            }
        }
        
        return (groups, didMerge)
    }
}
