import Foundation

/// A deterministic puzzle generator bound to one taxonomy topic.
/// Generators never touch the network or an LLM: validation is pure Swift.
public protocol PuzzleGenerator: Sendable {
    /// The topic `id` this generator serves.
    var topicId: String { get }
    var type: PuzzleType { get }
    /// Which `evidence` index each playable variant maps onto.
    var mastery: MasteryCriteria { get }

    /// Generate the `sequence`-th puzzle at `difficulty` (1...5).
    /// Deterministic for a given seed — same inputs, same puzzle.
    func makePuzzle(sequence: Int, difficulty: Int, store: TaxonomyStore) -> PuzzleInstance

    /// Evaluate an answer. Pure function of the puzzle — no randomness.
    func validate(_ puzzle: PuzzleInstance, answer: Answer) -> Verdict

    /// Diagnose a wrong answer into a misconception + research match.
    func diagnose(_ puzzle: PuzzleInstance, answer: Answer, store: TaxonomyStore) -> MisconceptionDiagnosis?
}

/// How topic `evidence` statements map onto puzzle assessment.
public struct MasteryCriteria: Codable, Sendable {
    /// evidence[i] is demonstrated by solving this many puzzles tagged with
    /// `evidenceIndex == i`.
    public let creditsPerEvidence: Int
    /// Recent window for accuracy requirement.
    public let recentWindow: Int
    /// Required fraction correct within the recent window.
    public let minimumAccuracy: Double
    /// Minimum current difficulty at which evidence credit counts
    /// (evidence earned on trivial settings doesn't count for older kids).
    public let minimumDifficulty: Int
    /// Per evidence index: the bridge forms (or nil = not puzzle-assessable,
    /// shown in parent zone as "conversation" items instead).
    public let evidenceForms: [[BridgeForm]?]

    public init(creditsPerEvidence: Int = 2, recentWindow: Int = 6,
                minimumAccuracy: Double = 0.8, minimumDifficulty: Int = 1,
                evidenceForms: [[BridgeForm]?]) {
        self.creditsPerEvidence = creditsPerEvidence
        self.recentWindow = recentWindow
        self.minimumAccuracy = minimumAccuracy
        self.minimumDifficulty = minimumDifficulty
        self.evidenceForms = evidenceForms
    }

    public func assessableEvidenceIndex(forSequence sequence: Int) -> Int? {
        let indices = evidenceForms.enumerated().compactMap { $0.element == nil ? nil : $0.offset }
        guard !indices.isEmpty else { return nil }
        let index = ((sequence % indices.count) + indices.count) % indices.count
        return indices[index]
    }
}

/// Registry: taxonomy topic id → generator.
public final class GeneratorRegistry: Sendable {
    public let generators: [String: any PuzzleGenerator]

    public init(generators: [any PuzzleGenerator]) {
        self.generators = Dictionary(generators.map { ($0.topicId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public func generator(for topicId: String) -> (any PuzzleGenerator)? {
        generators[topicId]
    }

    public var playableTopicIds: [String] { Array(generators.keys) }

    /// The default WonderMath set: one bridge or pattern generator per
    /// curated topic in the slice.
    public static func makeDefault() -> GeneratorRegistry {
        GeneratorRegistry(generators: BridgeLibrary.all + PatternPathLibrary.all)
    }
}

/// Shared verdict for single-gap puzzles: compare the answer to the unique
/// solution computed deterministically from the config.
public enum PuzzleValidator {

    /// Validate an `equation` puzzle (1 or 2 gaps).
    public static func validate(equation eq: Equation, gapCount: Int, answer: Answer) -> Verdict {
        guard answer.values.count == gapCount else { return .incomplete }
        guard eq.check(answer.values) == true else { return .incorrect(nil) }
        return .correct
    }

    /// Validate a sequence puzzle.
    public static func validate(sequence p: SequencePuzzle, answer: Answer) -> Verdict {
        guard let v = answer.values.first, answer.values.count == 1 else { return .incomplete }
        // Derive expected term deterministically from neighbours + step.
        let before = p.gapIndex > 0 ? p.terms[p.gapIndex - 1] : nil
        let after = p.gapIndex < p.terms.count - 1 ? p.terms[p.gapIndex + 1] : nil
        let expected: Int?
        if let b = before { expected = b + p.step }
        else if let a = after { expected = a - p.step }
        else { expected = nil }
        guard let expected, v == expected else { return .incorrect(nil) }
        return .correct
    }

    /// Diagnose a single-gap wrong answer against the puzzle's precompiled
    /// misconception table (guaranteed unambiguous at generation time).
    public static func diagnosis(for puzzle: PuzzleInstance, answer: Answer,
                                 store: TaxonomyStore) -> MisconceptionDiagnosis? {
        guard let v = answer.values.first,
              let kind = puzzle.misconceptionAnswers[v] else { return nil }
        let record = store.research(for: puzzle.topicId)
        let pattern = ErrorPatternMatcher.match(kind, in: record)
        // A reteach target is only useful if it's bundled & playable.
        let reteach = pattern?.reteachPrerequisiteId.flatMap { store.topic($0) != nil ? $0 : nil }
        return MisconceptionDiagnosis(
            kind: kind,
            childMessage: LocalizedMessage(kind.feedbackKey),
            researchPattern: pattern,
            reteachTopicId: reteach)
    }
}

public extension MisconceptionKind {
    /// Child-facing feedback key for this misconception.
    var feedbackKey: L10n.Key {
        switch self {
        case .usedVisibleNumbers: return .feedbackUsedVisibleNumbers
        case .wroteTheWhole: return .feedbackWroteTheWhole
        case .runningTotal: return .feedbackRunningTotal
        case .wrongOperation: return .feedbackWrongOperation
        case .offByOne: return .feedbackOffByOne
        case .placeValueSlip: return .feedbackPlaceValueSlip
        case .wrongStep: return .feedbackWrongStep
        case .wrongDirection: return .feedbackWrongDirection
        }
    }
}
