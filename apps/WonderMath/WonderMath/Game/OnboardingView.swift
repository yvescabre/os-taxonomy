import SwiftUI
import SwiftData
import WonderMathCore

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var nameFieldFocused: Bool
    @State private var name = ""
    @State private var age = 8
    @State private var species = "fox"
    @State private var colorName = "orange"
    @State private var accessory = "none"
    @State private var step = 0
    @State private var companionBobs = false

    private let speciesOptions: [(String, L10n.Key)] = [
        ("fox", .companionFox), ("owl", .companionOwl),
        ("turtle", .companionTurtle), ("dragon", .companionDragon)
    ]
    private let colors = ["orange", "blue", "green", "violet", "pink"]
    private let accessories = ["none", "z"]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                companionPanel(in: geometry.size)
                    .frame(width: geometry.size.width * 0.44)
                rightPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.cream)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Theme.cream.ignoresSafeArea())
        .fontDesign(.rounded)
        .onAppear {
            nameFieldFocused = true
            updateCompanionMotion()
        }
        .onChange(of: step) { _, newStep in
            nameFieldFocused = newStep == 0
        }
        .onChange(of: reduceMotion) { _, _ in
            updateCompanionMotion()
        }
    }

    private func companionPanel(in size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            Theme.skyGradient
                .ignoresSafeArea()
            OnboardingHill()
                .fill(Theme.leafGradient)
                .frame(height: size.height * 0.34)
                .frame(maxHeight: .infinity, alignment: .bottom)
            VStack(spacing: 0) {
                Text(speechBubbleText)
                    .font(Theme.roundedFont(25, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 470, alignment: .leading)
                    .padding(24)
                    .background {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white)
                            .overlay(alignment: .bottomLeading) {
                                SpeechBubbleTail()
                                    .fill(.white)
                                    .frame(width: 30, height: 20)
                                    .offset(x: 46, y: 10)
                            }
                            .shadow(color: Theme.ink.opacity(0.14), radius: 12, x: 0, y: 7)
                    }
                Spacer(minLength: 12)
                CompanionView(species: species, colorName: colorName,
                              accessory: accessory, size: min(220, size.height * 0.40))
                    .offset(y: companionBobs ? -7 : 0)
                    .padding(.bottom, size.height * 0.10)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .clipped()
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            Text(localizer.string(.onboardingTitle))
                .font(Theme.roundedFont(19, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
                .padding(.bottom, 14)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.sun : Theme.sand.opacity(0.68))
                        .frame(height: 8)
                }
            }
            .frame(maxWidth: 172)
            .padding(.bottom, 20)
            Text(stepTitle)
                .font(Theme.roundedFont(31, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
            stepContent
                .id(step)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .trailing)))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: step)
                .frame(maxWidth: 560)
            Spacer(minLength: 14)
            HStack(spacing: 14) {
                if step > 0 {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                            step -= 1
                        }
                    } label: {
                        Text(localizer.string(.onboardingBack))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ghost)
                    .accessibilityIdentifier("onboarding-back")
                }
                Button(action: advance) {
                    Text(localizer.string(step == 2 ? .startAdventure : .onboardingNext))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.sun)
                .disabled(step == 0 && trimmedName.isEmpty)
                .accessibilityIdentifier(step == 2 ? "start-adventure" : "onboarding-next")
            }
            .frame(maxWidth: 560)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            nameField
        case 1:
            agePicker
        default:
            companionPicker
        }
    }

    private var nameField: some View {
        TextField("", text: $name)
            .font(Theme.roundedFont(26, weight: .medium))
            .foregroundStyle(Theme.ink)
            .focused($nameFieldFocused)
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .submitLabel(.next)
            .onSubmit(advance)
            .padding(.horizontal, 20)
            .frame(height: 76)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .leading) {
                if name.isEmpty {
                    Text(localizer.string(.childNamePlaceholder))
                        .font(Theme.roundedFont(23, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.leading, 22)
                        .allowsHitTesting(false)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.wood, lineWidth: 3))
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.woodDark)
                    .frame(height: 6)
                    .offset(y: 6)
            }
            .tint(Theme.coral)
            .accessibilityLabel(localizer.string(.childNamePlaceholder))
            .accessibilityIdentifier("onboarding-name")
    }

    private var agePicker: some View {
        HStack(spacing: 24) {
            ageButton(symbol: "minus", change: -1, disabled: age == 7)
            Text(localizer.string(.parentAgeFormat, [.number(age)]))
                .font(Theme.roundedFont(31, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 150)
            ageButton(symbol: "plus", change: 1, disabled: age == 12)
        }
    }

    private func ageButton(symbol: String, change: Int, disabled: Bool) -> some View {
        Button {
            age = min(12, max(7, age + change))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Theme.leaf, in: Circle())
                .background(alignment: .bottom) {
                    Circle()
                        .fill(Theme.leafDark)
                        .frame(height: 7)
                        .offset(y: 6)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.65 : 1)
        .accessibilityLabel(localizer.string(.chooseAge))
    }

    private var companionPicker: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(speciesOptions, id: \.0) { item in
                    Button {
                        species = item.0
                    } label: {
                        VStack(spacing: 5) {
                            CompanionView(species: item.0, colorName: colorName,
                                          accessory: accessory, size: 52)
                            Text(localizer.string(item.1))
                                .font(Theme.roundedFont(12, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .padding(7)
                        .background(selectionBackground(selected: species == item.0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("companion-\(item.0)")
                }
            }
            HStack(spacing: 10) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Button {
                        colorName = color
                    } label: {
                        Circle()
                            .fill(colorColor(color))
                            .frame(width: 34, height: 34)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .padding(4)
                            .background(selectionBackground(selected: color == colorName))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizer.string(.companionColorLabel, [.number(index + 1)]))
                }
            }
            HStack(spacing: 12) {
                ForEach(Array(accessories.enumerated()), id: \.offset) { index, item in
                    Button {
                        accessory = item
                    } label: {
                        Text(item == "z" ? "Z" : "—")
                            .font(Theme.roundedFont(27, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .padding(4)
                            .background(selectionBackground(selected: accessory == item))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizer.string(.companionAccessoryLabel, [.number(index + 1)]))
                }
            }
        }
    }

    private func selectionBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 17)
            .fill(selected ? Theme.sun.opacity(0.15) : Theme.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(selected ? Theme.sun : Theme.sand.opacity(0.8),
                            lineWidth: selected ? 3 : 1.5)
            }
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 17)
                    .fill(Theme.woodDark.opacity(selected ? 0.38 : 0.18))
                    .frame(height: 5)
                    .offset(y: 5)
            }
            .shadow(color: Theme.ink.opacity(selected ? 0.12 : 0.04),
                    radius: selected ? 8 : 3, x: 0, y: selected ? 5 : 2)
    }

    private var stepTitle: String {
        switch step {
        case 0: localizer.string(.chooseName)
        case 1: localizer.string(.chooseAge)
        default: localizer.string(.chooseCompanion)
        }
    }

    private var speechBubbleText: String {
        switch step {
        case 0:
            localizer.string(.onboardingBubbleName)
        case 1:
            localizer.string(.onboardingBubbleAge, [.text(trimmedName)])
        default:
            localizer.string(.onboardingBubbleBuddy)
        }
    }

    private func advance() {
        guard step < 2 else {
            createProfile()
            return
        }
        nameFieldFocused = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            step += 1
        }
    }

    private func updateCompanionMotion() {
        guard !reduceMotion else {
            companionBobs = false
            return
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            companionBobs = true
        }
    }

    private func createProfile() {
        let profile = ChildProfile(name: trimmedName, age: age,
                                   languageCode: appState.language.rawValue,
                                   companionSpecies: species, companionColor: colorName,
                                   companionAccessory: accessory)
        modelContext.insert(profile)
        try? modelContext.save()
    }

    private func colorColor(_ value: String) -> Color {
        switch value {
        case "blue": return Color(red: 0.28, green: 0.56, blue: 0.88)
        case "green": return Theme.leaf
        case "violet": return Theme.violet
        case "pink": return Color(red: 0.91, green: 0.46, blue: 0.63)
        default: return Color(red: 0.96, green: 0.56, blue: 0.24)
        }
    }
}

private struct OnboardingHill: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.38))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.22),
                          control1: CGPoint(x: rect.width * 0.28, y: rect.height * -0.02),
                          control2: CGPoint(x: rect.width * 0.67, y: rect.height * 0.62))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
