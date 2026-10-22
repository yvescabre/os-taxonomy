import Foundation

// MARK: - Topics (mirrors schema/topics.schema.json)

public enum TopicType: String, Codable, CaseIterable, Sendable {
    case conceptual = "CONCEPTUAL"
    case procedural = "PROCEDURAL"
    case representational = "REPRESENTATIONAL"
    case language = "LANGUAGE"
    case meta = "META"
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TopicType(rawValue: raw) ?? .unknown
    }
}

public struct Topic: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let type: TopicType
    public let subject: String
    public let domain: String
    public let name: String
    public let description: String
    public let ageRangeStart: Int
    public let ageRangeEnd: Int
    public let centrality: Double
    public let evidence: [String]
    /// Contains a `{{name}}` placeholder for the child's name.
    public let assessmentPrompt: String?
    public let standards: [String]

    /// The parent-facing assessment question with the `{{name}}` placeholder
    /// replaced by the child's name, or stripped to a neutral phrasing.
    public func assessmentPrompt(forChild name: String?) -> String {
        guard let prompt = assessmentPrompt else { return "" }
        if let name, !name.isEmpty {
            return prompt.replacingOccurrences(of: "{{name}}", with: name)
        }
        return prompt.replacingOccurrences(of: "{{name}}", with: "your child")
    }
}

public struct TopicsFile: Codable, Sendable {
    public let version: String?
    public let topicCount: Int?
    public let topics: [Topic]
}

// MARK: - Dependencies (mirrors schema/dependencies.schema.json)

public enum EdgeStrength: String, Codable, Sendable {
    case hard
    case soft
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = EdgeStrength(rawValue: raw) ?? .unknown
    }
}

public struct Dependency: Codable, Hashable, Sendable {
    /// `topicId` depends on `prerequisiteId`. Reversing the edge gives "unlocks".
    public let topicId: String
    public let prerequisiteId: String
    public let strength: EdgeStrength
    public let reason: String?
}

public struct DependenciesFile: Codable, Sendable {
    public let version: String?
    public let note: String?
    public let edgeCount: Int?
    public let dependencies: [Dependency]
}

// MARK: - Teaching research (mirrors schema/teaching-research.schema.json)

public struct Pedagogy: Codable, Hashable, Sendable {
    public let summary: String?
    public let bestPractices: [String]
    public let keyRepresentations: [String]
    public let commonMisconceptions: [String]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        bestPractices = try c.decodeIfPresent([String].self, forKey: .bestPractices) ?? []
        keyRepresentations = try c.decodeIfPresent([String].self, forKey: .keyRepresentations) ?? []
        commonMisconceptions = try c.decodeIfPresent([String].self, forKey: .commonMisconceptions) ?? []
    }
}

public struct LearningActivity: Codable, Hashable, Sendable {
    public let title: String
    public let learnerActions: [String]
    public let intendedInsight: String?
    public let feedback: [String]
    public let rationale: String?
    public let sourceClaims: [String]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Activity"
        learnerActions = try c.decodeIfPresent([String].self, forKey: .learnerActions) ?? []
        intendedInsight = try c.decodeIfPresent(String.self, forKey: .intendedInsight)
        feedback = try c.decodeIfPresent([String].self, forKey: .feedback) ?? []
        rationale = try c.decodeIfPresent(String.self, forKey: .rationale)
        sourceClaims = try c.decodeIfPresent([String].self, forKey: .sourceClaims) ?? []
    }
}

public struct LearnContent: Codable, Hashable, Sendable {
    public let summary: String?
    public let activities: [LearningActivity]
    public let constraints: [String]
    public let reviewNotes: [String]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        activities = try c.decodeIfPresent([LearningActivity].self, forKey: .activities) ?? []
        constraints = try c.decodeIfPresent([String].self, forKey: .constraints) ?? []
        reviewNotes = try c.decodeIfPresent([String].self, forKey: .reviewNotes) ?? []
    }
}

public enum ErrorPatternKind: String, Codable, Sendable {
    case misconception
    case performance
    case developmental
    case interference
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ErrorPatternKind(rawValue: raw) ?? .unknown
    }
}

public struct ErrorPattern: Codable, Hashable, Sendable {
    public let kind: ErrorPatternKind?
    public let pattern: String?
    /// Parent-facing "next teaching move" guidance.
    public let nextMove: String?
    public let distractor: String?
    public let revealedBy: String?
    /// Optional taxonomy topic to reteach. May point outside the bundled subset.
    public let reteachPrerequisiteId: String?
}

public struct ResponseLevels: Codable, Hashable, Sendable {
    public let gap: String?
    public let partial: String?
    public let full: String?
}

public struct AssessContent: Codable, Hashable, Sendable {
    public let method: String?
    public let poeTask: String?
    public let probeDeeper: [String]
    public let correctAnswer: String?
    public let errorPatterns: [ErrorPattern]
    public let responseLevels: ResponseLevels?
    public let diagnosticPrompt: String?
    public let whatMakesItDiscriminate: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        method = try c.decodeIfPresent(String.self, forKey: .method)
        poeTask = try c.decodeIfPresent(String.self, forKey: .poeTask)
        probeDeeper = try c.decodeIfPresent([String].self, forKey: .probeDeeper) ?? []
        correctAnswer = try c.decodeIfPresent(String.self, forKey: .correctAnswer)
        errorPatterns = try c.decodeIfPresent([ErrorPattern].self, forKey: .errorPatterns) ?? []
        responseLevels = try c.decodeIfPresent(ResponseLevels.self, forKey: .responseLevels)
        diagnosticPrompt = try c.decodeIfPresent(String.self, forKey: .diagnosticPrompt)
        whatMakesItDiscriminate = try c.decodeIfPresent(String.self, forKey: .whatMakesItDiscriminate)
    }
}

public struct ResearchSource: Codable, Hashable, Sendable {
    public let claim: String?
    public let source: String?
    public let url: String?
    public let verified: Bool?
}

public struct TeachingRecord: Codable, Hashable, Sendable {
    public let topicId: String
    public let pedagogy: Pedagogy?
    public let learn: LearnContent?
    public let assess: AssessContent?
    public let sources: [ResearchSource]
    public let confidence: String?
    public let publicationNotes: PublicationNotes?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topicId = try c.decode(String.self, forKey: .topicId)
        pedagogy = try c.decodeIfPresent(Pedagogy.self, forKey: .pedagogy)
        learn = try c.decodeIfPresent(LearnContent.self, forKey: .learn)
        assess = try c.decodeIfPresent(AssessContent.self, forKey: .assess)
        sources = try c.decodeIfPresent([ResearchSource].self, forKey: .sources) ?? []
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence)
        publicationNotes = try c.decodeIfPresent(PublicationNotes.self, forKey: .publicationNotes)
    }
}

public struct PublicationNotes: Codable, Hashable, Sendable {
    public let omittedCurriculumText: [String]?
}

public struct CoverageBySubject: Codable, Hashable, Sendable {
    public let topics: Int?
    public let withResearch: Int?
    public let withoutResearch: Int?
}

public struct TeachingCoverage: Codable, Hashable, Sendable {
    public let topicCount: Int?
    public let withResearch: Int?
    public let withoutResearch: Int?
    public let bySubject: [String: CoverageBySubject]?
    public let missingTopicIds: [String]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topicCount = try c.decodeIfPresent(Int.self, forKey: .topicCount)
        withResearch = try c.decodeIfPresent(Int.self, forKey: .withResearch)
        withoutResearch = try c.decodeIfPresent(Int.self, forKey: .withoutResearch)
        bySubject = try c.decodeIfPresent([String: CoverageBySubject].self, forKey: .bySubject)
        missingTopicIds = try c.decodeIfPresent([String].self, forKey: .missingTopicIds) ?? []
    }
}

public struct TeachingResearchFile: Codable, Sendable {
    public let schemaVersion: Double?
    public let version: String?
    public let exportedAt: String?
    public let topicFileSha256: String?
    public let recordCount: Int?
    public let coverage: TeachingCoverage?
    public let notes: [String]?
    public let records: [TeachingRecord]
}
