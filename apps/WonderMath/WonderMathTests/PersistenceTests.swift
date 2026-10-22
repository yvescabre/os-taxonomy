import XCTest
import SwiftData
import WonderMathCore
@testable import WonderMath

@MainActor
final class PersistenceTests: XCTestCase {
    func testProgressRewardsAndAdventureLogSurviveRefetch() async throws {
        let schema = Schema([
            ChildProfile.self,
            MasteryRecord.self,
            Achievement.self,
            DailyAdventureLog.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let profile = ChildProfile(name: "Mia", age: 8)
        context.insert(profile)
        try context.save()

        let appState = AppState()
        appState.load()
        for _ in 0..<200 {
            if case .ready = appState.phase { break }
            if case .failed(let message) = appState.phase {
                XCTFail("Taxonomy failed to load: \(message)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        guard case .ready = appState.phase,
              let topicId = appState.playableOrder.first else {
            XCTFail("Taxonomy did not become ready")
            return
        }

        let service = ProgressService(context: context, profile: profile, appState: appState)
        let outcomes = [
            Outcome(correct: true, maxHintLevel: nil, misconception: nil,
                    evidenceIndex: 0, difficulty: 1),
            Outcome(correct: false, maxHintLevel: .nudge, misconception: .offByOne,
                    evidenceIndex: 0, difficulty: 1),
            Outcome(correct: true, maxHintLevel: .clue, misconception: nil,
                    evidenceIndex: 0, difficulty: 1),
            Outcome(correct: true, maxHintLevel: nil, misconception: nil,
                    evidenceIndex: 0, difficulty: 1),
            Outcome(correct: true, maxHintLevel: nil, misconception: nil,
                    evidenceIndex: 0, difficulty: 1),
            Outcome(correct: true, maxHintLevel: nil, misconception: nil,
                    evidenceIndex: 0, difficulty: 1),
        ]
        var results: [RecordResult] = []
        for outcome in outcomes {
            results.append(service.record(outcome: outcome, topicId: topicId, secondsSpent: 12))
        }
        XCTAssertTrue(results.last?.chestOpened == true)
        let expectedState = try XCTUnwrap(service.progress(for: topicId)?.state)

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let firstPlan = service.todayPlan(now: now)
        let secondPlan = service.todayPlan(now: now)
        XCTAssertEqual(firstPlan.0.persistentModelID, secondPlan.0.persistentModelID)
        XCTAssertEqual(firstPlan.1.dateKey, secondPlan.1.dateKey)

        let refetchedContext = ModelContext(container)
        let persistedProfile = try XCTUnwrap(
            refetchedContext.fetch(FetchDescriptor<ChildProfile>())
                .first { $0.id == profile.id }
        )
        let persistedRecord = try XCTUnwrap(
            refetchedContext.fetch(FetchDescriptor<MasteryRecord>())
                .first { $0.profile?.id == profile.id && $0.topicId == topicId }
        )
        XCTAssertEqual(persistedRecord.progress().attempts, outcomes.count)
        XCTAssertEqual(persistedRecord.attempts, outcomes.count)
        XCTAssertEqual(persistedRecord.progress().state, expectedState)
        XCTAssertEqual(persistedRecord.progress().recentResults, [true, false, false, true, true, true])
        XCTAssertEqual(persistedRecord.totalSeconds, outcomes.count * 12)
        XCTAssertEqual(persistedProfile.puzzlesSolved, 5)
        XCTAssertEqual(persistedProfile.xp, outcomes.reduce(0) {
            $0 + Rewards.xp(correct: $1.correct, difficulty: $1.difficulty, hintFree: $1.hintFree)
        } + Rewards.chestBonus(puzzlesSolved: 5))
        XCTAssertTrue(refetchedContext.fetch(FetchDescriptor<Achievement>())
            .contains { $0.profile?.id == profile.id && $0.achievementId == "first_bridge" })
        XCTAssertEqual(refetchedContext.fetch(FetchDescriptor<DailyAdventureLog>())
            .filter { $0.profile?.id == profile.id && $0.dateKey == firstPlan.1.dateKey }.count, 1)
    }
}
