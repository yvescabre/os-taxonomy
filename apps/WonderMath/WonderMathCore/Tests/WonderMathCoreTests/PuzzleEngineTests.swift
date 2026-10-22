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

    func testEveryHintIsTrueOfTheAnswer() throws {
        var coveredPairs = Set<String>()
        var nudgeFailures: [String] = []
        var clueFailures: [String] = []
        var walkthroughFailures: [String] = []

        for generator in BridgeLibrary.all {
            for difficulty in 1...5 {
                for seq in 0..<24 {
                    let puzzle = generator.makePuzzle(sequence: seq, difficulty: difficulty, store: store)
                    guard case .equation(let equationPuzzle) = puzzle.config else {
                        return XCTFail("bad config for \(puzzle.id)")
                    }
                    let equation = equationPuzzle.equation
                    let form = equationPuzzle.form
                    let answer = try XCTUnwrap(equation.solve(), "no answer for \(puzzle.id)")
                    coveredPairs.insert("\(form.rawValue).\(operation(for: form, equation: equation).rawValue)")

                    let nudge = try XCTUnwrap(puzzle.hints.first { $0.level == .nudge }).message
                    let clue = try XCTUnwrap(puzzle.hints.first { $0.level == .clue }).message
                    let walkthrough = puzzle.explanation.first { $0.message.key == .stepInverseFormat }?.message
                    let label = "\(puzzle.id) [\(form.rawValue), \(operation(for: form, equation: equation).rawValue)]"
                    if !nudgeIsTrue(nudge, form: form, equation: equation, answer: answer) {
                        nudgeFailures.append(label)
                    }
                    if !clueIsTrue(clue, equation: equation, answer: answer) {
                        clueFailures.append(label)
                    }
                    if !(walkthrough.map { inverseArithmeticIsTrue($0, answer: answer) } ?? false) {
                        walkthroughFailures.append(label)
                    }
                }
            }
        }

        XCTAssertTrue(coveredPairs.contains("secondOperandUnknown.divide"),
                      "sweep did not cover secondOperandUnknown ÷")
        XCTAssertTrue(coveredPairs.contains("firstOperandUnknown.divide"),
                      "sweep did not cover firstOperandUnknown ÷")
        let failedPuzzles = Set(nudgeFailures + clueFailures + walkthroughFailures)
        XCTAssertTrue(nudgeFailures.isEmpty,
                      "\(nudgeFailures.count) nudge failures: \(nudgeFailures.prefix(8))")
        XCTAssertTrue(clueFailures.isEmpty,
                      "\(clueFailures.count) clue failures: \(clueFailures.prefix(8))")
        XCTAssertTrue(walkthroughFailures.isEmpty,
                      "\(walkthroughFailures.count) walkthrough failures: \(walkthroughFailures.prefix(8))")
        XCTAssertTrue(failedPuzzles.isEmpty,
                      "\(failedPuzzles.count) puzzles had at least one incorrect hint")
    }

    func testSecondOperandUnknownDivisionNudgeNamesDividendAndQuotient() throws {
        for generator in BridgeLibrary.all {
            for difficulty in 1...5 {
                for seq in 0..<64 {
                    let puzzle = generator.makePuzzle(sequence: seq, difficulty: difficulty, store: store)
                    guard case .equation(let equationPuzzle) = puzzle.config,
                          equationPuzzle.form == .secondOperandUnknown,
                          equationPuzzle.equation.left.operation == .divide else { continue }

                    let equation = equationPuzzle.equation
                    let answer = try XCTUnwrap(equation.solve())
                    let dividend = try XCTUnwrap(equation.left.lhs.knownValue)
                    let quotient = try XCTUnwrap(equation.right.evaluate())
                    let nudge = try XCTUnwrap(puzzle.hints.first { $0.level == .nudge }).message
                    XCTAssertEqual(nudge.key, .nudgeDividedByWhich)
                    XCTAssertEqual(nudge.args, [.number(dividend), .number(quotient)])
                    XCTAssertEqual(dividend / answer, quotient)
                    return
                }
            }
        }
        XCTFail("sweep did not produce a secondOperandUnknown division puzzle")
    }

    private func operation(for form: BridgeForm, equation: Equation) -> WonderMathCore.Operation {
        switch form {
        case .answerLeft, .balance: return equation.right.operation
        default: return equation.left.operation
        }
    }

    private func numberArguments(_ message: LocalizedMessage) -> [Int]? {
        var values: [Int] = []
        for argument in message.args {
            guard case .number(let value) = argument else { return nil }
            values.append(value)
        }
        return values
    }

    private func inverseArithmeticIsTrue(_ message: LocalizedMessage, answer: Int) -> Bool {
        guard message.args.count == 4,
              case .number(let lhs) = message.args[0],
              case .symbol(let symbol) = message.args[1],
              case .number(let rhs) = message.args[2],
              case .number(let shownAnswer) = message.args[3],
              let operation = WonderMathCore.Operation.allCases.first(where: { $0.symbol == symbol }) else { return false }
        return operation.apply(lhs, rhs) == shownAnswer && shownAnswer == answer
    }

    private func nudgeIsTrue(_ message: LocalizedMessage, form: BridgeForm,
                             equation: Equation, answer: Int) -> Bool {
        switch form {
        case .resultUnknown:
            return message.key.rawValue == "nudgeMissingNumber" && message.args.isEmpty
        case .balance:
            return message.key.rawValue == "nudgeBalance" && message.args.isEmpty
        case .commutativeSwap:
            return message.key.rawValue == "nudgeCommutative" && message.args.isEmpty
        case .firstOperandUnknown, .secondOperandUnknown, .answerLeft:
            let unknownSide = form == .answerLeft ? equation.right : equation.left
            let resultSide = form == .answerLeft ? equation.left : equation.right
            guard let result = resultSide.evaluate() else { return false }
            if unknownSide.lhs.isUnknown, let known = unknownSide.rhs.knownValue {
                switch unknownSide.operation {
                case .add, .subtract:
                    return message.key.rawValue == "nudgeMissingNumber" && message.args.isEmpty
                case .multiply:
                    guard message.key.rawValue == "nudgeMissingNumberTimes",
                          let args = numberArguments(message), args.count == 2 else { return false }
                    return args == [known, result] && answer * known == result
                case .divide:
                    guard message.key == .nudgeMissingNumberDividedBy,
                          let args = numberArguments(message), args.count == 2 else { return false }
                    return args == [known, result] && known != 0
                        && answer % known == 0 && answer / known == result
                }
            }
            if unknownSide.rhs.isUnknown, let known = unknownSide.lhs.knownValue {
                switch unknownSide.operation {
                case .add, .subtract:
                    return message.key.rawValue == "nudgeMissingNumber" && message.args.isEmpty
                case .multiply:
                    guard message.key.rawValue == "nudgeMissingNumberTimes",
                          let args = numberArguments(message), args.count == 2 else { return false }
                    return args == [known, result] && answer * known == result
                case .divide:
                    guard message.key == .nudgeDividedByWhich,
                          let args = numberArguments(message), args.count == 2 else { return false }
                    return args == [known, result] && answer != 0
                        && known % answer == 0 && known / answer == result
                }
            }
            return false
        }
    }

    private func clueIsTrue(_ message: LocalizedMessage, equation: Equation, answer: Int) -> Bool {
        guard let args = numberArguments(message) else { return false }
        switch message.key.rawValue {
        case "clueInverseAddSub":
            return args.count == 2 && args[0] - args[1] == answer
        case "clueInverseSubAsAdd":
            return args.count == 2 && args[0] + args[1] == answer
        case "clueInverseMultDiv":
            return args.count == 2 && args[1] != 0
                && args[0] % args[1] == 0 && args[0] / args[1] == answer
        case "clueInverseDivAsMult":
            return args.count == 2 && args[0] * args[1] == answer
        case "clueBalance":
            let knownSide = equation.left.unknownCount == 0 ? equation.left : equation.right
            return args.count == 1 && knownSide.evaluate() == args[0]
        case "clueCommutative":
            return args.isEmpty
        default:
            return false
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
