import Foundation
import Combine
import WonderMathCore

@MainActor
final class PuzzleSession: ObservableObject {
    enum State {
        case solving
        case solved(RecordResult)
        case retry
    }

    @Published private(set) var puzzle: PuzzleInstance
    @Published private(set) var sequence: Int
    @Published private(set) var placedValues: [Int] = []
    @Published private(set) var hintLevel: HintLevel?
    @Published private(set) var feedback: LocalizedMessage?
    @Published private(set) var visibleHint: LocalizedMessage?
    @Published private(set) var state: State = .solving

    let topicId: String
    let difficulty: Int
    private let recordsPracticeTime: Bool
    private let appState: AppState
    private let progressService: ProgressService
    private var startedAt = Date()
    private var lastDiagnosis: MisconceptionDiagnosis?

    init(topicId: String, difficulty: Int, appState: AppState, progressService: ProgressService,
         recordsPracticeTime: Bool = true) {
        self.topicId = topicId
        self.difficulty = difficulty
        self.recordsPracticeTime = recordsPracticeTime
        self.appState = appState
        self.progressService = progressService
        guard let generator = appState.registry.generator(for: topicId) else {
            preconditionFailure("No generator for topic \(topicId)")
        }
        let initialSequence = progressService.progress(for: topicId)?.attempts ?? 0
        sequence = initialSequence
        puzzle = generator.makePuzzle(sequence: initialSequence, difficulty: difficulty, store: appState.store)
    }

    var choices: [Int] { puzzle.choices }
    var isSolved: Bool {
        if case .solved = state { return true }
        return false
    }
    var isRetry: Bool {
        if case .retry = state { return true }
        return false
    }
    var acceptsAnswers: Bool {
        if case .solving = state { return true }
        return false
    }
    var canSubmit: Bool {
        guard acceptsAnswers else { return false }
        let requiredCount: Int
        if case .equation(let equation) = puzzle.config {
            requiredCount = equation.gapCount
        } else {
            requiredCount = 1
        }
        return placedValues.count >= requiredCount
    }
    var result: RecordResult? {
        if case .solved(let value) = state { return value }
        return nil
    }
    var correctValueForUITesting: Int? {
        guard ProcessInfo.processInfo.arguments.contains("-UITestInMemory"),
              let generator = appState.registry.generator(for: topicId) else { return nil }
        return puzzle.choices.first {
            generator.validate(puzzle, answer: Answer([$0])) == .correct
        }
    }

    func place(_ value: Int) {
        guard case .solving = state else { return }
        let gapCount: Int
        if case .equation(let equation) = puzzle.config { gapCount = equation.gapCount }
        else { gapCount = 1 }
        if placedValues.count < gapCount { placedValues.append(value) }
        else { placedValues[placedValues.count - 1] = value }
    }

    func clearPlacement() {
        guard case .solving = state else { return }
        placedValues.removeAll()
    }

    func nextHint() -> Hint? {
        guard acceptsAnswers else { return nil }
        let levels = HintLevel.allCases
        let next = levels.first { level in
            guard let current = hintLevel else { return true }
            return level.rawValue > current.rawValue
        }
        guard let next else { return nil }
        hintLevel = next
        let hint = puzzle.hint(next)
        visibleHint = hint?.message
        return hint
    }

    func submit() {
        guard case .solving = state else { return }
        guard let generator = appState.registry.generator(for: topicId) else { return }
        let answer = Answer(placedValues)
        let verdict = generator.validate(puzzle, answer: answer)
        guard verdict != .incomplete else { return }

        if verdict == .correct {
            feedback = LocalizedMessage(.feedbackCorrect)
            let outcome = Outcome(correct: true, maxHintLevel: hintLevel, misconception: nil,
                                  evidenceIndex: puzzle.evidenceIndex, difficulty: puzzle.difficulty,
                                  latency: Date().timeIntervalSince(startedAt))
            let result = progressService.record(outcome: outcome, topicId: topicId,
                                                secondsSpent: recordsPracticeTime
                                                    ? Int(Date().timeIntervalSince(startedAt)) : 0)
            state = .solved(result)
        } else {
            lastDiagnosis = generator.diagnose(puzzle, answer: answer, store: appState.store)
            feedback = lastDiagnosis?.childMessage ?? LocalizedMessage(.feedbackGenericWrong)
            let misconception: MisconceptionKind?
            if case .incorrect(let kind) = verdict { misconception = kind }
            else { misconception = lastDiagnosis?.kind }
            let outcome = Outcome(correct: false, maxHintLevel: hintLevel,
                                  misconception: misconception, evidenceIndex: puzzle.evidenceIndex,
                                  difficulty: puzzle.difficulty,
                                  latency: Date().timeIntervalSince(startedAt))
            _ = progressService.record(outcome: outcome, topicId: topicId,
                                       secondsSpent: recordsPracticeTime
                                           ? Int(Date().timeIntervalSince(startedAt)) : 0)
            state = .retry
        }
    }

    func continueAfterRetry() {
        guard case .retry = state else { return }
        placedValues.removeAll()
        feedback = nil
        startedAt = Date()
        state = .solving
    }

    func nextPuzzle() {
        guard case .solved = state,
              let generator = appState.registry.generator(for: topicId) else { return }
        sequence = progressService.progress(for: topicId)?.attempts ?? (sequence + 1)
        puzzle = generator.makePuzzle(sequence: sequence, difficulty: difficulty, store: appState.store)
        startedAt = Date()
        placedValues.removeAll()
        hintLevel = nil
        visibleHint = nil
        feedback = nil
        lastDiagnosis = nil
        state = .solving
    }
}
