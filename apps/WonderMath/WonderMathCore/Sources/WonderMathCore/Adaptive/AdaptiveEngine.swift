import Foundation

/// Local, per-skill adaptive engine.
///
/// Signals:
///   - PROMOTE: 3 hint-free correct outcomes in a row → difficulty +1 (cap 5).
///   - DEMOTE: 2 struggles (wrong or hint-assisted) in a row → difficulty −1.
///   - SCAFFOLD: 3 struggles at difficulty 1 → drop to a `hard` prerequisite
///     (preferring the research `reteachPrerequisiteId` when playable).
///   - MASTERED: every puzzle-assessable evidence item has ≥required credits
///     AND recent accuracy ≥ threshold → entered `mastered`, scheduled into
///     spaced review (Leitner boxes: 1/3/7/14/30 days).
///   - REVIEW: mastered + nextReviewDate ≤ now → served as re-practice.
/// Response speed is recorded but NEVER used as the ability signal.
public struct AdaptiveEngine: Sendable {

    public struct Config: Sendable {
        public var promoteAfterIndependent = 3
        public var demoteAfterStruggles = 2
        public var scaffoldAfterStruggles = 3
        public var maxDifficulty = 5
        /// Spaced-review intervals in days, Leitner-style.
        public var reviewIntervalsDays = [1, 3, 7, 14, 30]
        /// Parent difficulty offset (-1 gentler, +1 bolder).
        public var difficultyOffset = 0

        public init() {}
    }

    public let config: Config
    public init(config: Config = Config()) { self.config = config }

    // MARK: - Outcome application

    /// Fold one outcome into `progress`. Pure function: returns updated
    /// progress plus an optional scaffold suggestion for the caller.
    @discardableResult
    public func apply(_ outcome: Outcome,
                      to progress: SkillProgress,
                      topic: Topic,
                      generator: any PuzzleGenerator,
                      store: TaxonomyStore,
                      now: Date) -> (progress: SkillProgress, scaffold: AdaptiveDecision?) {
        var p = progress
        let criteria = generator.mastery
        p.attempts += 1
        p.lastOutcomeAt = now
        if outcome.maxHintLevel == .walkthrough { p.usedWalkthroughThisSession = true }

        if outcome.correct && outcome.hintFree {
            p.hintFreeCorrect += 1
            p.independentAttempts += 1
            p.consecutiveIndependent += 1
            p.consecutiveStruggles = 0
            p.recentResults.append(true)
            if let i = outcome.evidenceIndex, outcome.difficulty >= criteria.minimumDifficulty {
                p.evidenceCredits[i, default: 0] += 1
            }
        } else {
            p.consecutiveIndependent = 0
            p.consecutiveStruggles += 1
            p.recentResults.append(false)
            if let k = outcome.misconception {
                p.misconceptionCounts[k, default: 0] += 1
            }
        }
        if p.recentResults.count > criteria.recentWindow {
            p.recentResults.removeFirst(p.recentResults.count - criteria.recentWindow)
        }
        if p.state == .notStarted { p.state = .learning }

        // Mastered-topic review outcome handling.
        if p.state == .mastered, outcome.correct {
            p.reviewBox = min(p.reviewBox + 1, config.reviewIntervalsDays.count - 1)
            p.nextReviewDate = schedule(from: now, box: p.reviewBox)
        }

        // Mastery check (learning → mastered).
        if p.state == .learning, meetsMastery(progress: p, criteria: criteria) {
            p.state = .mastered
            p.masteredAt = now
            p.reviewBox = 0
            p.nextReviewDate = schedule(from: now, box: 0)
        }

        // Difficulty transitions.
        if p.consecutiveIndependent >= config.promoteAfterIndependent, p.difficulty < config.maxDifficulty {
            p.difficulty += 1
            p.consecutiveIndependent = 0
        }
        if p.consecutiveStruggles >= config.demoteAfterStruggles, p.difficulty > 1 {
            p.difficulty -= 1
            p.consecutiveStruggles = 0
        }

        // Scaffold decision: repeated failure at floor difficulty.
        var scaffold: AdaptiveDecision? = nil
        if p.difficulty == 1, p.consecutiveStruggles >= config.scaffoldAfterStruggles {
            scaffold = scaffoldTarget(for: topic.id, outcome: outcome, store: store)
            p.consecutiveStruggles = 0 // avoid spamming the decision
        }
        return (p, scaffold)
    }

    /// Whether progress meets all puzzle-assessable evidence + accuracy.
    public func meetsMastery(progress p: SkillProgress, criteria: MasteryCriteria) -> Bool {
        var assessable = 0
        for (i, forms) in criteria.evidenceForms.enumerated() {
            guard forms != nil else { continue } // conversation-only evidence
            assessable += 1
            if (p.evidenceCredits[i] ?? 0) < criteria.creditsPerEvidence { return false }
        }
        guard assessable > 0 else { return false }
        let window = min(criteria.recentWindow, p.recentResults.count)
        guard window > 0 else { return false }
        let recent = p.recentResults.suffix(window).filter { $0 }.count
        return Double(recent) / Double(window) >= criteria.minimumAccuracy
    }

    // MARK: - Scaffolding via `hard` prerequisite edges

    /// Pick a reteach target: prefer the diagnosed pattern's
    /// `reteachPrerequisiteId` when it's bundled, else the weakest playable
    /// `hard` prerequisite (checked by caller-supplied mastery), else nil.
    public func scaffoldTarget(for topicId: String,
                               outcome: Outcome,
                               store: TaxonomyStore,
                               progressLookup: (String) -> SkillProgress? = { _ in nil }) -> AdaptiveDecision? {
        // 1) Research recommendation from the last diagnosis.
        if let kind = outcome.misconception,
           let record = store.research(for: topicId),
           let pattern = ErrorPatternMatcher.match(kind, in: record),
           let reteach = pattern.reteachPrerequisiteId,
           store.topic(reteach) != nil {
            return .scaffold(toTopicId: reteach, reason: .researchRecommendation(fromTopicId: topicId))
        }
        // 2) Weakest playable hard prerequisite (lowest mastery, prefer
        //    unmastered ones).
        let hard = store.graph.hardPrerequisites(of: topicId)
            .map(\.prerequisiteId)
            .filter { store.topic($0) != nil }
        if let weakest = hard
            .map({ ($0, progressLookup($0)) })
            .filter({ $0.1?.state != .mastered })
            .min(by: { ($0.1?.hintFreeCorrect ?? 0) < ($1.1?.hintFreeCorrect ?? 0) }) {
            return .scaffold(toTopicId: weakest.0, reason: .repeatedStruggles(fromTopicId: topicId))
        }
        return nil
    }

    // MARK: - Gating & review

    /// A topic unlocks once every bundled `hard` prerequisite is mastered
    /// (prerequisites outside the subset are treated as assumed).
    public func isUnlocked(_ topicId: String, store: TaxonomyStore,
                           progress: (String) -> SkillProgress?) -> Bool {
        for dep in store.graph.hardPrerequisites(of: topicId) {
            if progress(dep.prerequisiteId)?.state != .mastered { return false }
        }
        return true
    }

    /// Mastered topics due for spaced review, soonest first.
    public func reviewsDue(progress: [String: SkillProgress], now: Date) -> [String] {
        progress
            .filter { _, p in
                p.state == .mastered && (p.nextReviewDate.map { $0 <= now } ?? false)
            }
            .sorted { (a, b) in (a.value.nextReviewDate ?? .distantFuture) < (b.value.nextReviewDate ?? .distantFuture) }
            .map(\.key)
    }

    /// Choose the next activity in a world's playable path.
    /// Priority: reviews due → first unlocked unmastered playable topic →
    /// scaffold if a topic is stuck → highest-difficulty practice.
    public func nextActivity(playableOrder: [String],
                             unlocked: (String) -> Bool,
                             progress: (String) -> SkillProgress?,
                             reviewsDue: [String]) -> AdaptiveDecision? {
        if let reviewId = reviewsDue.first(where: { playableOrder.contains($0) }),
           let p = progress(reviewId) {
            return .review(topicId: reviewId, difficulty: adjustedDifficulty(p.difficulty))
        }
        for topicId in playableOrder where unlocked(topicId) {
            let p = progress(topicId) ?? SkillProgress()
            if p.state != .mastered {
                return .practice(topicId: topicId, difficulty: adjustedDifficulty(p.difficulty))
            }
        }
        return nil
    }

    /// Parent-set difficulty offset applied to computed difficulty.
    public func adjustedDifficulty(_ d: Int) -> Int {
        min(config.maxDifficulty, max(1, d + config.difficultyOffset))
    }

    private func schedule(from now: Date, box: Int) -> Date {
        let days = config.reviewIntervalsDays[min(box, config.reviewIntervalsDays.count - 1)]
        return now.addingTimeInterval(TimeInterval(days) * 86400)
    }
}
