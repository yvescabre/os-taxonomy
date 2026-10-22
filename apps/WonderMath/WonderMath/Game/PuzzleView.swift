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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var session: PuzzleSession
    @State private var scene = BridgeScene(size: CGSize(width: 1100, height: 500))
    @State private var showingWhy = false
    @State private var showReward = false
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
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    bridgeArea
                        .frame(height: geometry.size.height * 0.64)
                    tray
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Theme.cream)
                if showReward, let result = session.result {
                    RewardOverlay(result: result, profile: profile, localizer: localizer,
                                  reduceMotion: reduceMotion) {
                        advance(result)
                    }
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
        .fontDesign(.rounded)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: preparePuzzle)
        .onChange(of: session.puzzle.id) { _, _ in preparePuzzle() }
        .onChange(of: session.feedback) { _, value in
            if let value { speech.speak(value, localizer: localizer, enabled: profile.audioEnabled) }
        }
        .sheet(isPresented: $showingWhy) { NavigationStack { WhyView(puzzle: session.puzzle) } }
    }

    private var bridgeArea: some View {
        ZStack {
            SpriteView(scene: scene)
                .accessibilityIdentifier("bridge-scene")
            VStack {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .heavy))
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(.ghost)
                    .clipShape(Circle())
                    .accessibilityLabel(localizer.string(.closeButton))
                    .accessibilityIdentifier("back-from-puzzle")
                    Text(topicTitle).chip()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                Spacer()
            }
            if !session.isSolved {
                VStack {
                    Spacer()
                    Text(localizer.string(.dropPlankHere))
                        .font(Theme.roundedFont(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.94), in: Capsule())
                        .padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { values, _ in
            guard session.acceptsAnswers,
                  let first = values.first, let number = Int(first) else { return false }
            session.place(number)
            scene.fill(gapWith: number)
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bridge-drop-target")
    }

    private var tray: some View {
        VStack(spacing: 8) {
            helperBubble
            HStack(spacing: 12) {
                ForEach(Array(session.choices.enumerated()), id: \.offset) { _, value in
                    plankButton(value)
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Button {
                    if let hint = session.nextHint() {
                        speech.speak(hint.message, localizer: localizer, enabled: profile.audioEnabled)
                    }
                } label: {
                    Label(currentHintTitle, systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.ghost)
                .disabled(!session.acceptsAnswers || session.hintLevel == .walkthrough)
                .accessibilityIdentifier("hint-button")
                Button(localizer.string(.whyDoesThisWork)) { showingWhy = true }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .buttonStyle(.ghost)
                    .accessibilityIdentifier("why-button")
                Button {
                    if session.isRetry {
                        session.continueAfterRetry()
                        scene.clearGap()
                        scene.wobble()
                    } else {
                        session.submit()
                        if session.isSolved {
                            scene.celebrate()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeOut(duration: 0.35)) { showReward = true }
                            }
                        } else if session.isRetry {
                            scene.wobble()
                        }
                    }
                } label: {
                    Text(localizer.string(session.isRetry ? .tryAgain : .checkAnswer))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.leaf)
                .disabled(!session.isRetry && !session.canSubmit)
                .accessibilityIdentifier(session.isRetry ? "retry-button" : "check-answer")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.cream)
    }

    private var helperBubble: some View {
        HStack(alignment: .center, spacing: 12) {
            CompanionView(species: profile.companionSpecies,
                          colorName: profile.companionColor,
                          accessory: profile.companionAccessory, size: 58)
            VStack(alignment: .leading, spacing: 5) {
                if let feedback = session.feedback {
                    Text(localizer.string(feedback))
                        .font(Theme.roundedFont(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("feedback-banner")
                }
                if let hint = session.visibleHint {
                    Text(localizer.string(hint))
                        .font(Theme.roundedFont(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("hint-message")
                }
                if session.feedback == nil && session.visibleHint == nil {
                    Text(localizer.string(instructionMessage))
                        .font(Theme.roundedFont(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            hintLadder
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(helperColor, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 2))
    }

    private var hintLadder: some View {
        VStack(alignment: .leading, spacing: 5) {
            ladderStep(.nudge, title: localizer.string(.hintNudgeTitle))
            ladderStep(.clue, title: localizer.string(.hintClueTitle))
            ladderStep(.walkthrough, title: localizer.string(.hintWalkthroughTitle))
        }
        .accessibilityHidden(true)
    }

    private func ladderStep(_ level: HintLevel, title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(session.hintLevel.map { $0.rawValue >= level.rawValue } == true ? Theme.sun : Theme.ink.opacity(0.16))
                .frame(width: 9, height: 9)
            Text(title).font(Theme.roundedFont(11, weight: .bold)).foregroundStyle(Theme.inkSoft)
        }
    }

    private func plankButton(_ value: Int) -> some View {
        let isCorrect = session.correctValueForUITesting == value
        return Button {
            guard session.acceptsAnswers else { return }
            session.place(value)
            scene.fill(gapWith: value)
        } label: {
            Text(localizer.format(value))
                .font(Theme.roundedFont(28, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 68)
                .foregroundStyle(.white)
                .background(Theme.woodGradient, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.woodDark, lineWidth: 3))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5).fill(Theme.woodDark)
                        .frame(height: 6).padding(.horizontal, 5).offset(y: 4)
                }
                .shadow(color: Theme.ink.opacity(0.16), radius: 4, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .draggable(String(value))
        .disabled(!session.acceptsAnswers)
        .opacity(session.acceptsAnswers ? 1 : 0.85)
        .accessibilityLabel(localizer.format(value))
        .accessibilityIdentifier(isCorrect && appState.isUITesting ? "plank-correct" : "plank-\(value)")
        .accessibilityValue(appState.isUITesting && isCorrect ? String(value) : "")
    }

    private var helperColor: Color {
        if session.isRetry { return Theme.warmFeedback }
        if session.visibleHint != nil { return Theme.hintFeedback }
        return .white
    }

    private var topicTitle: String {
        appState.store.topic(session.topicId).map {
            TaxonomyLocalization.displayName(of: $0, language: appState.language)
        } ?? localizer.string(.appName)
    }

    private var instructionMessage: LocalizedMessage {
        switch session.puzzle.config {
        case .equation:
            return LocalizedMessage(.bridgeInstructions)
        case .sequence:
            return LocalizedMessage(.sequenceInstructions)
        }
    }

    private var currentHintTitle: String {
        switch session.hintLevel {
        case nil: return localizer.string(.showHint)
        case .nudge: return localizer.string(.hintNudgeTitle)
        case .clue: return localizer.string(.hintClueTitle)
        case .walkthrough: return localizer.string(.hintWalkthroughTitle)
        }
    }

    private func preparePuzzle() {
        scene.scaleMode = .resizeFill
        scene.reduceMotion = reduceMotion
        let companion = CompanionView(species: profile.companionSpecies,
                                     colorName: profile.companionColor,
                                     accessory: profile.companionAccessory, size: 100)
        scene.configureCompanion(texture: companion.renderedImage(size: CGSize(width: 200, height: 200))
            .map(SKTexture.init(image:)))
        switch session.puzzle.config {
        case .equation(let puzzle):
            scene.configure(tokens: puzzle.equation.tokens)
        case .sequence(let puzzle):
            scene.configure(sequence: puzzle.terms)
        }
        if let placed = session.placedValues.last { scene.fill(gapWith: placed) }
        speech.speak(instructionMessage, localizer: localizer, enabled: profile.audioEnabled)
    }

    private func advance(_ result: RecordResult) {
        showReward = false
        onRoundFinished?()
        onNext(result)
        if result.scaffold == nil { session.nextPuzzle() }
    }
}

private struct RewardOverlay: View {
    let result: RecordResult
    let profile: ChildProfile
    let localizer: Localizer
    let reduceMotion: Bool
    let onNext: () -> Void
    @State private var rotateRays = false
    @State private var openChest = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Theme.sun, Theme.sunDark], center: .center,
                           startRadius: 20, endRadius: 650)
            Rays()
                .fill(.white.opacity(0.13))
                .frame(width: 1000, height: 1000)
                .rotationEffect(.degrees(rotateRays ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 34).repeatForever(autoreverses: false),
                           value: rotateRays)
            VStack(spacing: 15) {
                Text(localizer.string(.wellDone))
                    .font(Theme.roundedFont(42, weight: .black)).foregroundStyle(Theme.ink)
                if result.chestOpened {
                    chest
                } else {
                    starMedallion
                }
                Text(localizer.string(.xpEarnedFormat, [.number(result.xpGained)]))
                    .font(Theme.roundedFont(21, weight: .heavy)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(.white, in: Capsule())
                ForEach(result.newAchievements, id: \.id) { achievement in
                    Text(localizer.string(.newBadgeEarned) + " " + localizer.string(achievement.nameKey))
                        .font(Theme.roundedFont(17, weight: .bold))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(.white.opacity(0.88), in: Capsule())
                }
                if let decision = result.scaffold, case .scaffold = decision {
                    Text(localizer.string(.companionHelperPraise))
                        .font(Theme.roundedFont(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("scaffold-message")
                }
                HStack(spacing: 12) {
                    CompanionView(species: profile.companionSpecies,
                                  colorName: profile.companionColor,
                                  accessory: profile.companionAccessory, size: 74)
                    Text(localizer.string(.companionHelperPraise))
                        .font(Theme.roundedFont(18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
                Button(localizer.string(.nextPuzzle)) { onNext() }
                    .buttonStyle(.leaf)
                    .accessibilityIdentifier("next-puzzle")
            }
            .padding(26)
            .frame(maxWidth: 620)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reward-panel")
        .onAppear {
            rotateRays = !reduceMotion
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.2)) { openChest = true }
        }
    }

    private var chest: some View {
        ZStack {
            if result.chestOpened {
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -47)
                HStack(spacing: 8) {
                    ForEach(0..<4) { _ in Circle().fill(Theme.sun).frame(width: 20, height: 20) }
                }.offset(y: -35)
            }
            RoundedRectangle(cornerRadius: 15)
                .fill(Theme.woodGradient)
                .frame(width: 138, height: 76)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.woodDark, lineWidth: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).fill(Theme.sun).frame(width: 18, height: 76))
                .offset(y: 23)
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.woodGradient)
                .frame(width: 144, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.woodDark, lineWidth: 4))
                .rotationEffect(.degrees(result.chestOpened && openChest ? -22 : 0), anchor: .leading)
                .offset(y: -22)
        }
        .frame(width: 180, height: 110)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizer.string(.chestOpened))
        .accessibilityIdentifier("chest-reward")
    }

    private var starMedallion: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 70, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 142, height: 142)
            .background(Theme.sunDark, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 5))
    }
}

private struct Rays: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<24 {
            let start = Double(index) * .pi / 12
            let end = start + .pi / 36
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + CGFloat(cos(start)) * rect.width,
                                     y: rect.midY + CGFloat(sin(start)) * rect.height))
            path.addLine(to: CGPoint(x: rect.midX + CGFloat(cos(end)) * rect.width,
                                     y: rect.midY + CGFloat(sin(end)) * rect.height))
            path.closeSubpath()
        }
        return path
    }
}
