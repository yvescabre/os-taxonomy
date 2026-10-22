import Foundation

/// Mechanic-level misconceptions the bridge generator knows how to produce
/// and diagnose. Each maps onto taxonomy `errorPatterns` where possible.
public enum MisconceptionKind: String, Codable, CaseIterable, Sendable {
    /// Applied the visible operation to the two visible numbers
    /// (`8 + ? = 11` → 19; `7 × ? = 63` → 63 − 7).
    case usedVisibleNumbers
    /// Wrote the whole/total in the box (`9 + ? = 12` → 12).
    case wroteTheWhole
    /// Put the left-hand total in the box for `a + b = ? + c`.
    case runningTotal
    /// Treated the inverse direction wrongly (`? − 120 = 250` → 130;
    /// `? ÷ 6 = 7` → tried 7 ÷ 6).
    case wrongOperation
    /// Off-by-one, typically counting ticks instead of intervals.
    case offByOne
    /// Place-value slip (treated tens as ones, e.g. +40 counted as +4).
    case placeValueSlip
    /// Used a different times-table step than the pattern required.
    case wrongStep
    /// Followed the sequence in the wrong direction.
    case wrongDirection
}

/// A wrong-answer diagnosis plus research-linked context.
public struct MisconceptionDiagnosis: Sendable {
    public let kind: MisconceptionKind
    /// Child-facing, gently-worded feedback ("no red crosses").
    public let childMessage: LocalizedMessage
    /// Matched taxonomy errorPattern (nil when research is absent or nothing
    /// matched). Pattern text drives the parent dashboard, not the child UI.
    public let researchPattern: ErrorPattern?
    /// Topic the research recommends reteaching, if playable.
    public let reteachTopicId: String?

    public init(kind: MisconceptionKind, childMessage: LocalizedMessage,
                researchPattern: ErrorPattern?, reteachTopicId: String?) {
        self.kind = kind
        self.childMessage = childMessage
        self.researchPattern = researchPattern
        self.reteachTopicId = reteachTopicId
    }
}

/// Keyword-based matcher from mechanic misconceptions to taxonomy
/// `errorPatterns`. English keywords, applied to `pattern` + `revealedBy` +
/// `nextMove`. Matching is a suggestion, not a claim — when nothing matches,
/// the engine falls back to its own scaffold rules.
public enum ErrorPatternMatcher {

    private static let keywords: [MisconceptionKind: [[String]]] = [
        .usedVisibleNumbers: [
            ["adds the two visible", "visible numbers", "adds everything", "adds all numbers"],
            ["adds", "regardless of the box"],
            ["operates on the two visible", "operation shown"],
            ["adds/subtracts to fill the box"],
        ],
        .wroteTheWhole: [
            ["writes the whole", "adds the visible numbers", "whole instead"],
            ["answer", "is the total"],
        ],
        .runningTotal: [
            ["running-total", "running total", "left-hand total"],
        ],
        .wrongOperation: [
            ["position confusion", "treats", "where an answer"],
            ["wrong inverse", "inverts", "inverts incorrectly"],
            ["inverts the unknown-factor"],
        ],
        .offByOne: [
            ["off-by-one", "one off", "slips by one", "counts back", "counts on"],
            ["count", "tick", "mark"],
        ],
        .placeValueSlip: [
            ["place value", "tens as ones", "multiple of ten", "hundreds"],
        ],
        .wrongStep: [
            ["times table", "skip-count", "skip counting", "step"],
        ],
        .wrongDirection: [
            ["direction", "forwards", "backwards", "counting back"],
        ],
    ]

    /// Best-matching errorPattern for a misconception within a teaching record.
    public static func match(_ kind: MisconceptionKind,
                             in record: TeachingRecord?) -> ErrorPattern? {
        guard let patterns = record?.assess?.errorPatterns, !patterns.isEmpty,
              let groups = keywords[kind] else { return nil }
        var best: (pattern: ErrorPattern, score: Int)? = nil
        for (index, group) in groups.enumerated() {
            for ep in patterns {
                let haystack = [ep.pattern, ep.revealedBy, ep.nextMove]
                    .compactMap { $0 }.joined(separator: " ").lowercased()
                if group.allSatisfy({ haystack.contains($0.lowercased()) }) {
                    // Earlier groups are more specific → higher score.
                    let score = groups.count - index
                    if best == nil || score > best!.score { best = (ep, score) }
                }
            }
        }
        return best?.pattern
    }
}
