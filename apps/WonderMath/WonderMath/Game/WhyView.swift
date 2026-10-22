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
                            .font(Theme.roundedFont(17))
                            .padding(16)
                            .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
                    }
                } else {
                    Text(localizer.string(.noTeachingNotesYet))
                        .font(Theme.roundedFont(17))
                        .padding(16)
                        .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
                }
                ForEach(Array(puzzle.explanation.enumerated()), id: \.offset) { index, step in
                    section("\(index + 1)", body: localizer.string(step.message))
                }
                Button(localizer.string(.closeButton)) { dismiss() }
                    .buttonStyle(.ghost)
                    .frame(minHeight: 64)
            }
            .padding(28)
        }
        .fontDesign(.rounded)
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle(localizer.string(.whyDoesThisWork))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.roundedFont(21, weight: .heavy))
            Text(body).font(Theme.roundedFont(17))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white, lineWidth: 2))
    }
}
