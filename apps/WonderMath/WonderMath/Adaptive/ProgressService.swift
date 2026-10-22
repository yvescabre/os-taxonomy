import Foundation
import SwiftData
import WonderMathCore

struct RecordResult {
    let progress: SkillProgress
    let xpGained: Int
    let chestOpened: Bool
    let newAchievements: [AchievementDef]
    let scaffold: AdaptiveDecision?
    let persistenceError: String?
}

@MainActor
final class ProgressService {
    private let context: ModelContext
    private let profile: ChildProfile
    private let appState: AppState
    private let engine: AdaptiveEngine
    private var playableTopicIds: Set<String> { Set(appState.registry.playableTopicIds) }

    init(context: ModelContext, profile: ChildProfile, appState: AppState) {
        self.context = context
        self.profile = profile
        self.appState = appState
        var config = AdaptiveEngine.Config()
        config.difficultyOffset = profile.difficultyOffset
        engine = AdaptiveEngine(config: config)
    }

    func progress(for topicId: String) -> SkillProgress? {
        record(for: topicId)?.progress()
    }

    func record(outcome: Outcome, topicId: String, secondsSpent: Int) -> RecordResult {
        guard let topic = appState.store.topic(topicId),
              let generator = appState.registry.generator(for: topicId) else {
            return RecordResult(progress: SkillProgress(), xpGained: 0, chestOpened: false,
                                newAchievements: [], scaffold: nil,
                                persistenceError: "Missing topic or puzzle generator")
        }

        let masteryRecord = record(for: topicId) ?? {
            let value = MasteryRecord(topicId: topicId, profile: profile)
            context.insert(value)
            return value
        }()
        let applied = engine.apply(outcome, to: masteryRecord.progress(), topic: topic,
                                   generator: generator, store: appState.store,
                                   playable: playableTopicIds, now: .now)
        masteryRecord.store(applied.progress)
        masteryRecord.totalSeconds += max(0, secondsSpent)

        let baseXP = Rewards.xp(correct: outcome.correct, difficulty: outcome.difficulty,
                                hintFree: outcome.hintFree)
        if outcome.correct { profile.puzzlesSolved += 1 }
        let chestOpened = outcome.correct && profile.puzzlesSolved > 0 && profile.puzzlesSolved.isMultiple(of: 5)
        let xpGained = baseXP + (chestOpened ? Rewards.chestBonus(puzzlesSolved: 5) : 0)
        profile.xp += xpGained

        let existingAchievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let alreadyUnlocked = Set(existingAchievements
            .filter { $0.profile?.id == profile.id }
            .map(\.achievementId))
        let masteredCount = allMasteryRecords().filter { $0.progress().state == .mastered }.count
        let adventuresCompleted = (try? context.fetch(FetchDescriptor<DailyAdventureLog>()))?
            .filter { $0.profile?.id == profile.id && $0.completedAt != nil }.count ?? 0
        let newlyUnlocked = unlockedAchievements(
            stats: ProgressStats(
                puzzlesSolved: profile.puzzlesSolved,
                masteredTopicCount: masteredCount,
                solvedAfterWalkthrough: outcome.correct && outcome.maxHintLevel == .walkthrough,
                distinctValidAnswersInOnePuzzle: 1,
                adventuresCompleted: adventuresCompleted
            ),
            alreadyUnlocked: alreadyUnlocked
        )
        for definition in newlyUnlocked {
            context.insert(Achievement(achievementId: definition.id, profile: profile))
        }

        do {
            try context.save()
            return RecordResult(progress: applied.progress, xpGained: xpGained,
                                chestOpened: chestOpened, newAchievements: newlyUnlocked,
                                scaffold: applied.scaffold, persistenceError: nil)
        } catch {
            return RecordResult(progress: applied.progress, xpGained: xpGained,
                                chestOpened: chestOpened, newAchievements: newlyUnlocked,
                                scaffold: applied.scaffold, persistenceError: error.localizedDescription)
        }
    }

    func isUnlocked(_ topicId: String) -> Bool {
        engine.isUnlocked(topicId, store: appState.store, playable: playableTopicIds) {
            self.progress(for: $0)
        }
    }

    func adjustedDifficulty(_ difficulty: Int) -> Int {
        engine.adjustedDifficulty(difficulty)
    }

    func nextDecision() -> AdaptiveDecision? {
        let allProgress = Dictionary(uniqueKeysWithValues: allMasteryRecords().map {
            ($0.topicId, $0.progress())
        })
        let due = engine.reviewsDue(progress: allProgress, now: .now)
        return engine.nextActivity(playableOrder: appState.playableOrder,
                                   unlocked: { self.isUnlocked($0) },
                                   progress: { allProgress[$0] },
                                   reviewsDue: due)
    }

    func todayPlan(now: Date = .now) -> (DailyAdventureLog, DailyAdventurePlan) {
        let planner = DailyAdventurePlanner()
        if let existing = allAdventureLogs().first(where: { $0.dateKey == planner.dateKey(now) }),
           let plan = existing.plan() {
            return (existing, plan)
        }
        let allProgress = Dictionary(uniqueKeysWithValues: allMasteryRecords().map {
            ($0.topicId, $0.progress())
        })
        let config = engine
        let plan = planner.plan(date: now, childAge: profile.age,
                                bridgeOrder: appState.playableOrder,
                                unlocked: { self.isUnlocked($0) },
                                progress: { allProgress[$0] },
                                reviewsDue: engine.reviewsDue(progress: allProgress, now: now),
                                engine: config)
        let log = DailyAdventureLog(dateKey: plan.dateKey, plan: plan, profile: profile)
        context.insert(log)
        try? context.save()
        return (log, plan)
    }

    func saveChanges() {
        try? context.save()
    }

    func completeAdventureStage(log: DailyAdventureLog, secondsSpent: Int, totalStages: Int) {
        log.stagesCompleted = min(totalStages, log.stagesCompleted + 1)
        log.secondsPlayed += max(0, secondsSpent)
        if log.stagesCompleted >= totalStages {
            log.completedAt = .now
            let achievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
            let alreadyUnlocked = Set(achievements
                .filter { $0.profile?.id == profile.id }
                .map(\.achievementId))
            let definitions = unlockedAchievements(
                stats: ProgressStats(
                    puzzlesSolved: profile.puzzlesSolved,
                    masteredTopicCount: allMasteryRecords().filter { $0.progress().state == .mastered }.count,
                    solvedAfterWalkthrough: false,
                    distinctValidAnswersInOnePuzzle: 1,
                    adventuresCompleted: 1
                ),
                alreadyUnlocked: alreadyUnlocked
            )
            for definition in definitions {
                context.insert(Achievement(achievementId: definition.id, profile: profile))
            }
        }
        try? context.save()
    }

    private func record(for topicId: String) -> MasteryRecord? {
        allMasteryRecords().first { $0.topicId == topicId }
    }

    private func allMasteryRecords() -> [MasteryRecord] {
        ((try? context.fetch(FetchDescriptor<MasteryRecord>())) ?? [])
            .filter { $0.profile?.id == profile.id }
    }

    private func allAdventureLogs() -> [DailyAdventureLog] {
        ((try? context.fetch(FetchDescriptor<DailyAdventureLog>())) ?? [])
            .filter { $0.profile?.id == profile.id }
    }
}
