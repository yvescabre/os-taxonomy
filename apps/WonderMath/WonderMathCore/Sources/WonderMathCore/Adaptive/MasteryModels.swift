import Foundation

/// Lifecycle of a child's mastery of one topic.
public enum MasteryState: String, Codable, CaseIterable, Sendable {
    case notStarted
    case learning
    case mastered

    /// Computed display state including review-due; not persisted.
    public func displayState(dueForReview: Bool) -> DisplayMasteryState {
        if self == .mastered && dueForReview { return .review }
        switch self {
        case .notStarted: return .notStarted
        case .learning: return .learning
        case .mastered: return .mastered
        }
    }
}

public enum DisplayMasteryState: String, Sendable {
    case notStarted, learning, mastered, review
}

/// Rolling per-topic progress mirror (SwiftData `MasteryRecord` maps to/from
/// this value type so the engine stays Apple-framework-free and testable).
public struct SkillProgress: Codable, Hashable, Sendable {
    public var difficulty: Int = 1
    /// Last `recentWindow` outcomes, newest last. `true` = hint-free correct.
    public var recentResults: [Bool] = []
    /// Attempts completed without any hint or walkthrough.
    public var independentAttempts: Int = 0
    /// Per-evidence-index credit counts (index → count of hint-free correct
    /// puzzles tagged with that evidence).
    public var evidenceCredits: [Int: Int] = [:]
    /// Hint-free puzzles solved in a row.
    public var consecutiveIndependent: Int = 0
    /// Wrong or hint-assisted outcomes in a row.
    public var consecutiveStruggles: Int = 0
    /// Total attempts (incl. hint-assisted).
    public var attempts: Int = 0
    /// Correct attempts (incl. hint-assisted? no — hint-free only).
    public var hintFreeCorrect: Int = 0
    /// How often each misconception was diagnosed.
    public var misconceptionCounts: [MisconceptionKind: Int] = [:]
    public var state: MasteryState = .notStarted
    /// Date mastered (first time `mastered` was reached).
    public var masteredAt: Date?
    /// Spaced-review box 0..<intervals.count; advances on successful review.
    public var reviewBox: Int = 0
    /// Next scheduled review date (nil unless mastered).
    public var nextReviewDate: Date?
    /// Timestamp of the last outcome.
    public var lastOutcomeAt: Date?
    /// Whether the last activity used the walkthrough hint (achievement gating).
    public var usedWalkthroughThisSession: Bool = false

    public init() {}

    public var recentAccuracy: Double {
        guard !recentResults.isEmpty else { return 0 }
        return Double(recentResults.filter { $0 }.count) / Double(recentResults.count)
    }
}

/// What the engine wants the child to do next.
public enum AdaptiveDecision: Equatable, Sendable {
    /// Practise this topic at this difficulty.
    case practice(topicId: String, difficulty: Int)
    /// Drop back to a `hard` prerequisite that research says to reteach.
    case scaffold(toTopicId: String, reason: ScaffoldReason)
    /// A mastered topic is due for spaced re-practice.
    case review(topicId: String, difficulty: Int)
}

public enum ScaffoldReason: Equatable, Sendable {
    /// `reteachPrerequisiteId` from the diagnosed errorPattern.
    case researchRecommendation(fromTopicId: String)
    /// Repeated failure at difficulty 1 on a hard prerequisite edge.
    case repeatedStruggles(fromTopicId: String)
}

/// A recorded outcome, as fed to `AdaptiveEngine.apply`.
public struct Outcome: Equatable, Sendable {
    public var correct: Bool
    /// Deepest hint level used (nil = no help).
    public var maxHintLevel: HintLevel?
    /// Diagnosed misconception, if the validator caught one.
    public var misconception: MisconceptionKind?
    /// Evidence index the puzzle was tagged with.
    public var evidenceIndex: Int?
    public var difficulty: Int
    /// Response latency — recorded for parents, deliberately never used by
    /// the adaptive engine for ability judgements.
    public var latency: TimeInterval?

    public init(correct: Bool, maxHintLevel: HintLevel?, misconception: MisconceptionKind?,
                evidenceIndex: Int?, difficulty: Int, latency: TimeInterval? = nil) {
        self.correct = correct
        self.maxHintLevel = maxHintLevel
        self.misconception = misconception
        self.evidenceIndex = evidenceIndex
        self.difficulty = difficulty
        self.latency = latency
    }

    public var hintFree: Bool { maxHintLevel == nil }
}
