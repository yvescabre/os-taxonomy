import WonderMathCore

struct StarProgress: Equatable {
    let earned: Int
    let total: Int
    let fillFraction: Double
    private let earnedEvidenceIndices: Set<Int>

    init(criteria: MasteryCriteria, progress: SkillProgress) {
        let assessableIndices = criteria.evidenceForms.enumerated().compactMap {
            $0.element == nil ? nil : $0.offset
        }
        let earnedIndices = Set(assessableIndices.filter {
            (progress.evidenceCredits[$0] ?? 0) >= criteria.creditsPerEvidence
        })
        let completedCredits = assessableIndices.reduce(0) {
            $0 + min(progress.evidenceCredits[$1] ?? 0, criteria.creditsPerEvidence)
        }

        total = assessableIndices.count
        earned = earnedIndices.count
        fillFraction = total > 0 && criteria.creditsPerEvidence > 0
            ? Double(completedCredits) / Double(total * criteria.creditsPerEvidence)
            : 0
        earnedEvidenceIndices = earnedIndices
    }

    func isEarned(at evidenceIndex: Int) -> Bool {
        earnedEvidenceIndices.contains(evidenceIndex)
    }
}
