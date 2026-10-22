import SwiftUI
import WonderMathCore

struct WhyView: View {
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    let puzzle: PuzzleInstance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let why = puzzle.whyInfo {
                    section(localizer.string(.bigIdeaTitle),
                            body: localizer.string(why.bigIdea))
                    if localizer.language == .english {
                        if let wonder = why.wonder, !wonder.isEmpty {
                            section(localizer.string(.wonderTitle), body: wonder)
                        }
                        if let tryIt = why.tryIt, !tryIt.isEmpty {
                            section(localizer.string(.tryItTitle), body: tryIt)
                        }
                    }
                    if why.researchMissing {
                        Text(localizer.string(.noTeachingNotesYet))
                            .font(.body)
                            .padding(16)
                            .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
                    }
                } else {
                    Text(localizer.string(.noTeachingNotesYet))
                        .font(.body)
                        .padding(16)
                        .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
                }
                ForEach(Array(puzzle.explanation.enumerated()), id: \.offset) { index, step in
                    section("\(index + 1)", body: localizer.string(step.message))
                }
                Button(localizer.string(.closeButton)) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 64)
            }
            .padding(28)
        }
        .navigationTitle(localizer.string(.whyDoesThisWork))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            Text(body).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }
}
