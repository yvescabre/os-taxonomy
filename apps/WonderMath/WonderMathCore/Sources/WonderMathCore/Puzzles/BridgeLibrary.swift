import Foundation

/// Number-range and form policy for one topic's bridge generator.
public struct BridgeProfile: Sendable {
    public enum Family: Sendable { case additive, multiplicative, mixed }

    public let topicId: String
    public let family: Family
    /// Operations this topic's puzzles may use.
    public let operations: [Operation]
    /// Forms used when an evidence index doesn't pin one down.
    public let defaultForms: [BridgeForm]
    /// Mastery mapping (evidence index → forms; nil = conversation-only).
    public let mastery: MasteryCriteria
    /// Total range per difficulty (index 0..4) for add/sub puzzles.
    public let totalRanges: [ClosedRange<Int>]
    /// Table sets per difficulty for mult/div (e.g. [2,5,10] → [3,4,8] → [2..12]).
    public let factorSets: [[Int]]
    /// Max second factor per difficulty.
    public let maxFactors: [Int]

    public init(topicId: String, family: Family, operations: [Operation],
                defaultForms: [BridgeForm], mastery: MasteryCriteria,
                totalRanges: [ClosedRange<Int>]? = nil,
                factorSets: [[Int]]? = nil, maxFactors: [Int]? = nil) {
        self.topicId = topicId
        self.family = family
        self.operations = operations
        self.defaultForms = defaultForms
        self.mastery = mastery
        self.totalRanges = totalRanges ?? BridgeProfile.defaultAdditiveRanges
        self.factorSets = factorSets ?? [Array(2...5), Array(2...6), Array(2...8), Array(2...10), Array(2...12)]
        self.maxFactors = maxFactors ?? [5, 6, 8, 10, 12]
    }

    static let defaultAdditiveRanges: [ClosedRange<Int>] = [3...10, 5...20, 11...50, 20...120, 50...400]

    public func additiveTotalRange(at difficulty: Int) -> ClosedRange<Int> {
        totalRanges[min(max(difficulty - 1, 0), totalRanges.count - 1)]
    }
    public func factorSet(at difficulty: Int) -> [Int] {
        factorSets[min(max(difficulty - 1, 0), factorSets.count - 1)]
    }
    public func maxFactor(at difficulty: Int) -> Int {
        maxFactors[min(max(difficulty - 1, 0), maxFactors.count - 1)]
    }
}

/// The curated World 1 topic → generator table. Every id below was verified
/// against the bundled taxonomy (subject, domain, age band overlap 7–12) and
/// each evidence index is mapped to bridge forms, or nil where the evidence
/// is conversational ("explain that…"), which surfaces in the parent zone.
public enum BridgeLibrary {

    static let addSubForms: [BridgeForm] = [.resultUnknown, .firstOperandUnknown, .secondOperandUnknown, .answerLeft]
    static let multDivForms: [BridgeForm] = [.resultUnknown, .firstOperandUnknown, .secondOperandUnknown, .balance]

    /// Number bonds (mt_s2mfRBoTal): pairs to 20.
    private static let numberBonds = BridgeProfile(
        topicId: "mt_s2mfRBoTal", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.resultUnknown, .firstOperandUnknown, .secondOperandUnknown],
        mastery: MasteryCriteria(creditsPerEvidence: 3, evidenceForms: [
            [.resultUnknown],                    // "8 + 5 = 13"
            [.resultUnknown],                    // "13 − 5 → 8" (generated as sub result)
            [.firstOperandUnknown, .secondOperandUnknown], // all pairs to 20
        ]),
        totalRanges: [5...10, 8...15, 10...20, 12...20, 15...20])

    /// Addition & subtraction within 20 (mt_m1W6nTQJ2b): make-ten strategies.
    private static let addSub20 = BridgeProfile(
        topicId: "mt_m1W6nTQJ2b", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.resultUnknown, .secondOperandUnknown],
        mastery: MasteryCriteria(evidenceForms: [
            [.resultUnknown],                    // make-ten addition
            [.resultUnknown],                    // decompose subtraction
            [.secondOperandUnknown, .firstOperandUnknown], // derive related fact
        ]),
        totalRanges: [5...10, 8...15, 10...20, 10...20, 10...20])

    /// Fluent add/sub within 20 (mt__t4afSyZRm).
    private static let fluent20 = BridgeProfile(
        topicId: "mt__t4afSyZRm", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.resultUnknown, .secondOperandUnknown, .firstOperandUnknown],
        mastery: MasteryCriteria(creditsPerEvidence: 2, evidenceForms: [
            [.resultUnknown], [.resultUnknown],
            [.firstOperandUnknown, .secondOperandUnknown],
        ]),
        totalRanges: [5...12, 8...18, 10...20, 10...20, 10...20])

    /// What the equals sign means (mt_oIzycTBeE4): balance forms.
    private static let equalsSign = BridgeProfile(
        topicId: "mt_oIzycTBeE4", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.balance, .answerLeft],
        mastery: MasteryCriteria(evidenceForms: [
            nil,                                 // "6 = 6 is true" → conversation
            [.balance],                          // "4 + 1 = 5 + 2 is false" → balance
            [.balance, .answerLeft],             // "=" means balance
        ]),
        totalRanges: [3...10, 4...15, 5...20, 8...40, 10...60])

    /// Finding a missing number in addition (mt_ezc2m_0dzN).
    private static let missingAddend = BridgeProfile(
        topicId: "mt_ezc2m_0dzN", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.secondOperandUnknown, .firstOperandUnknown],
        mastery: MasteryCriteria(evidenceForms: [
            [.resultUnknown],                    // "10 − 8 as what-to-add"
            nil,                                 // explain missing-addend view
            [.secondOperandUnknown, .firstOperandUnknown],
        ]),
        totalRanges: [3...10, 5...15, 8...20, 10...50, 15...100])

    /// Inverse: addition undoes subtraction (mt_ehGS_uVSJv).
    private static let inverseAddSub = BridgeProfile(
        topicId: "mt_ehGS_uVSJv", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.firstOperandUnknown, .balance],
        mastery: MasteryCriteria(evidenceForms: [
            [.balance],                          // check 15+7=22 via 22−7
            [.firstOperandUnknown, .secondOperandUnknown], // □+9=14
            nil,                                 // explain inverse
        ]),
        totalRanges: [4...12, 8...20, 10...40, 15...80, 20...150])

    /// Unknown in Addition & Subtraction (mt_3JgrHY221M): all forms.
    private static let unknownAddSub = BridgeProfile(
        topicId: "mt_3JgrHY221M", family: .additive,
        operations: [.add, .subtract],
        defaultForms: addSubForms,
        mastery: MasteryCriteria(evidenceForms: [
            [.secondOperandUnknown],             // 8 + ? = 11
            [.answerLeft, .firstOperandUnknown], // 5 = □ − 3
            [.resultUnknown],                    // 6 + 6 = □
        ]),
        totalRanges: [4...12, 8...20, 10...40, 15...80, 20...150])

    /// Adding within 100 (mt_glPPG-kTQY).
    private static let addWithin100 = BridgeProfile(
        topicId: "mt_glPPG-kTQY", family: .additive,
        operations: [.add, .subtract],
        defaultForms: [.resultUnknown, .firstOperandUnknown, .secondOperandUnknown],
        mastery: MasteryCriteria(evidenceForms: [
            [.resultUnknown],                    // 46 + 7 bridging
            [.resultUnknown],                    // 38 + 40 tens
            nil,                                 // relate to written method
        ]),
        totalRanges: [10...30, 20...60, 30...80, 40...100, 50...100])

    /// Fluent add/sub within 100 (mt_cChv2j_-Da).
    private static let fluent100 = BridgeProfile(
        topicId: "mt_cChv2j_-Da", family: .additive,
        operations: [.add, .subtract],
        defaultForms: addSubForms,
        mastery: MasteryCriteria(creditsPerEvidence: 2, evidenceForms: [
            [.resultUnknown], [.resultUnknown],
            [.secondOperandUnknown, .answerLeft],
        ]),
        totalRanges: [10...40, 20...60, 30...80, 40...100, 50...100])

    /// Add/sub within 1000 (mt_ewmuMMPAzP).
    private static let addSub1000 = BridgeProfile(
        topicId: "mt_ewmuMMPAzP", family: .additive,
        operations: [.add, .subtract],
        defaultForms: addSubForms,
        mastery: MasteryCriteria(evidenceForms: [
            [.resultUnknown],                    // 3-digit add
            [.resultUnknown],                    // 3-digit subtract
            nil,                                 // relate & explain
        ]),
        totalRanges: [30...150, 60...300, 100...500, 150...800, 200...1000])

    /// Missing number problems age 7+ (mt_XuHmIn2xje): big ranges, all forms.
    private static let missingNumber7 = BridgeProfile(
        topicId: "mt_XuHmIn2xje", family: .additive,
        operations: [.add, .subtract],
        defaultForms: addSubForms + [.balance],
        mastery: MasteryCriteria(evidenceForms: [
            addSubForms,                         // 245 + ? = 380
            nil,                                 // choose a method
            [.balance, .answerLeft],             // multi-step combined
        ]),
        totalRanges: [20...100, 50...250, 100...400, 150...700, 200...999])

    // MARK: Multiplication & division

    /// Times tables 2s/5s/10s (mt_HhuSDxwDNM).
    private static let timesTablesBasic = BridgeProfile(
        topicId: "mt_HhuSDxwDNM", family: .multiplicative,
        operations: [.multiply, .divide],
        defaultForms: [.resultUnknown, .secondOperandUnknown],
        mastery: MasteryCriteria(creditsPerEvidence: 3, evidenceForms: [
            [.resultUnknown],                    // 5 × 3 = 15
            [.resultUnknown],                    // 20 ÷ 5 = 4
            [.resultUnknown],                    // recite tables
        ]),
        factorSets: [[2, 5, 10], [2, 5, 10], [2, 5, 10], [2, 5, 10], [2, 5, 10]],
        maxFactors: [5, 6, 8, 10, 12])

    /// Times tables 3s/4s/8s (mt_wQ89AEXhz3).
    private static let timesTables348 = BridgeProfile(
        topicId: "mt_wQ89AEXhz3", family: .multiplicative,
        operations: [.multiply, .divide],
        defaultForms: [.resultUnknown, .secondOperandUnknown],
        mastery: MasteryCriteria(creditsPerEvidence: 2, evidenceForms: [
            [.resultUnknown], [.resultUnknown], [.resultUnknown],
        ]),
        factorSets: [[3, 4], [3, 4, 8], [3, 4, 8], [3, 4, 8], [3, 4, 8]],
        maxFactors: [5, 6, 8, 10, 12])

    /// All times tables to 12×12 (mt_K5jM7vlVhA).
    private static let allTimesTables = BridgeProfile(
        topicId: "mt_K5jM7vlVhA", family: .multiplicative,
        operations: [.multiply, .divide],
        defaultForms: multDivForms,
        mastery: MasteryCriteria(creditsPerEvidence: 3, evidenceForms: [
            [.resultUnknown],
            [.resultUnknown],
            [.secondOperandUnknown, .firstOperandUnknown],
        ]),
        factorSets: [Array(2...5), Array(2...7), Array(2...9), Array(2...11), Array(2...12)],
        maxFactors: [6, 8, 10, 11, 12])

    /// Fluent multiplication & division facts (mt_WX30dzi4dt).
    private static let fluentMultDiv = BridgeProfile(
        topicId: "mt_WX30dzi4dt", family: .multiplicative,
        operations: [.multiply, .divide],
        defaultForms: multDivForms,
        mastery: MasteryCriteria(creditsPerEvidence: 2, evidenceForms: [
            [.resultUnknown], [.resultUnknown],
            [.firstOperandUnknown, .secondOperandUnknown],
        ]),
        factorSets: [Array(2...6), Array(2...8), Array(2...10), Array(2...12), Array(2...12)],
        maxFactors: [6, 8, 10, 12, 12])

    /// Commutative multiplication (mt_C9ZfT-4cgn).
    private static let commutative = BridgeProfile(
        topicId: "mt_C9ZfT-4cgn", family: .multiplicative,
        operations: [.multiply],
        defaultForms: [.commutativeSwap, .balance],
        mastery: MasteryCriteria(evidenceForms: [
            [.commutativeSwap],                  // 3 × 5 = 5 × 3
            [.commutativeSwap],                  // choose the easier order
            [.balance],                          // 12 ÷ 3 ≠ 3 ÷ 12 contrast
        ]),
        factorSets: [[2, 3, 4, 5], [2, 3, 4, 5, 10], [2, 3, 4, 5, 6], Array(2...7), Array(2...9)],
        maxFactors: [5, 6, 8, 9, 10])

    /// Division as Unknown Factor (mt_GDG9_SZmsO).
    private static let divisionUnknownFactor = BridgeProfile(
        topicId: "mt_GDG9_SZmsO", family: .multiplicative,
        operations: [.multiply, .divide],
        defaultForms: [.resultUnknown, .secondOperandUnknown],
        mastery: MasteryCriteria(evidenceForms: [
            [.secondOperandUnknown],             // 8 × ? = 32
            [.resultUnknown],                    // 32 ÷ 8 via fact
            nil,                                 // explain inverse relationship
        ]),
        factorSets: [Array(2...5), Array(2...7), Array(2...9), Array(2...12), Array(2...12)],
        maxFactors: [5, 6, 8, 10, 12])

    /// Unknown in Multiplication & Division (mt_xZvDCYA5Ae).
    private static let unknownMultDiv = BridgeProfile(
        topicId: "mt_xZvDCYA5Ae", family: .multiplicative,
        operations: [.multiply, .divide],
        defaultForms: multDivForms + [.answerLeft],
        mastery: MasteryCriteria(evidenceForms: [
            [.secondOperandUnknown],             // 7 × ? = 63
            [.firstOperandUnknown],              // ? ÷ 5 = 9
            nil,                                 // explain the strategy
        ]),
        factorSets: [Array(2...6), Array(2...8), Array(2...10), Array(2...12), Array(2...12)],
        maxFactors: [6, 8, 10, 12, 12])

    /// Using inverse operations (mt_VUQNveSYjQ): full mix, bigger numbers.
    private static let inverseOps = BridgeProfile(
        topicId: "mt_VUQNveSYjQ", family: .mixed,
        operations: [.add, .subtract, .multiply, .divide],
        defaultForms: [.firstOperandUnknown, .secondOperandUnknown, .balance, .answerLeft],
        mastery: MasteryCriteria(evidenceForms: [
            addSubForms,                         // check add/sub via inverse
            multDivForms,                        // check mult/div via inverse
            nil,                                 // squaring/square-root — conversation
        ]),
        totalRanges: [20...100, 40...300, 60...500, 100...999, 100...999],
        factorSets: [Array(2...9), Array(2...12), Array(2...12), Array(2...12), Array(2...12)],
        maxFactors: [9, 12, 12, 12, 15])

    public static let profiles: [BridgeProfile] = [
        numberBonds, addSub20, fluent20, equalsSign, missingAddend,
        inverseAddSub, unknownAddSub, addWithin100, fluent100, addSub1000,
        missingNumber7,
        timesTablesBasic, timesTables348, allTimesTables, fluentMultDiv,
        commutative, divisionUnknownFactor, unknownMultDiv, inverseOps,
    ]

    public static let all: [BridgeGenerator] = profiles.map(BridgeGenerator.init(profile:))
}
