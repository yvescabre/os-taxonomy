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

private struct PlankDragState: Equatable {
    let value: Int
    let size: CGSize
    let origin: CGPoint
    var location: CGPoint
    var isOverBridge: Bool
    var isReturning: Bool
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
    @State private var activePlankDrag: PlankDragState?
    @State private var bridgeDropFrame = CGRect.zero
    let profile: ChildProfile
    let appState: AppState
    let progressService: ProgressService
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
        self.progressService = progressService
        self.recordsPracticeTime = recordsPracticeTime
        self.onNext = onNext
        self.onRoundFinished = onRoundFinished
    }

    var body: some View {
        GeometryReader { geometry in
            let bridgeSize = CGSize(width: geometry.size.width, height: geometry.size.height * 0.64)
            ZStack {
                VStack(spacing: 0) {
                    bridgeArea
                        .frame(height: bridgeSize.height)
                    tray
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Theme.cream)
                if let drag = activePlankDrag {
                    plankCard(drag.value)
                        .frame(width: drag.size.width, height: drag.size.height)
                        .scaleEffect(1.08)
                        .shadow(color: Theme.ink.opacity(0.28), radius: 14, x: 0, y: 10)
                        .position(drag.location)
                        .zIndex(2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if showReward, let result = session.result {
                    RewardOverlay(result: result, profile: profile, localizer: localizer,
                                  reduceMotion: reduceMotion) {
                        advance(result)
                    }
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: "puzzle")
            .onAppear {
                bridgeDropFrame = CGRect(origin: .zero, size: bridgeSize)
            }
            .onChange(of: geometry.size) { _, size in
                bridgeDropFrame = CGRect(
                    origin: .zero,
                    size: CGSize(width: size.width, height: size.height * 0.64)
                )
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
                    if let stars = currentStarProgress {
                        StarProgressMeter(progress: stars, localizer: localizer,
                                          reduceMotion: reduceMotion)
                    }
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bridge-drop-target")
    }

    private var tray: some View {
        VStack(spacing: 8) {
            helperBubble
            HStack(spacing: 12) {
                ForEach(Array(session.choices.enumerated()), id: \.offset) { _, value in
                    plankView(value)
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

    private func plankView(_ value: Int) -> some View {
        let isCorrect = session.correctValueForUITesting == value
        return GeometryReader { geometry in
            plankCard(value)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture { placePlank(value) }
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .named("puzzle"))
                        .onChanged { drag in
                            let frame = geometry.frame(in: .named("puzzle"))
                            updatePlankDrag(value, size: geometry.size,
                                            origin: CGPoint(x: frame.midX, y: frame.midY),
                                            location: drag.location)
                        }
                        .onEnded { drag in
                            endPlankDrag(value, location: drag.location)
                        }
                )
                .opacity(activePlankDrag?.value == value && activePlankDrag?.isReturning == false ? 0.35 : 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(localizer.format(value))
                .accessibilityIdentifier(isCorrect && appState.isUITesting ? "plank-correct" : "plank-\(value)")
                .accessibilityValue(appState.isUITesting && isCorrect ? String(value) : "")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { placePlank(value) }
                .disabled(!session.acceptsAnswers)
        }
        .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68)
    }

    private func plankCard(_ value: Int) -> some View {
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

    private func placePlank(_ value: Int) {
        guard session.acceptsAnswers else { return }
        session.place(value)
        scene.fill(gapWith: value)
    }

    private func updatePlankDrag(_ value: Int, size: CGSize, origin: CGPoint, location: CGPoint) {
        guard session.acceptsAnswers else { return }
        let isOverBridge = bridgeDropFrame.contains(location)
        let wasOverBridge = activePlankDrag?.isOverBridge == true
        if var drag = activePlankDrag, drag.value == value {
            drag.location = location
            drag.isOverBridge = isOverBridge
            activePlankDrag = drag
        } else {
            activePlankDrag = PlankDragState(value: value, size: size, origin: origin,
                                             location: location, isOverBridge: isOverBridge,
                                             isReturning: false)
        }
        if wasOverBridge != isOverBridge { scene.setGapHighlighted(isOverBridge) }
    }

    private func endPlankDrag(_ value: Int, location: CGPoint) {
        guard session.acceptsAnswers, let drag = activePlankDrag, drag.value == value else {
            scene.setGapHighlighted(false)
            activePlankDrag = nil
            return
        }
        scene.setGapHighlighted(false)
        guard bridgeDropFrame.contains(location) else {
            guard !reduceMotion else {
                activePlankDrag = nil
                return
            }
            var returningDrag = drag
            returningDrag.location = drag.origin
            returningDrag.isOverBridge = false
            returningDrag.isReturning = true
            withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) {
                activePlankDrag = returningDrag
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if activePlankDrag?.value == value, activePlankDrag?.isReturning == true {
                    activePlankDrag = nil
                }
            }
            return
        }
        placePlank(value)
        activePlankDrag = nil
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

    private var currentStarProgress: StarProgress? {
        guard let criteria = appState.registry.generator(for: session.topicId)?.mastery else { return nil }
        let progress = progressService.progress(for: session.topicId) ?? SkillProgress()
        let stars = StarProgress(criteria: criteria, progress: progress)
        return stars.total > 0 ? stars : nil
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

private struct StarProgressMeter: View {
    let progress: StarProgress
    let localizer: Localizer
    let reduceMotion: Bool
    @State private var poppingIndex: Int?
    @State private var popScale: CGFloat = 1

    var body: some View {
        HStack(spacing: 10) {
            Text(localizer.string(.progressStars))
                .font(Theme.roundedFont(15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.9373, green: 0.9020, blue: 0.8314))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.7), lineWidth: 2)
                                .padding(2)
                        }
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.ink.opacity(0.14), lineWidth: 2)
                                .padding(2)
                        }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.sunGradient)
                        .frame(width: geometry.size.width * progress.fillFraction)
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.sunDark)
                                .frame(height: 4)
                                .padding(.horizontal, 3)
                                .offset(y: 2)
                        }
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78),
                            value: progress.fillFraction
                        )
                    HStack(spacing: 0) {
                        ForEach(0..<progress.total, id: \.self) { index in
                            checkpoint(at: index)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 38)
            }
            .frame(width: 228, height: 38)
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 2))
        .shadow(color: Theme.ink.opacity(0.12), radius: 3, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizer.string(.progressStars))
        .accessibilityValue(localizer.string(.progressStarsValueFormat, [
            .number(progress.earned), .number(progress.total)
        ]))
        .accessibilityIdentifier("progress-stars")
        .onChange(of: progress.earned) { oldValue, newValue in
            guard !reduceMotion, newValue > oldValue else { return }
            poppingIndex = newValue - 1
            withAnimation(.spring(response: 0.2, dampingFraction: 0.48)) {
                popScale = 1.25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) {
                    popScale = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                poppingIndex = nil
            }
        }
    }

    private func checkpoint(at index: Int) -> some View {
        let earned = progress.isEarned(at: index)
        return Image(systemName: earned ? "star.fill" : "star")
            .font(Theme.roundedFont(17, weight: .heavy))
            .foregroundStyle(earned ? Theme.ink : Theme.ink.opacity(0.28))
            .frame(width: 38, height: 38)
            .background(earned ? Theme.sun : .white, in: Circle())
            .overlay(Circle().stroke(earned ? Theme.sunDark : Theme.sand, lineWidth: 2))
            .scaleEffect(poppingIndex == index ? popScale : 1)
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
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 15) {
                Text(localizer.string(.wellDone))
                    .font(Theme.roundedFont(42, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.25), radius: 3, x: 0, y: 3)
                if result.chestOpened {
                    chest.padding(.top, 40)
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
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(maxWidth: 620)
            .background {
                RoundedRectangle(cornerRadius: 32)
                    .fill(RadialGradient(colors: [Theme.sun, Theme.sunDark], center: .center,
                                         startRadius: 20, endRadius: 650))
            }
            .overlay {
                GeometryReader { geometry in
                    let raySize = max(geometry.size.width, geometry.size.height) * 2
                    Rays()
                        .fill(.white.opacity(0.14))
                        .frame(width: raySize, height: raySize)
                        .rotationEffect(.degrees(rotateRays ? 360 : 0))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .animation(reduceMotion ? nil :
                            .linear(duration: 34).repeatForever(autoreverses: false),
                            value: rotateRays)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(RoundedRectangle(cornerRadius: 32)
                .stroke(.white.opacity(0.58), lineWidth: 3))
            .shadow(color: Theme.ink.opacity(0.28), radius: 18, x: 0, y: 10)
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
                HStack(spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 25, weight: .black))
                    Image(systemName: "star.fill")
                        .font(.system(size: 34, weight: .black))
                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .black))
                }
                .foregroundStyle(.white)
                .shadow(color: Theme.ink.opacity(0.3), radius: 3, x: 0, y: 2)
                .offset(y: -55)
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Theme.sun)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Theme.sunDark, lineWidth: 3))
                            .offset(y: index == 1 ? -8 : 0)
                    }
                }
                .offset(y: -32)
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
