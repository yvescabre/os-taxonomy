import SwiftUI
import SwiftData
import WonderMathCore

struct TopicPathView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let profile: ChildProfile
    @State private var path: [String] = []

    var body: some View {
        let service = ProgressService(context: modelContext, profile: profile, appState: appState)
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                let nodeCount = appState.playableOrder.count
                let lastNodeX = 110 + CGFloat(max(nodeCount - 1, 0)) * 158
                let contentWidth = max(geometry.size.width - 300,
                                       lastNodeX + 300)
                let trailHeight = max(geometry.size.height - 105, 400)
                let points = trailPoints(count: nodeCount, height: trailHeight)

                ZStack(alignment: .topLeading) {
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            MeadowBackground()
                                .frame(width: contentWidth, height: trailHeight)
                            WindingTrail(points: points)
                            ForEach(0..<max(points.count - 1, 0), id: \.self) { index in
                                let current = points[index]
                                let next = points[index + 1]
                                let middleX = (current.x + next.x) / 2
                                let middleY = (current.y + next.y) / 2
                                let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                                MeadowTree()
                                    .position(x: middleX - 18, y: middleY + side * 82)
                                MeadowFlowers()
                                    .position(x: middleX + 28, y: middleY - side * 65)
                            }
                            ForEach(Array(appState.playableOrder.enumerated()), id: \.element) { index, topicId in
                                if let topic = appState.store.topic(topicId) {
                                    let progress = service.progress(for: topicId)
                                    let state = displayState(for: progress)
                                    let unlocked = service.isUnlocked(topicId)
                                    let node = TopicNode(
                                        number: index + 1,
                                        state: state,
                                        stars: starCount(topicId: topicId, progress: progress),
                                        isNext: topicId == nextUpTopicId(service: service),
                                        species: profile.companionSpecies,
                                        colorName: profile.companionColor,
                                        accessory: profile.companionAccessory,
                                        reduceMotion: reduceMotion
                                    )
                                    if unlocked {
                                        NavigationLink(value: topic.id) { node }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(TaxonomyLocalization.displayName(
                                                of: topic, language: appState.language))
                                            .accessibilityIdentifier("topic-\(topic.id)")
                                            .accessibilityValue(statusLabel(state))
                                            .position(points[index])
                                    } else {
                                        LockedTopicNode(number: index + 1)
                                            .accessibilityIdentifier("topic-locked-\(topic.id)")
                                            .accessibilityValue(localizer.string(.lockedBadge))
                                            .position(points[index])
                                    }
                                }
                            }
                            if let last = points.last {
                                CastleIsland()
                                    .frame(width: 216, height: 136)
                                    .position(x: last.x + 150, y: last.y - 12)
                            }
                        }
                        .frame(width: contentWidth, height: trailHeight)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.top, 90)
                    .padding(.trailing, 315)
                    .padding(.bottom, 14)

                    topBar
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    nextTopicPanel(service: service)
                        .frame(width: 306)
                        .padding(.trailing, 22)
                        .padding(.top, 94)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { topicId in
                let service = ProgressService(context: modelContext, profile: profile, appState: appState)
                let progress = service.progress(for: topicId)
                PuzzleView(topicId: topicId,
                           difficulty: service.adjustedDifficulty(progress?.difficulty ?? 1),
                           profile: profile, appState: appState, progressService: service)
            }
        }
        .fontDesign(.rounded)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .heavy))
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.ghost)
            .clipShape(Circle())
            .accessibilityLabel(localizer.string(.worldMapTitle))
            .accessibilityIdentifier("back-to-map")
            Text(localizer.string(.topicPathTitle)).chip()
        }
    }

    private func nextTopicPanel(service: ProgressService) -> some View {
        let topicId = nextUpTopicId(service: service) ?? appState.playableOrder.first
        let topic = topicId.flatMap(appState.store.topic)
        let topicIndex = topicId.flatMap { appState.playableOrder.firstIndex(of: $0) } ?? 0
        let progress = topicId.flatMap(service.progress(for:))

        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: "bridge").foregroundStyle(Theme.woodDark)
                Text(localizer.string(.topicPathTitle))
                    .font(Theme.roundedFont(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 2)
                Text(localizer.string(.bridgeProgressFormat, [
                    .number(topicIndex + 1), .number(appState.playableOrder.count)
                ]))
                    .font(Theme.roundedFont(14, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            if let topic {
                Text(TaxonomyLocalization.displayName(of: topic, language: appState.language))
                    .font(Theme.roundedFont(23, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                starRow(count: starCount(topicId: topic.id, progress: progress), size: 24)
                if appState.language == .english {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(topic.evidence.enumerated()), id: \.offset) { index, evidence in
                            let earned = evidenceEarned(topicId: topic.id, index: index,
                                                        progress: progress)
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(earned ? Theme.leaf : Theme.ink.opacity(0.25))
                                Text(evidence)
                                    .font(Theme.roundedFont(14, weight: .medium))
                                    .foregroundStyle(Theme.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            Button {
                let service = ProgressService(context: modelContext, profile: profile, appState: appState)
                if let decision = service.nextDecision() {
                    let target: String
                    switch decision {
                    case .practice(let topicId, _), .review(let topicId, _):
                        target = topicId
                    case .scaffold(let topicId, _):
                        target = topicId
                    }
                    path.append(target)
                } else if let topicId = appState.playableOrder.first(where: { service.isUnlocked($0) }) {
                    path.append(topicId)
                }
            } label: {
                Label(localizer.string(.playTopic), systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sun)
            .accessibilityIdentifier("play-next")
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.8), lineWidth: 2))
        .shadow(color: Theme.ink.opacity(0.14), radius: 15, x: 0, y: 9)
    }

    private func starRow(count: Int, size: CGFloat) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<3) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < count ? Theme.sun : Theme.ink.opacity(0.15))
            }
        }
        .accessibilityHidden(true)
    }

    private func nextUpTopicId(service: ProgressService) -> String? {
        appState.playableOrder.first { topicId in
            service.isUnlocked(topicId) && service.progress(for: topicId)?.state != .mastered
        }
    }

    private func starCount(topicId: String, progress: SkillProgress?) -> Int {
        min(3, starProgress(topicId: topicId, progress: progress)?.earned ?? 0)
    }

    private func evidenceEarned(topicId: String, index: Int, progress: SkillProgress?) -> Bool {
        starProgress(topicId: topicId, progress: progress)?.isEarned(at: index) ?? false
    }

    private func starProgress(topicId: String, progress: SkillProgress?) -> StarProgress? {
        guard let criteria = appState.registry.generator(for: topicId)?.mastery else { return nil }
        let stars = StarProgress(criteria: criteria, progress: progress ?? SkillProgress())
        return stars.total > 0 ? stars : nil
    }

    private func trailPoints(count: Int, height: CGFloat) -> [CGPoint] {
        let yRatios: [CGFloat] = [0.82, 0.70, 0.72, 0.53, 0.41, 0.29, 0.32, 0.50,
                                  0.65, 0.73, 0.56, 0.39, 0.28, 0.38, 0.57, 0.74]
        return (0..<count).map { index in
            let ratio = yRatios[index % yRatios.count]
            return CGPoint(x: 110 + CGFloat(index) * 158, y: height * ratio)
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

private struct MeadowBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: [Theme.sky, Theme.skyPale],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geometry.size.height * 0.56)
                    .frame(maxHeight: .infinity, alignment: .top)
                LinearGradient(colors: [Color(red: 0.59, green: 0.87, blue: 0.49),
                                        Color(red: 0.29, green: 0.66, blue: 0.36)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geometry.size.height * 0.70)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                DistantHill()
                    .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.90, blue: 0.67).opacity(0.75),
                                                  Color(red: 0.63, green: 0.83, blue: 0.54).opacity(0.72)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: geometry.size.height * 0.28)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: geometry.size.height * 0.20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }
}

private struct DistantHill: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.48))
            path.addCurve(to: CGPoint(x: rect.width * 0.52, y: rect.height * 0.40),
                          control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.02),
                          control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.18))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.45),
                          control1: CGPoint(x: rect.width * 0.70, y: rect.height * 0.63),
                          control2: CGPoint(x: rect.width * 0.84, y: rect.height * 0.12))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct MeadowTree: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.54, green: 0.32, blue: 0.19))
                .frame(width: 7, height: 19)
                .offset(y: 14)
            Circle().fill(Theme.leafDark).frame(width: 28, height: 28).offset(x: -9, y: -4)
            Circle().fill(Theme.leaf).frame(width: 31, height: 31).offset(x: 8, y: -5)
            Circle().fill(Theme.leaf).frame(width: 25, height: 25).offset(y: -16)
        }
        .frame(width: 48, height: 54)
        .accessibilityHidden(true)
    }
}

private struct MeadowFlowers: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            flower(Theme.coral)
            flower(Theme.violet)
            flower(Theme.sun)
        }
        .accessibilityHidden(true)
    }

    private func flower(_ color: Color) -> some View {
        VStack(spacing: 1) {
            Circle().fill(color).frame(width: 9, height: 9)
            Capsule().fill(Theme.leafDark).frame(width: 2, height: 8)
        }
    }
}

private struct WindingTrail: View {
    let points: [CGPoint]

    var body: some View {
        TrailShape(points: points)
            .stroke(Theme.sand, style: StrokeStyle(lineWidth: 44, lineCap: .round, lineJoin: .round))
            .overlay {
                TrailShape(points: points)
                    .stroke(.white.opacity(0.92),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 16]))
            }
            .accessibilityHidden(true)
    }
}

private struct TrailShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            var previous = first
            for point in points.dropFirst() {
                let midpoint = (previous.x + point.x) / 2
                path.addCurve(to: point,
                              control1: CGPoint(x: midpoint, y: previous.y),
                              control2: CGPoint(x: midpoint, y: point.y))
                previous = point
            }
        }
    }
}

private struct TopicNode: View {
    let number: Int
    let state: DisplayMasteryState
    let stars: Int
    let isNext: Bool
    let species: String
    let colorName: String
    let accessory: String
    let reduceMotion: Bool
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(nodeFill)
                        .frame(width: isNext ? 86 : 72, height: isNext ? 86 : 72)
                    Circle()
                        .stroke(nodeStroke, lineWidth: isNext ? 7 : 5)
                        .frame(width: isNext ? 86 : 72, height: isNext ? 86 : 72)
                    if state == .mastered {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(Theme.roundedFont(isNext ? 29 : 24, weight: .black))
                            .foregroundStyle(Theme.ink)
                    }
                    if isNext {
                        Circle().stroke(Theme.sun.opacity(0.42), lineWidth: 5)
                            .frame(width: 98, height: 98)
                            .scaleEffect(pulsing && !reduceMotion ? 1.16 : 0.96)
                            .opacity(pulsing && !reduceMotion ? 0.4 : 0.95)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(index < stars ? Theme.sun : Theme.ink.opacity(0.18))
                    }
                }
            }
            if isNext {
                CompanionView(species: species, colorName: colorName,
                              accessory: accessory, size: 48)
                    .offset(y: 8)
            }
        }
        .frame(width: isNext ? 146 : 86, height: isNext ? 118 : 96)
        .onAppear {
            guard isNext && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }

    private var nodeFill: Color {
        switch state {
        case .mastered: return Theme.leaf
        case .learning, .review: return .white
        case .notStarted: return isNext ? Theme.sun : .white
        }
    }

    private var nodeStroke: Color {
        switch state {
        case .mastered: return Theme.leafDark
        case .learning, .review: return Theme.coral
        case .notStarted: return isNext ? Theme.sunDark : Theme.ink.opacity(0.18)
        }
    }
}

private struct LockedTopicNode: View {
    let number: Int

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Theme.inkSoft.opacity(0.45), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 4))
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink.opacity(0.2))
        }
        .frame(width: 86, height: 96)
        .accessibilityLabel("\(number)")
    }
}
