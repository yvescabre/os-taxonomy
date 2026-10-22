import Foundation

/// "Stepping stones": a constant-step number sequence with one missing stone.
/// The gap is solvable by construction: every sequence is generated from a
/// start value and a step, so the missing term is unique.
public struct PatternPathGenerator: PuzzleGenerator {
    public let topicId: String
    public let type: PuzzleType = .patternPath
    public let profile: PatternPathProfile
    public var mastery: MasteryCriteria { profile.mastery }

    public init(profile: PatternPathProfile) {
        self.topicId = profile.topicId
        self.profile = profile
    }

    public func makePuzzle(sequence s: Int, difficulty: Int, store: TaxonomyStore) -> PuzzleInstance {
        let d = min(max(difficulty, 1), 5)
        var rng = SeededRandom(seed: SeededRandom.seed(["pattern", topicId, d, s]))
        let step = rng.element(of: profile.steps(at: d)) * (profile.allowBackward && rng.probability(0.4) ? -1 : 1)
        let length = profile.length(at: d)
        let start = rng.int(in: profile.startRange(at: d))
        var terms = (0..<length).map { start + $0 * step }
        // Keep all terms non-negative for the slice's age range.
        if terms.contains(where: { $0 < 0 }) { terms = terms.map { $0 - terms.min()! } }
        let gapIndex = rng.int(in: 1...(length - 2)) // never an endpoint
        let answer = terms[gapIndex]
        var displayTerms: [Int?] = terms
        displayTerms[gapIndex] = nil

        let config = SequencePuzzle(terms: displayTerms, gapIndex: gapIndex, step: step)
        let misconceptionAnswers = diagnoseableAnswers(terms: terms, gap: gapIndex, step: step, answer: answer)
        let choices = buildChoices(answer: answer, misconceptionAnswers: misconceptionAnswers,
                                   difficulty: d, rng: &rng)
        let puzzle = PuzzleInstance(
            id: "pattern-\(topicId)-d\(d)-\(s)",
            type: type, topicId: topicId,
            evidenceIndex: profile.mastery.assessableEvidenceIndex(forSequence: s),
            difficulty: d, config: .sequence(config), choices: choices,
            interaction: .tapToPlace,
            hints: [
                Hint(level: .nudge, message: LocalizedMessage(.nudgeSequence)),
                Hint(level: .clue, message: LocalizedMessage(.clueSequence)),
                Hint(level: .walkthrough, message: LocalizedMessage(.stepSequenceFormat,
                    [.number(abs(step)), .number(answer)])),
            ],
            explanation: [
                ExplanationStep(LocalizedMessage(.stepSequenceFormat, [.number(abs(step)), .number(answer)])),
                ExplanationStep(LocalizedMessage(.stepCheckFormat, [.number(answer)])),
            ],
            whyInfo: WhyInfo(
                bigIdea: LocalizedMessage(.ideaSequence),
                wonder: store.research(for: topicId)?.learn?.summary,
                tryIt: store.research(for: topicId)?.learn?.activities.first?.learnerActions.first,
                researchMissing: store.research(for: topicId) == nil),
            misconceptionAnswers: misconceptionAnswers)
        return puzzle
    }

    public func validate(_ puzzle: PuzzleInstance, answer: Answer) -> Verdict {
        guard case .sequence(let p) = puzzle.config else { return .incorrect(nil) }
        let verdict = PuzzleValidator.validate(sequence: p, answer: answer)
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

    private func diagnoseableAnswers(terms: [Int], gap: Int, step: Int,
                                     answer: Int) -> [Int: MisconceptionKind] {
        var table: [Int: MisconceptionKind] = [:]
        func offer(_ kind: MisconceptionKind, _ value: Int?) {
            guard let v = value, v != answer, v >= 0, table[v] == nil else { return }
            table[v] = kind
        }
        let before = gap > 0 ? terms[gap - 1] : nil
        let after = gap < terms.count - 1 ? terms[gap + 1] : nil
        offer(.offByOne, before)            // repeat the previous stone
        offer(.offByOne, after)             // skip ahead
        offer(.wrongStep, before.map { $0 + step * 2 })   // double hop
        offer(.wrongDirection, before.map { $0 - step })  // hop backwards
        offer(.wrongStep, (before ?? 0) + (step > 0 ? 1 : -1)) // count by ones
        return table
    }

    private func buildChoices(answer: Int, misconceptionAnswers: [Int: MisconceptionKind],
                              difficulty d: Int, rng: inout SeededRandom) -> [Int] {
        let count = d <= 2 ? 3 : 4
        var set = Set([answer])
        var ordered = [answer]
        for v in misconceptionAnswers.keys.sorted() where set.count < count {
            set.insert(v); ordered.append(v)
        }
        var i = 1
        while set.count < count && i < 50 {
            for delta in [i, -i] where set.count < count {
                let v = answer + delta
                if v >= 0, !set.contains(v) { set.insert(v); ordered.append(v) }
            }
            i += 1
        }
        return rng.shuffled(ordered)
    }
}

public struct PatternPathProfile: Sendable {
    public typealias IntRange = ClosedRange<Int>

    public let topicId: String
    /// Allowed step sizes per difficulty (index 0..4).
    public let stepSets: [[Int]]
    /// Allowed sequence starts per difficulty.
    public let startRanges: [IntRange]
    /// Sequence lengths per difficulty.
    public let lengths: [Int]
    /// Whether backward (descending) sequences are allowed.
    public let allowBackward: Bool
    public let mastery: MasteryCriteria

    public init(topicId: String, stepSets: [[Int]], startRanges: [IntRange],
                lengths: [Int] = [4, 4, 5, 5, 6], allowBackward: Bool,
                mastery: MasteryCriteria) {
        self.topicId = topicId
        self.stepSets = stepSets
        self.startRanges = startRanges
        self.lengths = lengths
        self.allowBackward = allowBackward
        self.mastery = mastery
    }

    public func steps(at d: Int) -> [Int] { stepSets[min(max(d - 1, 0), stepSets.count - 1)] }
    public func startRange(at d: Int) -> ClosedRange<Int> { startRanges[min(max(d - 1, 0), startRanges.count - 1)] }
    public func length(at d: Int) -> Int { lengths[min(max(d - 1, 0), lengths.count - 1)] }
}

/// Curated pattern-path topics (logic/visual daily stage + world path).
/// All ids verified against the bundled subset.
public enum PatternPathLibrary {

    private static func criteria(_ forms: [[BridgeForm]?]) -> MasteryCriteria {
        // Pattern path doesn't use BridgeForm; reuse the criteria type with
        // empty forms arrays just to mark which evidence indices are playable.
        MasteryCriteria(evidenceForms: forms)
    }

    /// Counting in 2s (mt_nvdpxAJTBG).
    private static let count2 = PatternPathProfile(
        topicId: "mt_nvdpxAJTBG",
        stepSets: [[2], [2], [2], [2], [2]],
        startRanges: [0...6, 0...10, 0...20, 0...40, 0...80],
        allowBackward: true,
        mastery: criteria([[.resultUnknown], [.resultUnknown], [.resultUnknown]]))

    /// Skip counting 4s/8s/50s/100s (mt_IzQvs7k_sE).
    private static let skipCount = PatternPathProfile(
        topicId: "mt_IzQvs7k_sE",
        stepSets: [[4], [4, 8], [4, 8, 50], [4, 8, 50, 100], [8, 50, 100]],
        startRanges: [0...8, 0...16, 0...50, 0...100, 0...200],
        allowBackward: true,
        mastery: criteria([[.resultUnknown], [.resultUnknown], [.resultUnknown]]))

    /// Counting forwards and backwards age 9+ (mt_tAtMET4EIU).
    private static let countBack9 = PatternPathProfile(
        topicId: "mt_tAtMET4EIU",
        stepSets: [[10, 25], [10, 25, 50], [10, 25, 50, 100], [25, 50, 100, 250], [50, 100, 250, 1000]],
        startRanges: [0...50, 0...100, 0...500, 0...1000, 0...5000],
        allowBackward: true,
        mastery: criteria([[.resultUnknown], [.resultUnknown], [.resultUnknown]]))

    /// Describing growing number patterns (mt_W3VOAuFwVw).
    private static let growing = PatternPathProfile(
        topicId: "mt_W3VOAuFwVw",
        stepSets: [[1, 2, 3], [2, 3, 5], [2, 4, 5, 10], [3, 4, 6, 10], [5, 6, 7, 9, 11]],
        startRanges: [0...10, 0...20, 0...30, 0...50, 0...60],
        allowBackward: false,
        mastery: criteria([[.resultUnknown], nil, [.resultUnknown]]))

    /// Linear number sequences (mt_hBZwbst0ow).
    private static let linear = PatternPathProfile(
        topicId: "mt_hBZwbst0ow",
        stepSets: [[2, 3, 4, 5], [3, 4, 6, 7], [4, 6, 8, 9], [6, 7, 8, 11], [9, 11, 12, 13]],
        startRanges: [0...30, 0...60, 0...100, -20...100, -50...100],
        allowBackward: true,
        mastery: criteria([[.resultUnknown], [.resultUnknown], nil]))

    public static let profiles: [PatternPathProfile] = [count2, skipCount, countBack9, growing, linear]
    public static let all: [PatternPathGenerator] = profiles.map(PatternPathGenerator.init(profile:))
}
