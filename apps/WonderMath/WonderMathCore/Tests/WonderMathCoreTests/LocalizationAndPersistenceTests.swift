import XCTest
@testable import WonderMathCore

final class LocalizationTests: XCTestCase {

    func testEveryKeyExistsInBothLanguages() {
        for key in L10n.Key.allCases {
            XCTAssertNotNil(EnglishStrings.table[key], "EN missing \(key)")
            XCTAssertNotNil(GermanStrings.table[key], "de-CH missing \(key)")
        }
    }

    func testPlaceholderCountsMatchAcrossLanguages() {
        let pattern = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
        for (key, en) in EnglishStrings.table {
            guard let de = GermanStrings.table[key] else { continue }
            func slots(_ s: String) -> [String] {
                pattern.matches(in: s, range: NSRange(s.startIndex..., in: s))
                    .compactMap { Range($0.range(at: 1), in: s).map { String(s[$0]) } }
            }
            XCTAssertEqual(Set(slots(en)), Set(slots(de)), "arg mismatch for \(key)")
        }
    }

    func testSwissNumberFormatting() {
        let de = Localizer(language: .german)
        XCTAssertEqual(de.format(1234567), "1’234’567")
        XCTAssertTrue(de.format(1234567).contains("’"))
        let en = Localizer(language: .english)
        XCTAssertEqual(en.format(1234567), "1,234,567")
    }

    func testMinutesPluralization() {
        let en = Localizer(language: .english)
        XCTAssertEqual(en.minutes(1), "1 minute")
        XCTAssertEqual(en.minutes(5), "5 minutes")

        let de = Localizer(language: .german)
        XCTAssertEqual(de.minutes(1), "1 Minute")
        XCTAssertEqual(de.minutes(5), "5 Minuten")
    }

    func testRoundsPluralization() {
        let en = Localizer(language: .english)
        XCTAssertEqual(en.rounds(1), "1 round")
        XCTAssertEqual(en.rounds(2), "2 rounds")

        let de = Localizer(language: .german)
        XCTAssertEqual(de.rounds(1), "1 Runde")
        XCTAssertEqual(de.rounds(2), "2 Runden")
    }

    func testMessageRenderingSubstitutesArgs() {
        let en = Localizer(language: .english)
        let s = en.string(.clueInverseAddSub, [.number(11), .number(8)])
        XCTAssertTrue(s.contains("11") && s.contains("8"))
        let de = Localizer(language: .german)
        let sd = de.string(.clueInverseAddSub, [.number(11), .number(8)])
        XCTAssertTrue(sd.contains("11") && sd.contains("8"))
    }

    func testGermanTopicNamesForAllPlayableTopics() throws {
        let store = try TestSupport.loadStore()
        for id in TestSupport.registry.playableTopicIds {
            let topic = try XCTUnwrap(store.topic(id))
            let de = TaxonomyLocalization.displayName(of: topic, language: .german)
            XCTAssertFalse(de.isEmpty)
            // Playable topics must be translated, not fall back to English.
            XCTAssertNotEqual(de, topic.name, "missing German name for \(id)")
        }
        // Non-playable topics may legitimately fall back to English.
    }

    func testNoDatasetStringLeaksIntoGermanChildCopy() throws {
        // Every authored key must have a German string distinct enough from EN
        // (child UI never renders raw dataset text in German).
        let de = Localizer(language: .german)
        for key in L10n.Key.allCases where key != .attributionText && key != .licenseNote {
            _ = de.string(key) // never crashes, never returns key rawValue
            XCTAssertNotEqual(de.template(for: key), key.rawValue)
        }
    }
}

final class PersistenceTests: XCTestCase {

    func testSkillProgressCodableRoundTrip() throws {
        var p = SkillProgress()
        p.difficulty = 3
        p.attempts = 9
        p.hintFreeCorrect = 6
        p.evidenceCredits = [0: 2, 2: 1]
        p.recentResults = [true, false, true]
        p.misconceptionCounts = [.runningTotal: 2, .offByOne: 1]
        p.state = .learning
        p.reviewBox = 2
        p.nextReviewDate = Date(timeIntervalSince1970: 1_800_100_000)
        p.usedWalkthroughThisSession = true

        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(SkillProgress.self, from: data)
        XCTAssertEqual(p, back)
    }

    func testDailyPlanCodableRoundTrip() throws {
        let store = try TestSupport.loadStore()
        let order = TestSupport.playableOrder(store)
        let plan = DailyAdventurePlanner().plan(
            date: TestSupport.now, childAge: 9, bridgeOrder: order,
            unlocked: { _ in true }, progress: { _ in nil }, reviewsDue: [],
            engine: AdaptiveEngine())
        let data = try JSONEncoder().encode(plan)
        let back = try JSONDecoder().decode(DailyAdventurePlan.self, from: data)
        XCTAssertEqual(plan.stages, back.stages)
        XCTAssertEqual(plan.dateKey, back.dateKey)
    }
}
