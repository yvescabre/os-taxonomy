import Foundation

/// XP and achievements. Deliberately boring: no randomness in rewards
/// (no loot boxes), no streaks, no pressure mechanics.
public enum Rewards {

    /// XP for a puzzle: base + difficulty bonus + tiny hint-free bonus.
    /// Using hints never costs XP — help-seeking is rewarded, not punished.
    public static func xp(correct: Bool, difficulty: Int, hintFree: Bool) -> Int {
        guard correct else { return 2 } // a thank-you for trying
        return 10 + 2 * difficulty + (hintFree ? 3 : 0)
    }

    /// Bonus XP when a stage/session wraps up (the "treasure chest").
    public static func chestBonus(puzzlesSolved: Int) -> Int {
        puzzlesSolved >= 5 ? 30 : puzzlesSolved >= 3 ? 20 : 10
    }
}

public struct AchievementDef: Codable, Hashable, Sendable {
    public let id: String
    public let nameKey: L10n.Key

    public init(id: String, nameKey: L10n.Key) {
        self.id = id
        self.nameKey = nameKey
    }
}

public enum AchievementCatalog {
    public static let all: [AchievementDef] = [
        AchievementDef(id: "first_bridge", nameKey: .achFirstBridge),
        AchievementDef(id: "ten_bridges", nameKey: .achTenBridges),
        AchievementDef(id: "first_mastery", nameKey: .achMasteredSkill),
        AchievementDef(id: "learned_then_nailed", nameKey: .achUsedWalkthroughThenSolved),
        AchievementDef(id: "many_ways", nameKey: .achFoundMultipleWays),
        AchievementDef(id: "adventure_done", nameKey: .achFinishedAdventure),
    ]
}

/// Stats snapshot for achievement evaluation.
public struct ProgressStats: Sendable {
    public var puzzlesSolved: Int
    public var masteredTopicCount: Int
    public var solvedAfterWalkthrough: Bool
    public var distinctValidAnswersInOnePuzzle: Int
    public var adventuresCompleted: Int

    public init(puzzlesSolved: Int, masteredTopicCount: Int,
                solvedAfterWalkthrough: Bool, distinctValidAnswersInOnePuzzle: Int,
                adventuresCompleted: Int) {
        self.puzzlesSolved = puzzlesSolved
        self.masteredTopicCount = masteredTopicCount
        self.solvedAfterWalkthrough = solvedAfterWalkthrough
        self.distinctValidAnswersInOnePuzzle = distinctValidAnswersInOnePuzzle
        self.adventuresCompleted = adventuresCompleted
    }
}

/// Evaluate which achievements are newly unlocked.
public func unlockedAchievements(stats: ProgressStats,
                                 alreadyUnlocked: Set<String>) -> [AchievementDef] {
    AchievementCatalog.all.filter { def in
        guard !alreadyUnlocked.contains(def.id) else { return false }
        switch def.id {
        case "first_bridge": return stats.puzzlesSolved >= 1
        case "ten_bridges": return stats.puzzlesSolved >= 10
        case "first_mastery": return stats.masteredTopicCount >= 1
        case "learned_then_nailed": return stats.solvedAfterWalkthrough
        case "many_ways": return stats.distinctValidAnswersInOnePuzzle >= 3
        case "adventure_done": return stats.adventuresCompleted >= 1
        default: return false
        }
    }
}
