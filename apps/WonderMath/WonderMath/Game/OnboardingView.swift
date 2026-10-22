import SwiftUI
import SwiftData
import WonderMathCore

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @State private var name = ""
    @State private var age = 8
    @State private var species = "fox"
    @State private var colorName = "orange"
    @State private var accessory = "none"

    private let speciesOptions: [(String, L10n.Key)] = [
        ("fox", .companionFox), ("owl", .companionOwl),
        ("turtle", .companionTurtle), ("dragon", .companionDragon)
    ]
    private let colors = ["orange", "blue", "green", "violet", "pink"]
    private let accessories = ["none", "star", "heart"]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(localizer.string(.appName)).font(.largeTitle.bold())
                Text(localizer.string(.chooseName)).font(.title2.bold())
                TextField(localizer.string(.childNamePlaceholder), text: $name)
                    .font(.title2)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 460)
                    .accessibilityIdentifier("onboarding-name")
                Text(localizer.string(.chooseAge)).font(.title2.bold())
                HStack(spacing: 24) {
                    Button { age = max(7, age - 1) } label: {
                        Image(systemName: "minus.circle.fill").font(.largeTitle)
                            .frame(width: 72, height: 72)
                    }
                    .accessibilityLabel(localizer.string(.chooseAge))
                    .disabled(age == 7)
                    Text(localizer.string(.parentAgeFormat, [.number(age)]))
                        .font(.title.bold()).frame(minWidth: 140)
                    Button { age = min(12, age + 1) } label: {
                        Image(systemName: "plus.circle.fill").font(.largeTitle)
                            .frame(width: 72, height: 72)
                    }
                    .accessibilityLabel(localizer.string(.chooseAge))
                    .disabled(age == 12)
                }
                Text(localizer.string(.chooseCompanion)).font(.title2.bold())
                HStack(spacing: 18) {
                    ForEach(speciesOptions, id: \.0) { item in
                        Button { species = item.0 } label: {
                            VStack(spacing: 8) {
                                CompanionView(species: item.0, colorName: colorName,
                                              accessory: accessory, size: 76)
                                Text(localizer.string(item.1)).font(.caption.bold())
                            }
                            .padding(12)
                            .background(species == item.0 ? Color.blue.opacity(0.17) : .white.opacity(0.8),
                                        in: RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 90)
                        .accessibilityIdentifier("companion-\(item.0)")
                    }
                }
                HStack(spacing: 12) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        Button { colorName = color } label: {
                            Circle().fill(colorColor(color)).frame(width: 46, height: 46)
                                .overlay(Circle().stroke(color == colorName ? Color.primary : Color.clear,
                                                         lineWidth: 3))
                                .frame(width: 64, height: 64)
                        }
                        .accessibilityLabel(localizer.string(.companionColorLabel, [.number(index + 1)]))
                    }
                }
                HStack(spacing: 12) {
                    ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                        Button { accessory = item } label: {
                            Image(systemName: accessorySymbol(item))
                                .font(.title2)
                                .frame(width: 64, height: 64)
                                .background(accessory == item ? Color.orange.opacity(0.2) : .clear,
                                            in: Circle())
                        }
                        .accessibilityLabel(localizer.string(.companionAccessoryLabel, [.number(index + 1)]))
                    }
                }
                Button(action: createProfile) {
                    Text(localizer.string(.startAdventure))
                        .font(.title3.bold())
                        .frame(maxWidth: 460, minHeight: 72)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("start-adventure")
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(Color.cyan.opacity(0.12))
    }

    private func createProfile() {
        let profile = ChildProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                   age: age, languageCode: appState.language.rawValue,
                                   companionSpecies: species, companionColor: colorName,
                                   companionAccessory: accessory)
        modelContext.insert(profile)
        try? modelContext.save()
    }

    private func colorColor(_ value: String) -> Color {
        switch value {
        case "blue": return .blue
        case "green": return .green
        case "violet": return .purple
        case "pink": return .pink
        default: return .orange
        }
    }

    private func accessorySymbol(_ value: String) -> String {
        switch value {
        case "star": return "star.fill"
        case "heart": return "heart.fill"
        default: return "circle"
        }
    }
}
