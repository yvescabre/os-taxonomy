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
                        VStack(spacing: 18) {
                            HStack(spacing: 16) {
                                CompanionView(species: profile.companionSpecies,
                                              colorName: profile.companionColor,
                                              accessory: profile.companionAccessory, size: 88)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(localizer.string(.dailyAdventureTitle))
                                        .font(Theme.roundedFont(30, weight: .black))
                                        .foregroundStyle(Theme.ink)
                                    ProgressView(value: Double(log.stagesCompleted),
                                                 total: Double(max(1, plan.stages.count)))
                                        .tint(Theme.leaf)
                                        .accessibilityIdentifier("adventure-progress")
                                    Text(localizer.string(.adventureProgressFormat, [
                                        .number(log.stagesCompleted), .number(plan.stages.count)
                                    ]))
                                    .font(Theme.roundedFont(16, weight: .bold))
                                    .foregroundStyle(Theme.inkSoft)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Theme.ink.opacity(0.10), radius: 12, x: 0, y: 6)
                            if log.completedAt != nil {
                                Label(localizer.string(.adventureComplete), systemImage: "sparkles")
                                    .font(Theme.roundedFont(25, weight: .heavy))
                                    .padding(22)
                                    .background(Theme.sun.opacity(0.25),
                                                in: RoundedRectangle(cornerRadius: 24))
                                    .shadow(color: Theme.ink.opacity(0.10), radius: 10, x: 0, y: 5)
                            }
                            ForEach(Array(plan.stages.enumerated()), id: \.offset) { index, stage in
                                stageRow(index: index, stage: stage, log: log)
                            }
                            Button(localizer.string(.doneButton)) { dismiss() }
                                .buttonStyle(.leaf)
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
                        .font(Theme.roundedFont(17, weight: .bold)).foregroundStyle(Theme.ink)
                }
            }
        }
        .fontDesign(.rounded)
        .background(Theme.cream.ignoresSafeArea())
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
            stageCard {
                stageContent(title: stageTitle, rounds: stage.rounds, symbol: stateSymbol)
                Button {
                    stageStartedAt = Date()
                    path.append(index)
                } label: {
                    Label(localizer.string(.playTopic), systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.sun)
                .accessibilityIdentifier("adventure-stage-\(index)")
            }
        } else {
            stageCard {
                stageContent(title: stageTitle, rounds: stage.rounds, symbol: stateSymbol)
            }
                .accessibilityIdentifier("adventure-stage-\(index)")
        }
    }

    private func stageCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.85), lineWidth: 2))
        .shadow(color: Theme.ink.opacity(0.10), radius: 12, x: 0, y: 6)
    }

    private func stageContent(title: String, rounds: Int, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.leaf)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(Theme.roundedFont(20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(localizer.string(.roundsFormat, [.number(rounds)]))
                    .font(Theme.roundedFont(15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}
