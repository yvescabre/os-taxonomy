import SwiftUI
import SpriteKit
import SwiftData
import WonderMathCore

private enum MapSheet: Identifiable {
    case comingSoon(WorldDefinition)
    case buddy

    var id: String {
        switch self {
        case .comingSoon(let world): return world.id.rawValue
        case .buddy: return "buddy"
        }
    }
}

struct WorldMapView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let profile: ChildProfile
    @State private var activeSheet: MapSheet?
    @State private var showingTopicPath = false
    @State private var showingAdventure = false
    @State private var showingParent = false
    @State private var comingSoonDetent: PresentationDetent = .large
    @State private var scene = WorldMapScene(size: CGSize(width: 1200, height: 800))

    private let companionOptions: [(String, L10n.Key)] = [
        ("fox", .companionFox), ("owl", .companionOwl),
        ("turtle", .companionTurtle), ("dragon", .companionDragon)
    ]
    private let colorOptions = ["orange", "blue", "green", "violet", "pink"]
    private var localizer: Localizer { appState.localizer }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                ForEach(WorldCatalog.worlds, id: \.id) { world in
                    worldButton(world)
                        .position(position(for: world.id, in: geometry.size))
                }
                companionGreeting(in: geometry.size)
                header
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 26)
                    .padding(.top, 26)
                Button { showingParent = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 64, height: 64)
                        .background(.white.opacity(0.9), in: Circle())
                        .shadow(color: Theme.ink.opacity(0.15), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizer.string(.parentZoneTitle))
                .accessibilityIdentifier("parent-zone")
                .position(x: geometry.size.width - 62, y: geometry.size.height - 58)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .fontDesign(.rounded)
        .fullScreenCover(isPresented: $showingTopicPath) {
            TopicPathView(profile: profile)
        }
        .fullScreenCover(isPresented: $showingAdventure) {
            DailyAdventureView(profile: profile)
        }
        .fullScreenCover(isPresented: $showingParent) {
            ParentGateView(profile: profile)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .comingSoon(let world):
                comingSoonSheet(world)
                    .presentationDetents([.medium, .large], selection: $comingSoonDetent)
                    .presentationBackground(Theme.paper)
            case .buddy:
                buddySheet
                    .presentationDetents([.large])
            }
        }
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.updateMotionSetting(reduceMotion)
        }
        .onChange(of: reduceMotion) { _, value in
            scene.updateMotionSetting(value)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Button { activeSheet = .buddy } label: {
                HStack(spacing: 12) {
                    CompanionView(species: profile.companionSpecies,
                                  colorName: profile.companionColor,
                                  accessory: profile.companionAccessory, size: 54)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(profile.name)
                            .font(Theme.roundedFont(19, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        GeometryReader { barGeometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.ink.opacity(0.10))
                                Capsule()
                                    .fill(Theme.sunGradient)
                                    .frame(width: barGeometry.size.width * CGFloat(profile.xp % 100) / 100)
                            }
                        }
                        .frame(width: 144, height: 11)
                        Text(localizer.string(.xpFormat, [.number(profile.xp)]))
                            .font(Theme.roundedFont(13, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                            .accessibilityIdentifier("header-xp")
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(.white.opacity(0.93), in: Capsule())
                .shadow(color: Theme.ink.opacity(0.13), radius: 12, x: 0, y: 7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizer.string(.customizeBuddy))
            .accessibilityIdentifier("customize-buddy")

            Spacer(minLength: 8)
            Button { showingAdventure = true } label: {
                Label(localizer.string(.dailyAdventureTitle), systemImage: "sparkles")
                    .lineLimit(1)
            }
            .buttonStyle(.sun)
            .accessibilityIdentifier("daily-adventure")
        }
    }

    private func worldButton(_ world: WorldDefinition) -> some View {
        let playable = world.isPlayable && world.id == .numberKingdom
        return Button {
            if playable {
                showingTopicPath = true
            } else {
                comingSoonDetent = .large
                activeSheet = .comingSoon(world)
            }
        } label: {
            IslandArt(world: world, title: localizer.string(world.titleKey), open: playable)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("world-\(world.id.rawValue)")
        .accessibilityValue(playable ? localizer.string(.playTopic) : localizer.string(.lockedWorldBadge))
    }

    private func position(for world: WorldID, in size: CGSize) -> CGPoint {
        let fraction: CGPoint
        switch world {
        case .numberKingdom: fraction = CGPoint(x: 0.18, y: 0.68)
        case .logicLagoon: fraction = CGPoint(x: 0.43, y: 0.53)
        case .puzzlePeaks: fraction = CGPoint(x: 0.83, y: 0.47)
        case .inventorsWorkshop: fraction = CGPoint(x: 0.64, y: 0.70)
        case .mysteryIsland: fraction = CGPoint(x: 0.82, y: 0.82)
        }
        return CGPoint(x: size.width * fraction.x, y: size.height * fraction.y)
    }

    private func companionGreeting(in size: CGSize) -> some View {
        HStack(alignment: .bottom, spacing: 7) {
            CompanionView(species: profile.companionSpecies,
                          colorName: profile.companionColor,
                          accessory: profile.companionAccessory, size: 82)
            Text(localizer.string(.mapCompanionGreeting))
                .font(Theme.roundedFont(16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 17)
                .padding(.vertical, 12)
                .frame(maxWidth: 255, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 22))
                .overlay(alignment: .bottomLeading) {
                    MapBubbleTail().fill(.white).frame(width: 18, height: 14).offset(x: 24, y: 6)
                }
                .shadow(color: Theme.ink.opacity(0.12), radius: 12, x: 0, y: 7)
        }
        .position(x: size.width * 0.27, y: size.height * 0.27)
        .accessibilityElement(children: .combine)
    }

    private func comingSoonSheet(_ world: WorldDefinition) -> some View {
        VStack(spacing: 14) {
            CompanionView(species: profile.companionSpecies,
                          colorName: profile.companionColor,
                          accessory: profile.companionAccessory, size: 94)
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.sunDark)
            Text(localizer.string(world.titleKey))
                .font(Theme.roundedFont(30, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(localizer.string(.comingSoon))
                .font(Theme.roundedFont(22, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            Text(localizer.string(.comingSoonDetail))
                .font(Theme.roundedFont(18, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(localizer.string(.closeButton)) { activeSheet = nil }
                .buttonStyle(.leaf)
                .accessibilityIdentifier("close-coming-soon")
        }
        .padding(30)
        .padding(.bottom, 24)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var buddySheet: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text(localizer.string(.customizeBuddy))
                    .font(Theme.roundedFont(29, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                CompanionView(species: profile.companionSpecies,
                              colorName: profile.companionColor,
                              accessory: profile.companionAccessory, size: 96)
                HStack(spacing: 12) {
                    ForEach(companionOptions, id: \.0) { option in
                        companionSpeciesButton(option.0, titleKey: option.1)
                    }
                }
                HStack(spacing: 12) {
                    ForEach(Array(["none", "star", "heart"].enumerated()), id: \.offset) { index, item in
                        Button {
                            profile.companionAccessory = item
                            saveProfile()
                        } label: {
                            Image(systemName: item == "heart" ? "heart.fill" :
                                    item == "star" ? "star.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(Theme.sunDark)
                                .frame(width: 64, height: 64)
                                .background(profile.companionAccessory == item ? Theme.sun.opacity(0.23) : .white,
                                            in: Circle())
                        }
                        .accessibilityLabel(localizer.string(.companionAccessoryLabel, [.number(index + 1)]))
                        .accessibilityIdentifier("buddy-accessory-\(item)")
                    }
                }
                HStack(spacing: 14) {
                    ForEach(Array(colorOptions.enumerated()), id: \.offset) { _, color in
                        Button {
                            profile.companionColor = color
                            saveProfile()
                        } label: {
                            Circle().fill(companionColor(color))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(profile.companionColor == color ? Theme.ink : .white,
                                                         lineWidth: 3))
                                .frame(width: 58, height: 58)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(localizer.string(.closeButton)) { activeSheet = nil }
                    .buttonStyle(.ghost)
                    .accessibilityIdentifier("close-buddy")
            }
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .background(Theme.cream)
    }

    private func companionSpeciesButton(_ species: String, titleKey: L10n.Key) -> some View {
        Button {
            profile.companionSpecies = species
            saveProfile()
        } label: {
            VStack(spacing: 4) {
                CompanionView(species: species, colorName: profile.companionColor,
                              accessory: profile.companionAccessory, size: 56)
                Text(localizer.string(titleKey))
                    .font(Theme.roundedFont(12, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 116)
            .frame(minHeight: 82)
            .background(profile.companionSpecies == species ? Theme.sun.opacity(0.2) : .white,
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizer.string(titleKey))
        .accessibilityIdentifier("buddy-species-\(species)")
    }

    private func saveProfile() {
        try? modelContext.save()
    }

    private func companionColor(_ name: String) -> Color {
        switch name {
        case "blue": return Color(red: 0.28, green: 0.56, blue: 0.88)
        case "green": return Color(red: 0.25, green: 0.66, blue: 0.48)
        case "violet": return Color(red: 0.57, green: 0.4, blue: 0.78)
        case "pink": return Color(red: 0.91, green: 0.46, blue: 0.63)
        default: return Color(red: 0.96, green: 0.56, blue: 0.24)
        }
    }
}

private struct IslandArt: View {
    let world: WorldDefinition
    let title: String
    let open: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        VStack(spacing: -2) {
            ZStack(alignment: .center) {
                Ellipse().fill(Theme.wood.opacity(0.8))
                    .frame(width: 218, height: 62).offset(y: 29)
                Ellipse().fill(LinearGradient(colors: [Color(red: 0.56, green: 0.85, blue: 0.47),
                                                       Color(red: 0.31, green: 0.66, blue: 0.36)],
                                              startPoint: .top, endPoint: .bottom))
                    .frame(width: 204, height: 58).offset(y: 15)
                IslandIllustration(world: world.id)
                    .frame(width: 164, height: 134)
                    .offset(y: -16)
                if !open {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 42, height: 42)
                        .background(.white, in: Circle())
                        .shadow(color: Theme.ink.opacity(0.18), radius: 6, x: 0, y: 3)
                        .offset(x: 89, y: -55)
                }
            }
            .frame(width: 226, height: 145)
            Text(title)
                .font(Theme.roundedFont(16, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(open ? Theme.ink : Theme.inkSoft)
                .lineLimit(2)
                .frame(width: 220, height: 48)
                .background(.white.opacity(open ? 0.94 : 0.72), in: Capsule())
                .shadow(color: Theme.ink.opacity(0.14), radius: 7, x: 0, y: 4)
        }
        .frame(width: 232, height: 195)
        .saturation(open ? 1 : 0.25)
        .opacity(open ? 1 : 0.78)
        .offset(y: reduceMotion ? 0 : (floating ? -6 : 0))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

private struct IslandIllustration: View {
    let world: WorldID

    @ViewBuilder
    var body: some View {
        switch world {
        case .numberKingdom:
            CastleIsland()
        case .logicLagoon:
            LagoonIsland()
        case .puzzlePeaks:
            PeaksIsland()
        case .inventorsWorkshop:
            WorkshopIsland()
        case .mysteryIsland:
            MysteryIsland()
        }
    }
}

private struct CastleIsland: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            CastleTower(width: 38, height: 68, roof: Theme.coral, number: "1")
            Rectangle().fill(Color(red: 1, green: 0.93, blue: 0.77))
                .frame(width: 72, height: 80)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.woodDark.opacity(0.55))
                        .frame(width: 24, height: 37)
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.woodDark, lineWidth: 3))
            CastleTower(width: 40, height: 92, roof: Theme.violet, number: "2")
        }
        .shadow(color: Theme.ink.opacity(0.18), radius: 5, x: 0, y: 5)
    }
}

private struct CastleTower: View {
    let width: CGFloat
    let height: CGFloat
    let roof: Color
    let number: String

    var body: some View {
        VStack(spacing: -1) {
            MapTriangle().fill(roof).frame(width: width + 12, height: 25)
            Rectangle().fill(Color(red: 1, green: 0.92, blue: 0.75))
                .frame(width: width, height: height - 25)
                .overlay(alignment: .top) {
                    Text(number).font(Theme.roundedFont(16, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.coral, in: Capsule())
                        .offset(y: -9)
                }
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.woodDark, lineWidth: 3))
        }
    }
}

private struct LagoonIsland: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Theme.waterGradient).frame(width: 148, height: 82)
                .overlay(Ellipse().stroke(.white.opacity(0.75), lineWidth: 4))
            Ellipse().fill(Theme.leaf).frame(width: 42, height: 19).offset(x: -34, y: -6)
            Ellipse().fill(Theme.leafDark).frame(width: 34, height: 16).offset(x: 40, y: 12)
            Circle().fill(Theme.sun).frame(width: 18, height: 18).offset(x: 40, y: 12)
            HStack(alignment: .bottom, spacing: 14) {
                Reed().stroke(Theme.leafDark, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 21, height: 65)
                Reed().stroke(Theme.leafDark, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 21, height: 54).scaleEffect(x: -1, y: 1)
            }
            .offset(x: -61, y: -28)
        }
    }
}

private struct PeaksIsland: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            MountainShape().fill(Color(red: 0.50, green: 0.68, blue: 0.79))
                .frame(width: 106, height: 112).offset(x: -29)
            MountainShape().fill(Color(red: 0.66, green: 0.79, blue: 0.87))
                .frame(width: 92, height: 90).offset(x: 42, y: 7)
            SnowCap().fill(.white).frame(width: 47, height: 42).offset(x: -29, y: -70)
            SnowCap().fill(.white).frame(width: 39, height: 34).offset(x: 42, y: -61)
        }
    }
}

private struct WorkshopIsland: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 1, green: 0.91, blue: 0.75))
                .frame(width: 112, height: 77)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.woodDark.opacity(0.65)).frame(width: 28, height: 43)
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.woodDark, lineWidth: 3))
            MapTriangle().fill(Theme.coral)
                .frame(width: 134, height: 47)
                .offset(y: -70)
            Capsule().fill(Theme.woodDark).frame(width: 18, height: 44)
                .offset(x: 30, y: -99)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(Theme.violet)
                .offset(x: 52, y: -5)
        }
    }
}

private struct MysteryIsland: View {
    var body: some View {
        ZStack {
            Capsule().fill(Theme.woodDark).frame(width: 15, height: 77)
                .rotationEffect(.degrees(-9)).offset(x: -34, y: 12)
            ForEach(0..<5) { index in
                PalmFrond().fill(index.isMultiple(of: 2) ? Theme.leaf : Theme.leafDark)
                    .frame(width: 58, height: 35)
                    .rotationEffect(.degrees(Double(index) * 62 - 130))
                    .offset(x: -34, y: -28)
            }
            Text("?")
                .font(Theme.roundedFont(66, weight: .black))
                .foregroundStyle(Theme.violet)
                .offset(x: 46, y: 13)
        }
    }
}

private struct MapTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width * 0.52, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct SnowCap: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width * 0.50, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.height * 0.52))
            path.addLine(to: CGPoint(x: rect.width * 0.80, y: rect.height * 0.38))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct PalmFrond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
                              control: CGPoint(x: rect.width * 0.55, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                              control: CGPoint(x: rect.width * 0.70, y: rect.height * 0.88))
            path.closeSubpath()
        }
    }
}

private struct Reed: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.40, y: rect.minY),
                              control: CGPoint(x: rect.width * 0.12, y: rect.height * 0.45))
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY * 0.80))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.35),
                              control: CGPoint(x: rect.width * 0.88, y: rect.height * 0.45))
        }
    }
}

private struct MapBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
