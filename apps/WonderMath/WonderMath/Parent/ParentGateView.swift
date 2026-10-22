import SwiftUI
import SwiftData
import WonderMathCore

struct ParentGateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    let profile: ChildProfile
    @State private var first = Self.randomFactor()
    @State private var second = Self.randomFactor()
    @State private var entry = ""
    @State private var authorized = false
    @State private var showError = false

    private var answer: Int { first * second }
    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-UITestInMemory") }

    var body: some View {
        Group {
            if authorized {
                ParentDashboardView(profile: profile)
            } else {
                VStack(spacing: 20) {
                    Text(localizer.string(.parentZoneTitle)).font(Theme.roundedFont(34, weight: .black))
                    Text(localizer.string(.parentGatePrompt, [.number(first), .number(second)]))
                        .font(Theme.roundedFont(22, weight: .heavy))
                        .accessibilityIdentifier("parent-gate-prompt")
                        .accessibilityValue(isUITesting ? String(answer) : "")
                    Text(localizer.string(.parentGateHint)).font(Theme.roundedFont(17))
                    Text(entry.isEmpty ? " " : localizer.format(Int(entry) ?? 0))
                        .font(Theme.roundedFont(34, weight: .bold).monospacedDigit())
                        .frame(minHeight: 56)
                        .accessibilityIdentifier("parent-gate-entry")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(1...9, id: \.self) { digit in
                            digitButton(digit)
                        }
                        Button(localizer.string(.closeButton)) { dismiss() }
                            .frame(minHeight: 64)
                            .buttonStyle(.ghost)
                        digitButton(0)
                        Button {
                            entry = String(entry.dropLast())
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(.ghost)
                        .accessibilityIdentifier("gate-delete")
                        .disabled(entry.isEmpty)
                    }
                    Button(localizer.string(.checkAnswer)) {
                        authorized = Int(entry) == answer
                        showError = !authorized
                        if !authorized {
                            entry = ""
                            first = Self.randomFactor()
                            second = Self.randomFactor()
                        }
                    }
                    .buttonStyle(.sun)
                    .frame(maxWidth: 380, minHeight: 68)
                    .accessibilityIdentifier("gate-submit")
                    .disabled(entry.isEmpty)
                    if showError {
                        Text(localizer.string(.parentGateHint))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(26)
                .frame(maxWidth: 540)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 32))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .fontDesign(.rounded)
                .background(Theme.cream.ignoresSafeArea())
            }
        }
        .onChange(of: authorized) { _, value in
            if value { try? modelContext.save() }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            guard entry.count < 4 else { return }
            entry.append(String(digit))
        } label: {
            Text(String(digit)).font(Theme.roundedFont(25, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.ghost)
        .accessibilityIdentifier("gate-digit-\(digit)")
    }

    private static func randomFactor() -> Int {
        (13...49).filter { $0 % 10 != 0 && $0 % 11 != 0 }.randomElement()!
    }
}
