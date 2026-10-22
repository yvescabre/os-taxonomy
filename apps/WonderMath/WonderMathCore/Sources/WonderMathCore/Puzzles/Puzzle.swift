import Foundation

/// Identifier-stable taxonomy of puzzle mechanics.
public enum PuzzleType: String, Codable, CaseIterable, Sendable {
    /// "Repair the bridge": an equation with missing plank(s).
    case bridgeEquation
    /// "Stepping stones": a sequence with a missing term (logic/visual).
    case patternPath
    /// "Your own bridge": open-ended fill-in where several answers may work
    /// (daily creative stage). All valid answers count as correct.
    case buildYourOwn
}

/// How the child enters answers. Kept data-side so alternative renderings
/// (SwiftUI vs SpriteKit) share one spec.
public enum InteractionModel: String, Codable, Sendable {
    /// Drag a numbered plank from a tray into the gap.
    case dragPlanks
    /// Tap planks to fill the gap(s) in order.
    case tapToPlace
}

public enum HintLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case nudge = 1
    case clue = 2
    case walkthrough = 3

    public static func < (l: HintLevel, r: HintLevel) -> Bool { l.rawValue < r.rawValue }
}

public struct Hint: Codable, Hashable, Sendable {
    public let level: HintLevel
    public let message: LocalizedMessage

    public init(level: HintLevel, message: LocalizedMessage) {
        self.level = level
        self.message = message
    }
}

public struct ExplanationStep: Codable, Hashable, Sendable {
    public let message: LocalizedMessage

    public init(_ message: LocalizedMessage) {
        self.message = message
    }
}

/// Ways to finish a puzzle.
public enum CompletionCriteria: Codable, Hashable, Sendable {
    /// Exactly one numeric value fills the gap (the slice's only completion
    /// mode — always validated to have exactly one solution).
    case uniqueAnswer
    /// Any answer satisfying the predicate is accepted (open-ended puzzles).
    case anyValid
}

/// A concrete, generated puzzle.
public struct PuzzleInstance: Codable, Sendable {
    public let id: String
    public let type: PuzzleType
    /// Taxonomy topic this puzzle assesses.
    public let topicId: String
    /// Which taxonomy `evidence` index (0-based) this puzzle assesses, if the
    /// generator mapped one.
    public let evidenceIndex: Int?
    public let difficulty: Int
    public let config: PuzzleConfig
    /// Draggable/tappable number choices (includes the answer + distractors).
    public let choices: [Int]
    public let interaction: InteractionModel
    /// Three levels, always present.
    public let hints: [Hint]
    /// Ordered explanation revealed after solving ("the bridge repair guide").
    public let explanation: [ExplanationStep]
    /// Research-derived "Why does this work?" content, nil for topics without
    /// research — the UI shows a generic explanation then.
    public let whyInfo: WhyInfo?
    /// Map from a wrong numeric answer to a diagnosed misconception. Compiled
    /// once at generation time so validation is O(1) and unambiguous.
    public let misconceptionAnswers: [Int: MisconceptionKind]

    public init(id: String, type: PuzzleType, topicId: String, evidenceIndex: Int?,
                difficulty: Int, config: PuzzleConfig, choices: [Int],
                interaction: InteractionModel, hints: [Hint],
                explanation: [ExplanationStep], whyInfo: WhyInfo?,
                misconceptionAnswers: [Int: MisconceptionKind]) {
        self.id = id
        self.type = type
        self.topicId = topicId
        self.evidenceIndex = evidenceIndex
        self.difficulty = difficulty
        self.config = config
        self.choices = choices
        self.interaction = interaction
        self.hints = hints
        self.explanation = explanation
        self.whyInfo = whyInfo
        self.misconceptionAnswers = misconceptionAnswers
    }

    public var completion: CompletionCriteria {
        switch type {
        case .buildYourOwn: return .anyValid
        case .bridgeEquation, .patternPath: return .uniqueAnswer
        }
    }

    public func hint(_ level: HintLevel) -> Hint? { hints.first { $0.level == level } }
}

/// Research-linked "Why does this work?" content.
public struct WhyInfo: Codable, Hashable, Sendable {
    /// Plain-language explanation authored in-app (always present).
    public let bigIdea: LocalizedMessage
    /// Curiosity line for the child, drawn from `learn.summary`/`intendedInsight`.
    public let wonder: String?
    /// Hands-on idea pulled from `learn.activities[].learnerActions`.
    public let tryIt: String?
    /// True when the topic has no teaching research — the UI can surface the
    /// "full teaching notes" availability note for parents.
    public let researchMissing: Bool

    public init(bigIdea: LocalizedMessage, wonder: String?, tryIt: String?, researchMissing: Bool) {
        self.bigIdea = bigIdea
        self.wonder = wonder
        self.tryIt = tryIt
        self.researchMissing = researchMissing
    }
}

/// What a puzzle looks like, in render-agnostic terms.
public enum PuzzleConfig: Codable, Hashable, Sendable {
    /// An equation with one gap (or two for `buildYourOwn`).
    case equation(EquationPuzzle)
    /// A number sequence with one gap.
    case sequence(SequencePuzzle)
}

public struct EquationPuzzle: Codable, Hashable, Sendable {
    public let equation: Equation
    /// Number of gaps (1 for bridgeEquation, 2 for buildYourOwn).
    public let gapCount: Int
    /// Which generated form produced this puzzle (for feedback/diagnostics).
    public let form: BridgeForm

    public init(equation: Equation, gapCount: Int, form: BridgeForm) {
        self.equation = equation
        self.gapCount = gapCount
        self.form = form
    }
}

public struct SequencePuzzle: Codable, Hashable, Sendable {
    /// Sequence terms; exactly one is nil (the gap).
    public let terms: [Int?]
    /// Index of the gap.
    public let gapIndex: Int
    /// Step between consecutive terms (constant by construction).
    public let step: Int

    public init(terms: [Int?], gapIndex: Int, step: Int) {
        self.terms = terms
        self.gapIndex = gapIndex
        self.step = step
    }
}

/// A single answer attempt: the chosen plank value(s), in gap order.
public struct Answer: Codable, Hashable, Sendable {
    public let values: [Int]

    public init(_ values: [Int]) { self.values = values }
}

public enum Verdict: Codable, Equatable, Sendable {
    /// All gaps filled and valid.
    case correct
    /// Filled but wrong; optional diagnosed misconception.
    case incorrect(MisconceptionKind?)
    /// Not all gaps filled yet.
    case incomplete
}
