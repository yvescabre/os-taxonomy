import Foundation

/// "Repair the bridge": the vertical-slice mechanic. An equation is rendered
/// as planks on a bridge; one (or two, for build-your-own) planks are missing
/// and the child drags the right number into the gap.
///
/// Generation is deterministic and every emitted puzzle is verified to have
/// exactly one solution before it leaves the generator (uniqueAnswer
/// completion). Distractors are compiled into `misconceptionAnswers`.
public struct BridgeGenerator: PuzzleGenerator {
    public let topicId: String
    public let type: PuzzleType = .bridgeEquation
    public let profile: BridgeProfile
    public var mastery: MasteryCriteria { profile.mastery }

    public init(profile: BridgeProfile) {
        self.topicId = profile.topicId
        self.profile = profile
    }

    public func makePuzzle(sequence: Int, difficulty: Int, store: TaxonomyStore) -> PuzzleInstance {
        let d = min(max(difficulty, 1), 5)
        var rng = SeededRandom(seed: SeededRandom.seed(["bridge", topicId, d, sequence]))
        let evidenceIndex = pickEvidenceIndex(sequence: sequence, rng: &rng)
        let form = pickForm(for: evidenceIndex, rng: &rng)
        let equation = buildEquation(form: form, difficulty: d, rng: &rng)
        let answer = equation.solve()! // guaranteed by construction

        // Deterministic unambiguity proof: the solver must find exactly this
        // answer across the candidate window. If construction ever broke, we'd
        // rather crash loudly in tests than ship an ambiguous puzzle.
        precondition(equation.solve() == answer && equation.check([answer]) == true,
                     "bridge puzzle is not uniquely solvable")

        let misconceptionAnswers = diagnoseableAnswers(equation: equation, answer: answer, form: form)
        let choices = buildChoices(answer: answer, misconceptionAnswers: misconceptionAnswers,
                                   difficulty: d, rng: &rng)
        let nudge = nudge(for: form, equation: equation)
        let clue = clue(for: form, equation: equation)
        let walkthrough = walkthroughSteps(equation: equation, form: form, answer: answer)
        let why = whyInfo(for: form, store: store)
        let interaction: InteractionModel = rng.probability(0.5) ? .dragPlanks : .tapToPlace

        return PuzzleInstance(
            id: "bridge-\(topicId)-d\(d)-\(sequence)",
            type: type, topicId: topicId, evidenceIndex: evidenceIndex,
            difficulty: d,
            config: .equation(EquationPuzzle(equation: equation, gapCount: 1, form: form)),
            choices: choices, interaction: interaction,
            hints: [
                Hint(level: .nudge, message: nudge),
                Hint(level: .clue, message: clue),
                Hint(level: .walkthrough, message: LocalizedMessage(.stepWeKnowFormat,
                    [walkthrough[0].message.args[0]])),
            ],
            explanation: walkthrough,
            whyInfo: why,
            misconceptionAnswers: misconceptionAnswers)
    }

    public func validate(_ puzzle: PuzzleInstance, answer: Answer) -> Verdict {
        guard case .equation(let p) = puzzle.config else { return .incorrect(nil) }
        let verdict = PuzzleValidator.validate(equation: p.equation, gapCount: p.gapCount, answer: answer)
        if case .incorrect = verdict, let v = answer.values.first,
           let kind = puzzle.misconceptionAnswers[v] {
            return .incorrect(kind)
        }
        return verdict
    }

    public func diagnose(_ puzzle: PuzzleInstance, answer: Answer,
                         store: TaxonomyStore) -> MisconceptionDiagnosis? {
        PuzzleValidator.diagnosis(for: puzzle, answer: answer, store: store)
    }

    // MARK: - Evidence → form selection

    private func pickEvidenceIndex(sequence: Int, rng: inout SeededRandom) -> Int? {
        let playable = profile.mastery.evidenceForms.enumerated().compactMap { $0.element == nil ? nil : $0.offset }
        guard !playable.isEmpty else { return nil }
        // Cycle so every assessable evidence item gets equal coverage.
        return playable[sequence % playable.count]
    }

    private func pickForm(for evidenceIndex: Int?, rng: inout SeededRandom) -> BridgeForm {
        if let i = evidenceIndex, i < profile.mastery.evidenceForms.count,
           let forms = profile.mastery.evidenceForms[i], !forms.isEmpty {
            return rng.element(of: forms)
        }
        return rng.element(of: profile.defaultForms)
    }

    // MARK: - Equation construction (uniquely solvable by construction)

    private func buildEquation(form: BridgeForm, difficulty d: Int, rng: inout SeededRandom) -> Equation {
        switch form {
        case .resultUnknown:
            let (a, b, op) = pickTriple(difficulty: d, rng: &rng)
            _ = op.apply(a, b)!
            // `a op b = ?` — the gap is the whole right side.
            return Equation(left: Expr(lhs: .known(a), op: op, rhs: .known(b)),
                            right: Expr(lhs: .unknown, op: .add, rhs: .known(0)))

        case .firstOperandUnknown:
            let (a, b, op) = pickTriple(difficulty: d, rng: &rng)
            let result = op.apply(a, b)!
            // ? op b = result  →  answer = a
            return Equation(left: Expr(lhs: .unknown, op: op, rhs: .known(b)),
                            right: Expr(lhs: .known(result), op: .add, rhs: .known(0)))

        case .secondOperandUnknown:
            let (a, b, op) = pickTriple(difficulty: d, rng: &rng)
            let result = op.apply(a, b)!
            // a op ? = result  →  answer = b
            return Equation(left: Expr(lhs: .known(a), op: op, rhs: .unknown),
                            right: Expr(lhs: .known(result), op: .add, rhs: .known(0)))

        case .answerLeft:
            // c = ? op b  — answer in the left operand of the right side
            let (a, b, op) = pickTriple(difficulty: d, rng: &rng)
            let result = op.apply(a, b)!
            return Equation(left: Expr(lhs: .known(result), op: .add, rhs: .known(0)),
                            right: Expr(lhs: .unknown, op: op, rhs: .known(b)))

        case .balance:
            // a op b = ? op2 c
            let (a, b, op) = pickTriple(difficulty: d, rng: &rng)
            let total = op.apply(a, b)!
            let op2 = rng.element(of: profile.operations)
            // Need c s.t. total = ? op2 c with a unique, non-degenerate answer.
            let c = pickSecondOperand(total: total, op: op2, rng: &rng)
            return Equation(left: Expr(lhs: .known(a), op: op, rhs: .known(b)),
                            right: Expr(lhs: .unknown, op: op2, rhs: .known(c)))

        case .commutativeSwap:
            // a × b = b × ?
            let (a, b, _) = pickTriple(difficulty: d, rng: &rng, force: .multiply)
            return Equation(left: Expr(lhs: .known(a), op: .multiply, rhs: .known(b)),
                            right: Expr(lhs: .known(b), op: .multiply, rhs: .unknown))
        }
    }

    /// Pick operand pair + operation appropriate to the profile's family.
    /// Returns (a, b, op) where `op.apply(a,b)` is guaranteed non-nil.
    private func pickTriple(difficulty d: Int, rng: inout SeededRandom,
                            force: Operation? = nil) -> (Int, Int, Operation) {
        for _ in 0..<200 {
            let op = force ?? rng.element(of: profile.operations)
            switch op {
            case .add:
                let total = rng.int(in: profile.additiveTotalRange(at: d))
                let a = rng.int(in: 1...(total - 1))
                return (a, total - a, .add)
            case .subtract:
                let total = rng.int(in: profile.additiveTotalRange(at: d))
                let b = rng.int(in: 1...(total - 1))
                return (total, b, .subtract)
            case .multiply:
                let a = rng.element(of: profile.factorSet(at: d))
                let b = rng.int(in: 2...profile.maxFactor(at: d))
                return (a, b, .multiply)
            case .divide:
                // Emit `product ÷ a = b` from a multiplication fact — always exact.
                let a = rng.element(of: profile.factorSet(at: d))
                let b = rng.int(in: 2...profile.maxFactor(at: d))
                return (a * b, a, .divide)
            }
        }
        fatalError("unreachable")
    }

    /// For `balance`, choose the right-side operand `c` so `? op c = total`
    /// is uniquely solvable and non-trivial.
    private func pickSecondOperand(total: Int, op: Operation, rng: inout SeededRandom) -> Int {
        switch op {
        case .add: return rng.int(in: 1...(max(total, 2) - 1))
        case .subtract:
            // ? − c = total → c = answer − total; pick c small so answer stays sane.
            return rng.int(in: 1...max(2, total / 2))
        case .multiply:
            // ? × c = total → c must divide total evenly, >1 if possible.
            let divisors = (2...total).filter { total % $0 == 0 }
            return rng.element(of: divisors.isEmpty ? [1] : divisors)
        case .divide:
            // ? ÷ c = total → c must be ≥2 and answer = total × c ≤ cap.
            return rng.int(in: 2...max(2, 12))
        }
    }

    // MARK: - Misconception answer table

    /// Compute which *wrong* answer would signal which misconception. Every
    /// candidate is checked to be (a) wrong, (b) unique in the map.
    private func diagnoseableAnswers(equation: Equation, answer: Int,
                                     form: BridgeForm) -> [Int: MisconceptionKind] {
        var table: [Int: MisconceptionKind] = [:]
        func offer(_ kind: MisconceptionKind, _ value: Int?) {
            guard let v = value, v != answer, v >= 0, table[v] == nil else { return }
            table[v] = kind
        }
        let lhs = equation.left.lhs.knownValue
        let lrhs = equation.left.rhs.knownValue
        let rl = equation.right.lhs.knownValue
        let rr = equation.right.rhs.knownValue
        let result = rl ?? lhs ?? 0

        switch form {
        case .resultUnknown:
            offer(.wroteTheWhole, lhs)
            offer(.offByOne, answer + 1)
            offer(.offByOne, answer - 1)
            if lhs != nil { offer(.placeValueSlip, placeValueConfusion(a: lhs!, b: lrhs ?? 0, op: equation.left.operation)) }
        case .firstOperandUnknown:
            // ? op b = c. Used-visible: apply op to visible numbers (b and c).
            offer(.usedVisibleNumbers, equation.left.operation.apply(result, lrhs ?? 0))
            offer(.wroteTheWhole, result)
            offer(.wrongOperation, equation.left.operation.inverse.apply(lrhs ?? 0, result))
            offer(.offByOne, answer + 1)
            offer(.offByOne, answer - 1)
        case .secondOperandUnknown:
            // a op ? = c. Used-visible: a op c (e.g. 8+11 for 8+?=11).
            offer(.usedVisibleNumbers, lhs.flatMap { equation.left.operation.apply($0, result) })
            offer(.wroteTheWhole, result)
            offer(.offByOne, answer + 1)
            offer(.offByOne, answer - 1)
        case .answerLeft:
            // c = ? op b. Wrong-operation: compute c − b (as if result-after-=).
            offer(.wrongOperation, Operation.subtract.apply(result, rr ?? 0))
            offer(.usedVisibleNumbers, equation.right.operation.apply(rr ?? 0, result))
            offer(.offByOne, answer + 1)
            offer(.offByOne, answer - 1)
        case .balance:
            // a op b = ? op2 c. Running total: the left-side value itself.
            offer(.runningTotal, lhs.flatMap { equation.left.operation.apply($0, lrhs ?? 0) })
            offer(.usedVisibleNumbers, rr.flatMap { equation.right.operation.apply($0, lhs ?? 0) })
            offer(.offByOne, answer + 1)
            offer(.offByOne, answer - 1)
        case .commutativeSwap:
            // a × b = b × ?. Misreads: the product, or "same number again".
            offer(.wroteTheWhole, lhs.flatMap { equation.left.operation.apply($0, lrhs ?? 0) })
            offer(.offByOne, answer + 1)
            offer(.offByOne, answer - 1)
        }
        return table
    }

    /// `38 + 40` where 40 is misread as 4 → 42; only meaningful for add/sub.
    private func placeValueConfusion(a: Int, b: Int, op: Operation) -> Int? {
        guard op == .add || op == .subtract else { return nil }
        if b >= 10, b % 10 == 0 { return op.apply(a, b / 10) }
        if a >= 10, a % 10 == 0 { return op.apply(a / 10, b) }
        return nil
    }

    // MARK: - Choices (distractors)

    private func buildChoices(answer: Int, misconceptionAnswers: [Int: MisconceptionKind],
                              difficulty d: Int, rng: inout SeededRandom) -> [Int] {
        let count = d <= 2 ? 3 : d <= 4 ? 4 : 5
        var set = Set([answer])
        var ordered: [Int] = [answer]
        // Misconception-driven distractors first — wrong for a reason.
        for v in misconceptionAnswers.keys.sorted() where set.count < count {
            set.insert(v); ordered.append(v)
        }
        // Then near misses around the answer.
        var offsets = [1, -1, 2, -2, 10, -10, 5, -5, 3, -3]
        var oi = 0
        while set.count < count && oi < 100 {
            let v = answer + offsets[oi % offsets.count]
            if v >= 0, !set.contains(v) { set.insert(v); ordered.append(v) }
            oi += 1
            if oi % offsets.count == 0 { offsets = rng.shuffled(offsets) }
        }
        return rng.shuffled(ordered)
    }

    // MARK: - Hints, walkthrough, why

    private func nudge(for form: BridgeForm, equation: Equation) -> LocalizedMessage {
        switch form {
        case .resultUnknown: return LocalizedMessage(.nudgeMissingNumber)
        case .firstOperandUnknown, .secondOperandUnknown, .answerLeft:
            if equation.left.operation == .multiply || equation.left.operation == .divide
                || equation.right.operation == .multiply || equation.right.operation == .divide {
                return LocalizedMessage(.nudgeMissingNumberTimes,
                    [.number(equation.left.rhs.knownValue ?? equation.right.rhs.knownValue ?? 0),
                     .number(equation.left.lhs.knownValue ?? equation.right.lhs.knownValue ?? 0)])
            }
            return LocalizedMessage(.nudgeMissingNumber)
        case .balance: return LocalizedMessage(.nudgeBalance)
        case .commutativeSwap: return LocalizedMessage(.nudgeCommutative)
        }
    }

    /// Clue states the inverse computation explicitly: "turn it around: 11 − 8".
    private func clue(for form: BridgeForm, equation: Equation) -> LocalizedMessage {
        if form == .commutativeSwap { return LocalizedMessage(.clueCommutative) }
        if form == .balance, let a = equation.left.lhs.knownValue,
           let b = equation.left.rhs.knownValue,
           let total = equation.left.operation.apply(a, b) {
            return LocalizedMessage(.clueBalance, [.number(total)])
        }
        let inv = inverseComputation(equation: equation, form: form)
        guard let inv else { return LocalizedMessage(.clueBalance, [.number(0)]) }
        switch inv.op {
        case .subtract: return LocalizedMessage(.clueInverseAddSub, [.number(inv.a), .number(inv.b)])
        case .add: return LocalizedMessage(.clueInverseSubAsAdd, [.number(inv.a), .number(inv.b)])
        case .divide: return LocalizedMessage(.clueInverseMultDiv, [.number(inv.a), .number(inv.b)])
        case .multiply: return LocalizedMessage(.clueInverseDivAsMult, [.number(inv.a), .number(inv.b)])
        }
    }

    /// The computation that yields the answer: `a op b = answer`.
    private func inverseComputation(equation: Equation, form: BridgeForm) -> (a: Int, op: Operation, b: Int)? {
        switch form {
        case .resultUnknown:
            guard let a = equation.left.lhs.knownValue, let b = equation.left.rhs.knownValue else { return nil }
            return (a, equation.left.operation, b)
        case .firstOperandUnknown:
            // ? op b = c → a = c invOp b
            guard let b = equation.left.rhs.knownValue, let c = equation.right.lhs.knownValue else { return nil }
            return (c, equation.left.operation.inverse, b)
        case .secondOperandUnknown:
            // a op ? = c → b = c invOp a   (sub: a−? =c → ? = a − c)
            guard let a = equation.left.lhs.knownValue, let c = equation.right.lhs.knownValue else { return nil }
            switch equation.left.operation {
            case .subtract: return (a, .subtract, c)
            case .divide: return (a, .divide, c)
            default: return (c, equation.left.operation.inverse, a)
            }
        case .answerLeft:
            // c = ? op b → same as firstOperandUnknown
            guard let b = equation.right.rhs.knownValue, let c = equation.left.lhs.knownValue else { return nil }
            return (c, equation.right.operation.inverse, b)
        case .balance:
            // total = ? op2 c → ? = total invOp c
            guard let a = equation.left.lhs.knownValue, let b = equation.left.rhs.knownValue,
                  let c = equation.right.rhs.knownValue else { return nil }
            guard let total = equation.left.operation.apply(a, b) else { return nil }
            switch equation.right.operation {
            case .subtract: return (total, .add, c)       // ? − c = t → ? = t + c
            case .divide: return (total, .multiply, c)    // ? ÷ c = t → ? = t × c
            default: return (total, equation.right.operation.inverse, c)
            }
        case .commutativeSwap:
            guard let a = equation.left.lhs.knownValue else { return nil }
            return (a, .multiply, 1) // renders as "swap": handled by clueCommutative upstream
        }
    }

    private func walkthroughSteps(equation: Equation, form: BridgeForm,
                                  answer: Int) -> [ExplanationStep] {
        var steps: [ExplanationStep] = []
        let knowns = [equation.left.lhs.knownValue, equation.left.rhs.knownValue,
                      equation.right.lhs.knownValue, equation.right.rhs.knownValue].compactMap { $0 }
        steps.append(ExplanationStep(LocalizedMessage(.stepWeKnowFormat,
            [.number(knowns.first ?? 0)])))
        if let inv = inverseComputation(equation: equation, form: form) {
            steps.append(ExplanationStep(LocalizedMessage(.stepInverseFormat,
                [.number(inv.a), .symbol(inv.op.symbol), .number(inv.b), .number(answer)])))
        }
        let checkText = "\(answer)"
        steps.append(ExplanationStep(LocalizedMessage(.stepCheckFormat, [.number(Int(checkText) ?? answer)])))
        return steps
    }

    private func whyInfo(for form: BridgeForm, store: TaxonomyStore) -> WhyInfo {
        let record = store.research(for: topicId)
        let idea: LocalizedMessage
        switch form {
        case .resultUnknown: idea = LocalizedMessage(.ideaInverseCheck)
        case .firstOperandUnknown, .secondOperandUnknown, .answerLeft:
            idea = LocalizedMessage(equationOperationIsMultDiv() ? .ideaMissingFactor : .ideaMissingAddend)
        case .balance: idea = LocalizedMessage(.ideaEqualsBalance)
        case .commutativeSwap: idea = LocalizedMessage(.ideaCommutative)
        }
        // Pull child-facing nuggets from research when present.
        let wonder = record?.learn?.summary ?? record?.pedagogy?.summary
        let tryIt = record?.learn?.activities.first?.learnerActions.first
        return WhyInfo(bigIdea: idea, wonder: wonder, tryIt: tryIt,
                       researchMissing: record == nil)
    }

    private func equationOperationIsMultDiv() -> Bool {
        switch profile.family {
        case .additive: return false
        case .multiplicative, .mixed: return true
        }
    }
}
