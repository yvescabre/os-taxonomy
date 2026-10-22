import SwiftUI
import SpriteKit
import SwiftData
import WonderMathCore

private enum MapSheet: Identifiable {
    case comingSoon(WorldDefinition)
    case adventure
    case parent
    case buddy

    var id: String {
        switch self {
        case .comingSoon(let world): return world.id.rawValue
        case .adventure: return "adventure"
        case .parent: return "parent"
        case .buddy: return "buddy"
        }
    }
}

struct WorldMapView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    let profile: ChildProfile
    @State private var activeSheet: MapSheet?
    @State private var showingTopicPath = false

    @State private var scene = WorldMapScene(size: CGSize(width: 1200, height: 700))
    private let companionOptions: [(String, L10n.Key)] = [
        ("fox", .companionFox), ("owl", .companionOwl),
        ("turtle", .companionTurtle), ("dragon", .companionDragon)
    ]
    private let colorOptions = ["orange", "blue", "green", "violet", "pink"]

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
            VStack(spacing: 10) {
                header
                Spacer(minLength: 4)
                HStack(spacing: 14) {
                    ForEach(WorldCatalog.worlds, id: \.id) { world in
                        worldButton(world)
                    }
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 12)
            }
            .padding(.vertical, 14)
        }
        .fullScreenCover(isPresented: $showingTopicPath) {
            TopicPathView(profile: profile)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .comingSoon(let world):
                comingSoonSheet(world)
                    .presentationDetents([.medium])
            case .adventure:
                DailyAdventureView(profile: profile)
            case .parent:
                ParentGateView(profile: profile)
            case .buddy:
                buddySheet
                    .presentationDetents([.medium])
            }
        }
        .onAppear { scene.scaleMode = .resizeFill }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(profile.name).font(.title2.bold())
            CompanionView(species: profile.companionSpecies,
                          colorName: profile.companionColor,
                          accessory: profile.companionAccessory, size: 54)
                .onTapGesture { activeSheet = .buddy }
                .accessibilityLabel(localizer.string(.companionHelperPraise))
                .accessibilityAddTraits(.isButton)
            Text(localizer.string(.xpFormat, [.number(profile.xp)]))
                .font(.title3.bold())
                .accessibilityIdentifier("header-xp")
            Spacer()
            Button { activeSheet = .buddy } label: {
                Label(localizer.string(.customizeBuddy), systemImage: "person.crop.circle")
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 64)
            .accessibilityIdentifier("customize-buddy")
            Button { activeSheet = .adventure } label: {
                Label(localizer.string(.dailyAdventureTitle), systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 64)
            .accessibilityIdentifier("daily-adventure")
            Button { activeSheet = .parent } label: {
                Label(localizer.string(.parentZoneTitle), systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 64)
            .accessibilityIdentifier("parent-zone")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 24)
    }

    private func worldButton(_ world: WorldDefinition) -> some View {
        let playable = world.isPlayable && world.id == .numberKingdom
        return Button {
            if playable {
                showingTopicPath = true
            } else {
                activeSheet = .comingSoon(world)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(playable ? Color(red: 0.98, green: 0.78, blue: 0.36) : Color.gray.opacity(0.45))
                        .frame(height: 118)
                    Image(systemName: playable ? "crown.fill" : "lock.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                    if !playable {
                        Text(localizer.string(.lockedWorldBadge))
                            .font(.caption.bold())
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .offset(y: 48)
                    }
                }
                Text(localizer.string(world.titleKey))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(localizer.string(world.subtitleKey))
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 64)
        .accessibilityIdentifier("world-\(world.id.rawValue)")
        .accessibilityValue(playable ? localizer.string(.playTopic) : localizer.string(.lockedWorldBadge))
    }

    private func comingSoonSheet(_ world: WorldDefinition) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.orange)
            Text(localizer.string(world.titleKey)).font(.largeTitle.bold())
            Text(localizer.string(.comingSoon)).font(.title2)
            Text(localizer.string(.comingSoonDetail))
                .multilineTextAlignment(.center)
            Button(localizer.string(.closeButton)) { activeSheet = nil }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 64)
                .accessibilityIdentifier("close-coming-soon")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cyan.opacity(0.12))
    }

    private var buddySheet: some View {
        VStack(spacing: 12) {
            Text(localizer.string(.customizeBuddy)).font(.largeTitle.bold())
            CompanionView(species: profile.companionSpecies,
                          colorName: profile.companionColor,
                          accessory: profile.companionAccessory, size: 84)
            HStack(spacing: 12) {
                ForEach(companionOptions, id: \.0) { species, titleKey in
                    Button {
                        profile.companionSpecies = species
                        saveProfile()
                    } label: {
                        CompanionView(species: species, colorName: profile.companionColor,
                                      accessory: profile.companionAccessory, size: 56)
                            .padding(7)
                            .background(profile.companionSpecies == species ? .blue.opacity(0.18) : .clear,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel(localizer.string(titleKey))
                    .accessibilityIdentifier("buddy-species-\(species)")
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
                            .frame(width: 58, height: 58)
                            .background(profile.companionAccessory == item ? .orange.opacity(0.2) : .clear,
                                        in: Circle())
                    }
                    .accessibilityLabel(localizer.string(.companionAccessoryLabel, [.number(index + 1)]))
                    .accessibilityIdentifier("buddy-accessory-\(item)")
                }
            }
            HStack(spacing: 14) {
                ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, color in
                    Button {
                        profile.companionColor = color
                        saveProfile()
                    } label: {
                        Circle().fill(companionColor(color)).frame(width: 38, height: 38)
                            .overlay(Circle().stroke(profile.companionColor == color ? Color.primary : Color.clear,
                                                     lineWidth: 3))
                            .frame(width: 58, height: 58)
                    }
                    .accessibilityLabel(localizer.string(.companionColorLabel, [.number(index + 1)]))
                }
            }
            Button(localizer.string(.closeButton)) { activeSheet = nil }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 64)
        }
        .padding(20)
    }

    private func saveProfile() {
        try? modelContext.save()
    }

    private func companionColor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "violet": return .purple
        case "pink": return .pink
        default: return .orange
        }
    }

    private var localizer: Localizer { appState.localizer }
}
