import SwiftUI
import SpriteKit
import SwiftData
import WonderMathCore

struct PuzzleView: View {
    let topicId: String
    let difficulty: Int
    let profile: ChildProfile
    let appState: AppState
    let progressService: ProgressService
    let recordsPracticeTime: Bool
    var onRoundFinished: (() -> Void)?
    @State private var currentTopicId: String
    @State private var sessionID = UUID()

    init(topicId: String, difficulty: Int, profile: ChildProfile,
         appState: AppState, progressService: ProgressService,
         recordsPracticeTime: Bool = true,
         onRoundFinished: (() -> Void)? = nil) {
        self.topicId = topicId
        self.difficulty = difficulty
        self.profile = profile
        self.appState = appState
        self.progressService = progressService
        self.recordsPracticeTime = recordsPracticeTime
        self.onRoundFinished = onRoundFinished
        _currentTopicId = State(initialValue: topicId)
    }

    var body: some View {
        PuzzlePlayScreen(topicId: currentTopicId, difficulty: difficulty, profile: profile,
                         appState: appState, progressService: progressService,
                         recordsPracticeTime: recordsPracticeTime,
                         onNext: { result in
            if let decision = result.scaffold, case .scaffold(let target, _) = decision {
                currentTopicId = target
                sessionID = UUID()
            }
        }, onRoundFinished: onRoundFinished)
        .id(sessionID)
    }
}

private struct PuzzlePlayScreen: View {
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: PuzzleSession
    @State private var scene = BridgeScene(size: CGSize(width: 1100, height: 480))
    @State private var showingWhy = false
    @State private var speech = Speech()
    let profile: ChildProfile
    let appState: AppState
    let recordsPracticeTime: Bool
    let onNext: (RecordResult) -> Void
    let onRoundFinished: (() -> Void)?

    init(topicId: String, difficulty: Int, profile: ChildProfile,
         appState: AppState, progressService: ProgressService,
         recordsPracticeTime: Bool,
         onNext: @escaping (RecordResult) -> Void,
         onRoundFinished: (() -> Void)?) {
        _session = StateObject(wrappedValue: PuzzleSession(topicId: topicId, difficulty: difficulty,
                                                           appState: appState, progressService: progressService,
                                                           recordsPracticeTime: recordsPracticeTime))
        self.profile = profile
        self.appState = appState
        self.recordsPracticeTime = recordsPracticeTime
        self.onNext = onNext
        self.onRoundFinished = onRoundFinished
    }

    var body: some View {
        VStack(spacing: 12) {
            bridgeArea
                .frame(maxWidth: .infinity)
                .frame(height: 310)
                .clipShape(RoundedRectangle(cornerRadius: 26))
            if let feedback = session.feedback {
                HStack(spacing: 12) {
                    CompanionView(species: profile.companionSpecies,
                                  colorName: profile.companionColor,
                                  accessory: profile.companionAccessory, size: 52)
                    Text(localizer.string(feedback))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
                .accessibilityIdentifier("feedback-banner")
            } else {
                Text(localizer.string(instructionMessage))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            HStack(spacing: 12) {
                ForEach(Array(session.choices.enumerated()), id: \.offset) { _, value in
                    plankButton(value)
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 12) {
                Button {
                    if let hint = session.nextHint() {
                        speech.speak(hint.message, localizer: localizer, enabled: profile.audioEnabled)
                    }
                } label: {
                    Label(currentHintTitle, systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity, minHeight: 68)
                }
                .buttonStyle(.bordered)
                .disabled(!session.acceptsAnswers || session.hintLevel == .walkthrough)
                .accessibilityIdentifier("hint-button")
                Button(localizer.string(.whyDoesThisWork)) { showingWhy = true }
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .buttonStyle(.bordered)
                .accessibilityIdentifier("why-button")
            }
            if let hint = session.visibleHint {
                Text(localizer.string(hint))
                    .font(.body.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, 14)
                    .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("hint-message")
            }
            if session.isSolved, let result = session.result {
                rewardPanel(result)
            } else {
                Button(session.isRetry ? localizer.string(.tryAgain) : localizer.string(.checkAnswer)) {
                        if session.isRetry {
                            session.continueAfterRetry()
                            scene.clearGap()
                            scene.wobble()
                        } else {
                            session.submit()
                            if session.isSolved { scene.celebrate() }
                            else if session.isRetry { scene.wobble() }
                        }
                }
                .font(.title3.bold())
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 72)
                .disabled(!session.isRetry && !session.canSubmit)
                .accessibilityIdentifier(session.isRetry ? "retry-button" : "check-answer")
            }
        }
        .padding(18)
        .background(Color(red: 0.94, green: 0.96, blue: 0.9))
        .navigationTitle(appState.store.topic(session.topicId).map {
            TaxonomyLocalization.displayName(of: $0, language: appState.language)
        } ?? localizer.string(.appName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(localizer.string(.closeButton)) { dismiss() }
                    .accessibilityIdentifier("back-from-puzzle")
            }
        }
        .onAppear(perform: preparePuzzle)
        .onChange(of: session.puzzle.id) { _, _ in preparePuzzle() }
        .onChange(of: session.feedback) { _, value in
            if let value { speech.speak(value, localizer: localizer, enabled: profile.audioEnabled) }
        }
        .sheet(isPresented: $showingWhy) { NavigationStack { WhyView(puzzle: session.puzzle) } }
    }

    private var bridgeArea: some View {
        ZStack(alignment: .bottom) {
            SpriteView(scene: scene)
                .accessibilityIdentifier("bridge-scene")
            Text(localizer.string(.dropPlankHere))
                .font(.caption.bold())
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .dropDestination(for: String.self) { values, _ in
                    guard session.acceptsAnswers,
                          let first = values.first, let number = Int(first) else { return false }
                    session.place(number)
                    scene.fill(gapWith: number)
                    return true
                }
                .accessibilityIdentifier("bridge-drop-target")
        }
    }

    private func plankButton(_ value: Int) -> some View {
        let isCorrect = session.correctValueForUITesting == value
        return Button {
            session.place(value)
            scene.fill(gapWith: value)
        } label: {
            Text(localizer.format(value))
                .font(.title.bold())
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Color(red: 0.62, green: 0.39, blue: 0.23), in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .draggable(String(value))
        .disabled(!session.acceptsAnswers)
        .accessibilityIdentifier(isCorrect && appState.isUITesting ? "plank-correct" : "plank-\(value)")
        .accessibilityValue(appState.isUITesting && isCorrect ? String(value) : "")
    }

    private var currentHintTitle: String {
        switch session.hintLevel {
        case .nudge: return localizer.string(.hintNudgeTitle)
        case .clue: return localizer.string(.hintClueTitle)
        case .walkthrough: return localizer.string(.hintWalkthroughTitle)
        case nil: return localizer.string(.showHint)
        }
    }

    private var instructionMessage: LocalizedMessage {
        if case .sequence = session.puzzle.config {
            return LocalizedMessage(.sequenceInstructions)
        }
        return LocalizedMessage(.bridgeInstructions)
    }

    private func preparePuzzle() {
        configureScene()
        speech.speak(instructionMessage, localizer: localizer, enabled: profile.audioEnabled)
    }

    private func rewardPanel(_ result: RecordResult) -> some View {
        VStack(spacing: 8) {
            HStack {
                CompanionView(species: profile.companionSpecies,
                              colorName: profile.companionColor,
                              accessory: profile.companionAccessory, size: 48)
                Text(localizer.string(.wellDone)).font(.title2.bold())
                Spacer()
                Text(localizer.string(.xpEarnedFormat, [.number(result.xpGained)]))
                    .font(.headline)
            }
            if result.chestOpened {
                Label(localizer.string(.chestOpened), systemImage: "gift.fill")
                    .font(.headline)
                    .accessibilityIdentifier("chest-reward")
            }
            ForEach(result.newAchievements, id: \.id) { achievement in
                Label(localizer.string(.newBadgeEarned) + " " +
                      localizer.string(achievement.nameKey), systemImage: "rosette")
            }
            if let decision = result.scaffold, case .scaffold = decision {
                Text(localizer.string(.companionHelperPraise))
                    .font(.subheadline.bold())
                    .accessibilityIdentifier("scaffold-message")
            }
            Button(localizer.string(.nextPuzzle)) {
                onRoundFinished?()
                onNext(result)
                if result.scaffold == nil { session.nextPuzzle() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 64)
            .accessibilityIdentifier("next-puzzle")
        }
        .padding(14)
        .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reward-panel")
    }

    private func configureScene() {
        switch session.puzzle.config {
        case .equation(let equation): scene.configure(tokens: equation.equation.tokens)
        case .sequence(let sequence): scene.configure(sequence: sequence.terms)
        }
    }
}
