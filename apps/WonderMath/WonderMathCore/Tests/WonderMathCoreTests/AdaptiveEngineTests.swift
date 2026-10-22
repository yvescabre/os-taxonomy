import XCTest
@testable import WonderMathCore

final class AdaptiveEngineTests: XCTestCase {

    var store: TaxonomyStore!
    var engine: AdaptiveEngine!
    var topic: Topic!
    var generator: (any PuzzleGenerator)!

    override func setUpWithError() throws {
        store = try TestSupport.loadStore()
        engine = AdaptiveEngine()
        topic = try XCTUnwrap(store.topic("mt_s2mfRBoTal")) // number bonds
        generator = TestSupport.registry.generator(for: topic.id)
    }

    private func correct(hintFree: Bool = true, evidence: Int = 0, difficulty: Int = 1) -> Outcome {
        Outcome(correct: true, maxHintLevel: hintFree ? nil : .nudge,
                misconception: nil, evidenceIndex: evidence, difficulty: difficulty)
    }

    private func wrong(kind: MisconceptionKind? = nil) -> Outcome {
        Outcome(correct: false, maxHintLevel: nil, misconception: kind,
                evidenceIndex: 0, difficulty: 1)
    }

    func testPromotesAfterThreeIndependent() throws {
        var p = SkillProgress()
        for _ in 0..<3 {
            p = engine.apply(correct(), to: p, topic: topic, generator: generator, store: store, now: TestSupport.now).progress
        }
        XCTAssertEqual(p.difficulty, 2)
        XCTAssertEqual(p.consecutiveIndependent, 0)
    }

    func testHintAssistedDoesNotPromote() throws {
        var p = SkillProgress()
        for _ in 0..<5 {
            p = engine.apply(correct(hintFree: false), to: p, topic: topic, generator: generator, store: store, now: TestSupport.now).progress
        }
        XCTAssertEqual(p.difficulty, 1)
    }

    func testDemotesAfterTwoStruggles() throws {
        var p = SkillProgress()
        p.difficulty = 3
        for _ in 0..<2 {
            p = engine.apply(wrong(), to: p, topic: topic, generator: generator, store: store, now: TestSupport.now).progress
        }
        XCTAssertEqual(p.difficulty, 2)
    }

    func testScaffoldsToHardPrerequisite() throws {
        // "Unknown in Addition & Subtraction" (hard prereq: equals sign).
        let t = try XCTUnwrap(store.topic("mt_3JgrHY221M"))
        let gen = TestSupport.registry.generator(for: t.id)!
        var p = SkillProgress()
        var scaffold: AdaptiveDecision?
        for _ in 0..<3 {
            let r = engine.apply(wrong(kind: .usedVisibleNumbers), to: p, topic: t, generator: gen, store: store, now: TestSupport.now)
            p = r.progress; scaffold = r.scaffold ?? scaffold
        }
        guard case .scaffold(let to, _) = scaffold else { return XCTFail("no scaffold") }
        XCTAssertEqual(to, "mt_oIzycTBeE4") // research reteach target for that misconception
    }

    func testMasteryRequiresEvidenceCoverage() throws {
        var p = SkillProgress()
        // Topic's assessable evidence indices.
        let forms = generator.mastery.evidenceForms.enumerated().compactMap { $0.element == nil ? nil : $0.offset }
        XCTAssertFalse(forms.isEmpty)
        var guard_ = 0
        while p.state != .mastered && guard_ < 200 {
            // Cycle evidence indices to earn all credits.
            let i = forms[guard_ % forms.count]
            p = engine.apply(correct(evidence: i, difficulty: p.difficulty),
                             to: p, topic: topic, generator: generator, store: store, now: TestSupport.now).progress
            guard_ += 1
        }
        XCTAssertEqual(p.state, .mastered)
        XCTAssertNotNil(p.masteredAt)
        XCTAssertNotNil(p.nextReviewDate)
    }

    func testMasteryNeedsAccuracyNotJustCredits() throws {
        var p = SkillProgress()
        // Sprinkle wrong answers so recent accuracy < 0.8.
        let forms = generator.mastery.evidenceForms.enumerated().compactMap { $0.element == nil ? nil : $0.offset }
        for i in 0..<30 {
            let outcome = (i % 3 == 2) ? wrong() : correct(evidence: forms[i % forms.count])
            p = engine.apply(outcome, to: p, topic: topic, generator: generator, store: store, now: TestSupport.now).progress
        }
        XCTAssertNotEqual(p.state, .mastered)
    }

    func testGatingUsesHardEdges() throws {
        // Unknown-A&S is locked until equals-sign is mastered.
        XCTAssertFalse(engine.isUnlocked("mt_3JgrHY221M", store: store) { _ in nil })
        XCTAssertTrue(engine.isUnlocked("mt_3JgrHY221M", store: store) { id in
            var p = SkillProgress(); p.state = id == "mt_oIzycTBeE4" ? .mastered : .notStarted
            return p
        })
    }

    func testReviewDueScheduling() throws {
        var p = SkillProgress()
        p.state = .mastered
        p.nextReviewDate = TestSupport.now.addingTimeInterval(-3600)
        let due = engine.reviewsDue(progress: ["t1": p], now: TestSupport.now)
        XCTAssertEqual(due, ["t1"])
        p.nextReviewDate = TestSupport.now.addingTimeInterval(3600)
        XCTAssertTrue(engine.reviewsDue(progress: ["t1": p], now: TestSupport.now).isEmpty)
    }

    func testNextActivityPriority() throws {
        let order = TestSupport.playableOrder(store)
        // Everything locked except first topic → practice it.
        let decision = engine.nextActivity(
            playableOrder: order,
            unlocked: { $0 == order[0] },
            progress: { _ in nil },
            reviewsDue: [])
        guard case .practice(let tid, let d) = decision else { return XCTFail() }
        XCTAssertEqual(tid, order[0]); XCTAssertEqual(d, 1)
    }
}

final class DailyAdventureTests: XCTestCase {

    func testPlanHasAllFiveStagesAndIsDeterministic() throws {
        let store = try TestSupport.loadStore()
        let order = TestSupport.playableOrder(store)
        let planner = DailyAdventurePlanner()
        let engine = AdaptiveEngine()
        let plan1 = planner.plan(
            date: TestSupport.now, childAge: 9, bridgeOrder: order,
            unlocked: { _ in true }, progress: { _ in nil }, reviewsDue: [], engine: engine)
        XCTAssertEqual(plan1.stages.map(\.kind),
                       [.warmup, .maths, .logic, .creative, .challenge])
        XCTAssertTrue(plan1.stages.allSatisfy { (1...5).contains($0.difficulty) })
        XCTAssertTrue(plan1.stages.allSatisfy { $0.rounds >= 1 })
        let plan2 = planner.plan(
            date: TestSupport.now, childAge: 9, bridgeOrder: order,
            unlocked: { _ in true }, progress: { _ in nil }, reviewsDue: [], engine: engine)
        XCTAssertEqual(plan1.stages, plan2.stages)
    }
}

final class ProgressionTests: XCTestCase {

    func testAchievementRules() {
        let stats = ProgressStats(puzzlesSolved: 12, masteredTopicCount: 2,
                                  solvedAfterWalkthrough: true,
                                  distinctValidAnswersInOnePuzzle: 4,
                                  adventuresCompleted: 1)
        let new = Set(unlockedAchievements(stats: stats, alreadyUnlocked: ["first_bridge"]).map(\.id))
        XCTAssertFalse(new.contains("first_bridge")) // already unlocked
        XCTAssertTrue(new.contains("ten_bridges"))
        XCTAssertTrue(new.contains("first_mastery"))
        XCTAssertTrue(new.contains("learned_then_nailed"))
        XCTAssertTrue(new.contains("many_ways"))
        XCTAssertTrue(new.contains("adventure_done"))
    }

    func testXpNeverPunishesHints() {
        XCTAssertGreaterThan(Rewards.xp(correct: true, difficulty: 3, hintFree: false), 0)
        XCTAssertEqual(Rewards.xp(correct: false, difficulty: 3, hintFree: true), 2)
        XCTAssertGreaterThan(Rewards.xp(correct: true, difficulty: 3, hintFree: true),
                             Rewards.xp(correct: true, difficulty: 3, hintFree: false))
    }
}
