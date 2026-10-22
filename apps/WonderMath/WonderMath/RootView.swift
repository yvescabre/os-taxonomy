import SwiftUI
import SwiftData
import WonderMathCore

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChildProfile.createdAt) private var profiles: [ChildProfile]

    var body: some View {
        Group {
            switch appState.phase {
            case .loading:
                VStack(spacing: 18) {
                    ProgressView()
                    Text(localized: .loadingTaxonomy, localizer: appState.localizer)
                        .font(.title2.bold())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.cyan.opacity(0.12))
            case .failed:
                VStack(spacing: 24) {
                    CompanionView(species: "owl", colorName: "violet", size: 120)
                    Text(localized: .errorGeneric, localizer: appState.localizer)
                        .font(.title2.bold())
                    Button(localizer.string(.tryAgain)) { appState.load() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 64)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                if let profile = profiles.first {
                    WorldMapView(profile: profile)
                        .onAppear { appState.language = profile.language }
                } else {
                    OnboardingView()
                }
            }
        }
        .environment(\.localizer, appState.localizer)
        .task {
            await createUITestProfileIfNeeded()
        }
    }

    private var localizer: Localizer { appState.localizer }

    @MainActor
    private func createUITestProfileIfNeeded() async {
        guard appState.isUITesting, profiles.isEmpty,
              let flag = ProcessInfo.processInfo.arguments.firstIndex(of: "-UITestProfile"),
              ProcessInfo.processInfo.arguments.indices.contains(flag + 1) else { return }
        let profile = ChildProfile(name: ProcessInfo.processInfo.arguments[flag + 1], age: 8)
        modelContext.insert(profile)
        try? modelContext.save()
    }
}
