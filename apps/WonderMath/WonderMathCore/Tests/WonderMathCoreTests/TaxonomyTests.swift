import XCTest
@testable import WonderMathCore

final class TaxonomyStoreTests: XCTestCase {

    func testLoadsBundledSubset() throws {
        let store = try TestSupport.loadStore()
        XCTAssertEqual(store.topics.count, 592)
        XCTAssertEqual(store.dependencies.count, 1165)
        XCTAssertEqual(store.records.count, 455)
        XCTAssertEqual(store.topics(inSubject: "Mathematics").count, 535)
        XCTAssertEqual(store.topics(inSubject: "Computing").count, 57)
    }

    func testLookupAndResearchPresence() throws {
        let store = try TestSupport.loadStore()
        let topic = try XCTUnwrap(store.topic("mt_3JgrHY221M"))
        XCTAssertEqual(topic.name, "Unknown in Addition & Subtraction")
        XCTAssertNotNil(store.research(for: topic.id))
        // Topics in `coverage.missingTopicIds` must have no record.
        let missing = store.coverage?.missingTopicIds ?? []
        XCTAssertFalse(missing.isEmpty)
        for id in missing { XCTAssertNil(store.research(for: id)) }
    }

    func testAssessmentPromptNameSubstitution() throws {
        let store = try TestSupport.loadStore()
        let topic = try XCTUnwrap(store.topic("mt_3JgrHY221M"))
        let prompt = topic.assessmentPrompt(forChild: "Maya")
        XCTAssertFalse(prompt.contains("{{name}}"))
        XCTAssertTrue(prompt.contains("Maya"))
        let neutral = topic.assessmentPrompt(forChild: nil)
        XCTAssertFalse(neutral.contains("{{name}}"))
    }

    func testEveryPlayableTopicExistsAndIsInBand() throws {
        let store = try TestSupport.loadStore()
        for id in TestSupport.registry.playableTopicIds {
            let t = try XCTUnwrap(store.topic(id), "missing topic \(id)")
            XCTAssertLessThanOrEqual(t.ageRangeStart, 12)
            XCTAssertGreaterThanOrEqual(t.ageRangeEnd, 7)
        }
    }
}

final class SkillGraphTests: XCTestCase {

    func testPrerequisitesAndUnlocks() throws {
        let store = try TestSupport.loadStore()
        let g = store.graph
        // "Unknown in Addition & Subtraction" has hard prereq "What the equals sign means".
        let hard = g.hardPrerequisites(of: "mt_3JgrHY221M").map(\.prerequisiteId)
        XCTAssertTrue(hard.contains("mt_oIzycTBeE4"))
        // Reversing: equals-sign unlocks unknown-A&S.
        let unlocked = g.unlocks("mt_oIzycTBeE4", strength: .hard).map(\.topicId)
        XCTAssertTrue(unlocked.contains("mt_3JgrHY221M"))
    }

    func testTopologicalOrderRespectsEdges() throws {
        let store = try TestSupport.loadStore()
        let ids = Set(store.topics.map(\.id))
        let order = store.graph.topologicalOrder(of: ids) { store.topic($0) }
        XCTAssertEqual(Set(order), ids)
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        for dep in store.dependencies {
            guard let after = position[dep.topicId], let before = position[dep.prerequisiteId] else { continue }
            XCTAssertLessThan(before, after, "\(dep.prerequisiteId) must precede \(dep.topicId)")
        }
    }

    func testSubsetIsAcyclic() throws {
        let store = try TestSupport.loadStore()
        XCTAssertTrue(store.graph.isAcyclic(Set(store.topics.map(\.id))))
    }

    func testToleratesDanglingEdges() {
        let g = SkillGraph(dependencies: [
            Dependency(topicId: "a", prerequisiteId: "external", strength: .hard, reason: nil),
            Dependency(topicId: "a", prerequisiteId: "b", strength: .hard, reason: nil),
        ], knownIds: ["a", "b"])
        XCTAssertEqual(g.hardPrerequisites(of: "a").count, 1) // external dropped
    }
}

final class WorldCatalogTests: XCTestCase {

    func testAllPlayableTopicsLiveInWorldOne() throws {
        let store = try TestSupport.loadStore()
        let w1 = Set(WorldCatalog.topicIds(for: .numberKingdom, in: store))
        for id in TestSupport.registry.playableTopicIds {
            XCTAssertTrue(w1.contains(id), "\(id) not in Number Kingdom domain set")
        }
    }

    func testWorldsCoverBundledSubjects() throws {
        let store = try TestSupport.loadStore()
        var covered = Set<String>()
        for w in WorldCatalog.worlds { covered.formUnion(WorldCatalog.topicIds(for: w.id, in: store)) }
        XCTAssertEqual(covered.count, store.topics.count)
        XCTAssertEqual(WorldCatalog.worlds.count, 5)
        XCTAssertEqual(WorldCatalog.worlds.filter(\.isPlayable).count, 1)
    }
}
