import SwiftUI
import SwiftData
import WonderMathCore

struct ParentGateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    let profile: ChildProfile
    @State private var first = Int.random(in: 23...69)
    @State private var second = Int.random(in: 30...84)
    @State private var entry = ""
    @State private var authorized = false
    @State private var showError = false

    private var answer: Int { first + second }
    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-UITestInMemory") }

    var body: some View {
        Group {
            if authorized {
                ParentDashboardView(profile: profile)
            } else {
                VStack(spacing: 20) {
                    Text(localizer.string(.parentZoneTitle)).font(.largeTitle.bold())
                    Text(localizer.string(.parentGatePrompt, [.number(first), .number(second)]))
                        .font(.title2.bold())
                        .accessibilityIdentifier("parent-gate-prompt")
                        .accessibilityValue(isUITesting ? String(answer) : "")
                    Text(localizer.string(.parentGateHint)).font(.body)
                    Text(entry.isEmpty ? " " : localizer.format(Int(entry) ?? 0))
                        .font(.largeTitle.monospacedDigit())
                        .frame(minHeight: 56)
                        .accessibilityIdentifier("parent-gate-entry")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(1...9, id: \.self) { digit in
                            digitButton(digit)
                        }
                        Button(localizer.string(.closeButton)) { dismiss() }
                            .frame(minHeight: 64)
                            .buttonStyle(.bordered)
                        digitButton(0)
                        Button {
                            entry = String(entry.dropLast())
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("gate-delete")
                        .disabled(entry.isEmpty)
                    }
                    Button(localizer.string(.checkAnswer)) {
                        authorized = Int(entry) == answer
                        showError = !authorized
                        if !authorized {
                            entry = ""
                            first = Int.random(in: 23...69)
                            second = Int.random(in: 30...84)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: 380, minHeight: 68)
                    .accessibilityIdentifier("gate-submit")
                    .disabled(entry.isEmpty)
                    if showError {
                        Text(localizer.string(.parentGateHint))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.95, green: 0.94, blue: 0.88))
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
            Text(String(digit)).font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("gate-digit-\(digit)")
    }
}
