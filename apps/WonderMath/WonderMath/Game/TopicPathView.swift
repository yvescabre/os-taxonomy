import SwiftUI
import SwiftData
import WonderMathCore

struct TopicPathView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    let profile: ChildProfile
    @State private var path: [String] = []

    var body: some View {
        let service = ProgressService(context: modelContext, profile: profile, appState: appState)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    Button {
                        if let decision = service.nextDecision() {
                            let target: String
                            switch decision {
                            case .practice(let topicId, _), .review(let topicId, _):
                                target = topicId
                            case .scaffold(let topicId, _):
                                target = topicId
                            }
                            path.append(target)
                        } else if let topicId = appState.playableOrder.first(where: {
                            service.isUnlocked($0)
                        }) {
                            path.append(topicId)
                        }
                    } label: {
                        Label(localizer.string(.playTopic), systemImage: "arrow.right.circle.fill")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 72)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("play-next")

                    ForEach(Array(appState.playableOrder.enumerated()), id: \.element) { index, topicId in
                        if let topic = appState.store.topic(topicId) {
                            let progress = service.progress(for: topicId)
                            let unlocked = service.isUnlocked(topicId)
                            let displayState = displayState(for: progress)
                            topicRow(topic: topic, index: index, progress: progress,
                                     unlocked: unlocked, state: displayState)
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(red: 0.94, green: 0.96, blue: 0.9))
            .navigationTitle(localizer.string(.topicPathTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.string(.worldMapTitle)) { dismiss() }
                        .accessibilityIdentifier("back-to-map")
                }
            }
            .navigationDestination(for: String.self) { topicId in
                let progress = service.progress(for: topicId)
                PuzzleView(topicId: topicId,
                           difficulty: service.adjustedDifficulty(progress?.difficulty ?? 1),
                           profile: profile, appState: appState, progressService: service)
            }
        }
    }

    @ViewBuilder
    private func topicRow(topic: Topic, index: Int, progress: SkillProgress?,
                          unlocked: Bool, state: DisplayMasteryState) -> some View {
        let name = TaxonomyLocalization.displayName(of: topic, language: appState.language)
        let status = statusLabel(state)
        if unlocked {
            NavigationLink(value: topic.id) {
                HStack(spacing: 16) {
                    Text("\(index + 1)")
                        .font(.title2.bold())
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.65), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(name).font(.headline)
                        Text(status).font(.subheadline)
                    }
                    Spacer()
                    Image(systemName: state == .mastered ? "checkmark.seal.fill" :
                            state == .review ? "arrow.clockwise.circle.fill" : "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(state == .mastered ? .green : .blue)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 76)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("topic-\(topic.id)")
            .accessibilityValue(status)
        } else {
            HStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).font(.headline)
                    Text(localizer.string(.lockedBadge)).font(.subheadline)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(.gray.opacity(0.13), in: RoundedRectangle(cornerRadius: 22))
            .accessibilityIdentifier("topic-locked-\(topic.id)")
        }
    }

    private func displayState(for progress: SkillProgress?) -> DisplayMasteryState {
        guard let progress else { return .notStarted }
        return progress.state.displayState(dueForReview: progress.nextReviewDate.map { $0 <= .now } ?? false)
    }

    private func statusLabel(_ state: DisplayMasteryState) -> String {
        switch state {
        case .notStarted: return localizer.string(.masteryNotStarted)
        case .learning: return localizer.string(.masteryLearning)
        case .mastered: return localizer.string(.masteryMastered)
        case .review: return localizer.string(.masteryReview)
        }
    }

}
