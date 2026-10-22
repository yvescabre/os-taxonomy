import Foundation

/// A daily adventure stitches five short stages into one journey:
/// warm-up → maths → logic/visual → creative → personalised challenge.
/// The plan is computed deterministically per (date, profile) and each stage
/// adapts through the adaptive engine.
public struct DailyAdventurePlan: Codable, Sendable {
    public let dateKey: String            // "YYYY-MM-DD" UTC
    public let stages: [AdventureStage]

    public struct AdventureStage: Codable, Hashable, Sendable {
        public let kind: StageKind
        public let topicId: String
        public let rounds: Int
        public let difficulty: Int

        public init(kind: StageKind, topicId: String, rounds: Int, difficulty: Int) {
            self.kind = kind
            self.topicId = topicId
            self.rounds = rounds
            self.difficulty = difficulty
        }
    }

    public enum StageKind: String, Codable, CaseIterable, Sendable {
        case warmup, maths, logic, creative, challenge

        public var titleKey: L10n.Key {
            switch self {
            case .warmup: return .stageWarmup
            case .maths: return .stageMaths
            case .logic: return .stageLogic
            case .creative: return .stageCreative
            case .challenge: return .stageChallenge
            }
        }
    }
}

public struct DailyAdventurePlanner: Sendable {
    public init() {}

    /// Topics that serve the "logic/visual" stage (the pattern path set).
    public var logicTopicIds: [String] { PatternPathLibrary.profiles.map(\.topicId) }

    /// Build today's plan. `bridgeOrder` is the topological world path;
    /// `progress` returns per-topic progress.
    public func plan(date: Date,
                     childAge: Int,
                     bridgeOrder: [String],
                     unlocked: (String) -> Bool,
                     progress: (String) -> SkillProgress?,
                     reviewsDue: [String],
                     engine: AdaptiveEngine) -> DailyAdventurePlan {
        let key = dateKey(date)
        var rng = SeededRandom(seed: SeededRandom.seed(["adventure", key]))

        // Warm-up: an unlocked topic the child has seen before (or the first
        // unlocked one) at gentle difficulty.
        let practiced = bridgeOrder.filter { (progress($0)?.attempts ?? 0) > 0 && unlocked($0) }
        let warmupTopic = practiced.first ?? bridgeOrder.first { unlocked($0) } ?? bridgeOrder[0]
        let warmup = DailyAdventurePlan.AdventureStage(
            kind: .warmup, topicId: warmupTopic, rounds: 2,
            difficulty: max(1, (progress(warmupTopic)?.difficulty ?? 1) - 1))

        // Maths: the frontier (first unlocked unmastered) at its difficulty.
        let mathsTopic = bridgeOrder.first { unlocked($0) && (progress($0)?.state != .mastered) }
            ?? warmupTopic
        let maths = DailyAdventurePlan.AdventureStage(
            kind: .maths, topicId: mathsTopic, rounds: 3,
            difficulty: progress(mathsTopic)?.difficulty ?? 1)

        // Logic/visual: a pattern topic age-band-suitable for the child.
        let logicTopic = logicTopicIds.first { unlocked($0) } ?? logicTopicIds[0]
        let logic = DailyAdventurePlan.AdventureStage(
            kind: .logic, topicId: logicTopic, rounds: 2,
            difficulty: progress(logicTopic)?.difficulty ?? 1)

        // Creative: build-your-own on a mid-path bridge topic.
        let creativeBase = bridgeOrder[min(bridgeOrder.count - 1,
                                           max(0, bridgeOrder.count / 3))]
        let creative = DailyAdventurePlan.AdventureStage(
            kind: .creative, topicId: creativeBase, rounds: 1,
            difficulty: progress(creativeBase)?.difficulty ?? 1)

        // Personalised challenge: scaffold target if a topic is struggling,
        // else the frontier topic +1 difficulty (clamped).
        var challenge = DailyAdventurePlan.AdventureStage(
            kind: .challenge, topicId: mathsTopic, rounds: 2,
            difficulty: min(5, (progress(mathsTopic)?.difficulty ?? 1) + 1))
        let struggling = bridgeOrder
            .map { ($0, progress($0)) }
            .filter { ($0.1?.consecutiveStruggles ?? 0) >= 2 && unlocked($0.0) }
        if let (tid, _) = struggling.first, let p = progress(tid) {
            challenge = DailyAdventurePlan.AdventureStage(
                kind: .challenge, topicId: tid, rounds: 2, difficulty: p.difficulty)
        } else {
            _ = rng.next()
        }

        // Review injection: any mastered topic due today replaces the warm-up.
        var stages = [warmup, maths, logic, creative, challenge]
        if let reviewId = reviewsDue.first, let p = progress(reviewId) {
            stages[0] = DailyAdventurePlan.AdventureStage(
                kind: .warmup, topicId: reviewId, rounds: 2,
                difficulty: engine.adjustedDifficulty(p.difficulty))
        }
        return DailyAdventurePlan(dateKey: key, stages: stages)
    }

    public func dateKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}
