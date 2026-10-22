import SwiftUI
import SwiftData
import WonderMathCore

struct DailyAdventureView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    let profile: ChildProfile
    @State private var log: DailyAdventureLog?
    @State private var plan: DailyAdventurePlan?
    @State private var path: [Int] = []
    @State private var roundsByStage: [Int: Int] = [:]
    @State private var stageStartedAt = Date()

    var body: some View {
        let service = ProgressService(context: modelContext, profile: profile, appState: appState)
        NavigationStack(path: $path) {
            Group {
                if let plan, let log {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text(localizer.string(.dailyAdventureTitle)).font(.largeTitle.bold())
                            ProgressView(value: Double(log.stagesCompleted),
                                         total: Double(max(1, plan.stages.count)))
                                .accessibilityIdentifier("adventure-progress")
                            Text(localizer.string(.adventureProgressFormat, [
                                .number(log.stagesCompleted), .number(plan.stages.count)
                            ])).font(.headline)
                            if log.completedAt != nil {
                                Label(localizer.string(.adventureComplete), systemImage: "sparkles")
                                    .font(.title2.bold())
                                    .padding(22)
                                    .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 22))
                            }
                            ForEach(Array(plan.stages.enumerated()), id: \.offset) { index, stage in
                                stageRow(index: index, stage: stage, log: log)
                            }
                            Button(localizer.string(.doneButton)) { dismiss() }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .padding(24)
                    }
                    .navigationDestination(for: Int.self) { index in
                        let stage = plan.stages[index]
                        PuzzleView(topicId: stage.topicId,
                                   difficulty: service.adjustedDifficulty(stage.difficulty),
                                   profile: profile, appState: appState, progressService: service,
                                   recordsPracticeTime: false,
                                   onRoundFinished: {
                            let rounds = roundsByStage[index, default: 0] + 1
                            roundsByStage[index] = rounds
                            if rounds >= stage.rounds {
                                service.completeAdventureStage(log: log,
                                    secondsSpent: max(0, Int(Date().timeIntervalSince(stageStartedAt))),
                                    totalStages: plan.stages.count)
                                path = []
                            }
                        })
                        .accessibilityIdentifier("adventure-puzzle-\(index)")
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(localizer.string(.dailyAdventureTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.string(.closeButton)) { dismiss() }
                }
            }
        }
        .onAppear {
            let today = service.todayPlan()
            log = today.0
            plan = today.1
        }
    }

    @ViewBuilder
    private func stageRow(index: Int, stage: DailyAdventurePlan.AdventureStage,
                          log: DailyAdventureLog) -> some View {
        let canPlay = index == log.stagesCompleted && log.completedAt == nil
        let stageTitle = localizer.string(stage.kind.titleKey)
        let stateSymbol = index < log.stagesCompleted ? "checkmark.circle.fill" :
            (canPlay ? "play.circle.fill" : "lock.fill")
        if canPlay {
            Button {
                stageStartedAt = Date()
                path.append(index)
            } label: {
                stageContent(title: stageTitle, rounds: stage.rounds, symbol: stateSymbol)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("adventure-stage-\(index)")
        } else {
            stageContent(title: stageTitle, rounds: stage.rounds, symbol: stateSymbol)
                .accessibilityIdentifier("adventure-stage-\(index)")
        }
    }

    private func stageContent(title: String, rounds: Int, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(localizer.string(.roundsFormat, [.number(rounds)]))
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }
}
