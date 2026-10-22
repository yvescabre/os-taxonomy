import XCTest
@testable import WonderMathCore

/// The core guarantee: every generated puzzle is solvable and unambiguous.
final class BridgeGeneratorTests: XCTestCase {

    var store: TaxonomyStore!

    override func setUpWithError() throws { store = try TestSupport.loadStore() }

    func testEveryProfileGeneratesSolvableUnambiguousPuzzles() throws {
        for generator in BridgeLibrary.all {
            for difficulty in 1...5 {
                for seq in 0..<12 {
                    let p = generator.makePuzzle(sequence: seq, difficulty: difficulty, store: store)
                    guard case .equation(let eq) = p.config else { return XCTFail("bad config") }
                    // Exactly one solution across the candidate window.
                    let solutions = eq.equation.candidateWindow().filter { eq.equation.check([$0]) == true }
                    XCTAssertEqual(solutions.count, 1, "ambiguous puzzle \(p.id): \(solutions)")
                    let answer = try XCTUnwrap(solutions.first)
                    // The solution is offered among the choices.
                    XCTAssertTrue(p.choices.contains(answer), "answer \(answer) not in \(p.choices)")
                    XCTAssertEqual(Set(p.choices).count, p.choices.count, "duplicate choices")
                    XCTAssertTrue(p.choices.allSatisfy { $0 >= 0 })
                    // No distractor also solves the equation.
                    for c in p.choices where c != answer {
                        XCTAssertNotEqual(eq.equation.check([c]), true, "distractor \(c) also solves \(p.id)")
                    }
                    // Validation accepts the answer and rejects distractors.
                    XCTAssertEqual(generator.validate(p, answer: Answer([answer])), .correct)
                    // Misconception answers never include the answer and are unique.
                    XCTAssertNil(p.misconceptionAnswers[answer])
                    // Three hint levels + explanation always present.
                    XCTAssertEqual(p.hints.count, 3)
                    XCTAssertFalse(p.explanation.isEmpty)
                    XCTAssertNotNil(p.whyInfo)
                }
            }
        }
    }

    func testDeterminism() throws {
        let gen = BridgeLibrary.all[0]
        let a = gen.makePuzzle(sequence: 4, difficulty: 3, store: store)
        let b = gen.makePuzzle(sequence: 4, difficulty: 3, store: store)
        XCTAssertEqual(a.choices, b.choices)
        XCTAssertEqual(a.config, b.config)
    }

    func testWrongAnswersDiagnoseMisconceptions() throws {
        var diagnosed = 0
        for generator in BridgeLibrary.all {
            for difficulty in [1, 3] {
                let p = generator.makePuzzle(sequence: 0, difficulty: difficulty, store: store)
                for (wrong, kind) in p.misconceptionAnswers {
                    guard case .incorrect(let found) = generator.validate(p, answer: Answer([wrong])) else {
                        return XCTFail("distractor \(wrong) judged wrong kind in \(p.id)")
                    }
                    XCTAssertEqual(found, kind)
                    let diag = generator.diagnose(p, answer: Answer([wrong]), store: store)
                    XCTAssertEqual(diag?.kind, kind)
                    diagnosed += 1
                }
            }
        }
        XCTAssertGreaterThan(diagnosed, 100, "expected many diagnosable distractors")
    }

    func testIncompleteAnswers() throws {
        let gen = BridgeLibrary.all[0]
        let p = gen.makePuzzle(sequence: 0, difficulty: 1, store: store)
        XCTAssertEqual(gen.validate(p, answer: Answer([])), .incomplete)
    }

    func testResearchLinkedFeedbackForKnownMisconception() throws {
        // mt_3JgrHY221M's research has an "adds the two visible numbers"
        // errorPattern; a matching distractor should link it.
        let gen = BridgeLibrary.all.first { $0.topicId == "mt_3JgrHY221M" }!
        var matched = false
        for seq in 0..<30 {
            let p = gen.makePuzzle(sequence: seq, difficulty: 2, store: store)
            for (wrong, _) in p.misconceptionAnswers {
                if let d = gen.diagnose(p, answer: Answer([wrong]), store: store),
                   d.researchPattern != nil { matched = true }
            }
        }
        XCTAssertTrue(matched, "no distractor matched research errorPatterns")
    }
}

final class PatternPathGeneratorTests: XCTestCase {

    var store: TaxonomyStore!

    override func setUpWithError() throws { store = try TestSupport.loadStore() }

    func testSequencesAreSolvableAndUnambiguous() throws {
        for generator in PatternPathLibrary.all {
            for difficulty in 1...5 {
                for seq in 0..<10 {
                    let p = generator.makePuzzle(sequence: seq, difficulty: difficulty, store: store)
                    guard case .sequence(let s) = p.config else { return XCTFail("bad config") }
                    // Reconstruct: the gap must equal neighbour + step.
                    let before = s.terms[s.gapIndex - 1]!
                    let answer = before + s.step
                    XCTAssertTrue(p.choices.contains(answer))
                    XCTAssertEqual(generator.validate(p, answer: Answer([answer])), .correct)
                    for c in p.choices where c != answer {
                        XCTAssertNotEqual(generator.validate(p, answer: Answer([c])), .correct)
                    }
                    // Sequence terms are a real constant-step progression;
                    // shown terms adjacent in index differ by exactly `step`.
                    for i in 0..<(s.terms.count - 1) {
                        guard let a = s.terms[i], let b = s.terms[i + 1] else { continue }
                        XCTAssertEqual(b - a, s.step)
                    }
                }
            }
        }
    }
}
