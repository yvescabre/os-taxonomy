import Foundation
import SwiftData
import WonderMathCore

/// A child's local profile. Everything stays on-device.
@Model
final class ChildProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var age: Int
    var languageCode: String          // AppLanguage rawValue
    var companionSpecies: String
    var companionColor: String
    var companionAccessory: String
    var xp: Int
    var audioEnabled: Bool
    var difficultyOffset: Int         // -1 gentler … +1 bolder
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MasteryRecord.profile)
    var mastery: [MasteryRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \Achievement.profile)
    var achievements: [Achievement] = []

    @Relationship(deleteRule: .cascade, inverse: \DailyAdventureLog.profile)
    var adventures: [DailyAdventureLog] = []

    init(id: UUID = UUID(), name: String, age: Int, languageCode: String = "en",
         companionSpecies: String = "fox", companionColor: String = "orange",
         companionAccessory: String = "none", xp: Int = 0,
         audioEnabled: Bool = true, difficultyOffset: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.age = age
        self.languageCode = languageCode
        self.companionSpecies = companionSpecies
        self.companionColor = companionColor
        self.companionAccessory = companionAccessory
        self.xp = xp
        self.audioEnabled = audioEnabled
        self.difficultyOffset = difficultyOffset
        self.createdAt = createdAt
    }

    var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .english }
}

/// Per-topic mastery row. `progressJSON` holds the Codable `SkillProgress`
/// value used by the adaptive engine; summary fields stay queryable.
@Model
final class MasteryRecord {
    var topicId: String
    var stateRaw: String
    var difficulty: Int
    var attempts: Int
    var hintFreeCorrect: Int
    var lastOutcomeAt: Date?
    var masteredAt: Date?
    var nextReviewDate: Date?
    /// Serialized `SkillProgress` (JSON). Authoritative for the engine.
    var progressJSON: Data
    var totalSeconds: Int             // time spent practising this topic
    var profile: ChildProfile?

    init(topicId: String, profile: ChildProfile?) {
        self.topicId = topicId
        self.stateRaw = MasteryState.notStarted.rawValue
        self.difficulty = 1
        self.attempts = 0
        self.hintFreeCorrect = 0
        self.progressJSON = (try? JSONEncoder().encode(SkillProgress())) ?? Data()
        self.totalSeconds = 0
        self.profile = profile
    }

    func progress() -> SkillProgress {
        (try? JSONDecoder().decode(SkillProgress.self, from: progressJSON)) ?? SkillProgress()
    }

    func store(_ p: SkillProgress) {
        progressJSON = (try? JSONEncoder().encode(p)) ?? Data()
        stateRaw = p.state.rawValue
        difficulty = p.difficulty
        attempts = p.attempts
        hintFreeCorrect = p.hintFreeCorrect
        lastOutcomeAt = p.lastOutcomeAt
        masteredAt = p.masteredAt
        nextReviewDate = p.nextReviewDate
    }
}

@Model
final class Achievement {
    var achievementId: String
    var unlockedAt: Date
    var profile: ChildProfile?

    init(achievementId: String, unlockedAt: Date = .now, profile: ChildProfile?) {
        self.achievementId = achievementId
        self.unlockedAt = unlockedAt
        self.profile = profile
    }
}

/// One row per day's adventure (stage completion + time, deterministic plan).
@Model
final class DailyAdventureLog {
    var dateKey: String               // YYYY-MM-DD UTC
    var planJSON: Data                // serialized DailyAdventurePlan
    var stagesCompleted: Int
    var secondsPlayed: Int
    var completedAt: Date?
    var profile: ChildProfile?

    init(dateKey: String, plan: DailyAdventurePlan, profile: ChildProfile?) {
        self.dateKey = dateKey
        self.planJSON = (try? JSONEncoder().encode(plan)) ?? Data()
        self.stagesCompleted = 0
        self.secondsPlayed = 0
        self.profile = profile
    }

    func plan() -> DailyAdventurePlan? {
        try? JSONDecoder().decode(DailyAdventurePlan.self, from: planJSON)
    }
}
