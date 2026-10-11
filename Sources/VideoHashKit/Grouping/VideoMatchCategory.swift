import Foundation

/// Classification tiers for video similarity matching.
public enum VideoMatchCategory: String, Codable, CaseIterable, Sendable {
    /// 100% identical videos (identical keyframe fingerprints and matching duration).
    case exactDuplicate = "Exact Duplicate"
    
    /// Visually identical videos with minor transcoding, resolution differences, or WhatsApp/AirDrop recompression.
    case nearDuplicate = "Near Duplicate"
    
    /// Similar scenes, multiple video takes of the same subject, or slightly trimmed variations.
    case similar = "Similar / Scene Variation"
    
    /// Distinct, unrelated videos.
    case different = "Distinct"
    
    public var isDuplicateOrSimilar: Bool {
        self != .different
    }
}
