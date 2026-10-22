import SwiftUI
import SwiftData
import WonderMathCore

struct ParentDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.localizer) private var localizer
    @Environment(\.dismiss) private var dismiss
    let profile: ChildProfile

    private var records: [MasteryRecord] { profile.mastery }
    private var logs: [DailyAdventureLog] { profile.adventures }
    private var totalMinutes: Int {
        (records.reduce(0) { $0 + $1.totalSeconds } +
         logs.reduce(0) { $0 + $1.secondsPlayed }) / 60
    }
    private var practicedCount: Int { records.filter { $0.attempts > 0 }.count }
    private var masteredCount: Int {
        records.filter { $0.progress().state == .mastered }.count
    }
    private var overallAccuracy: Int {
        let attempts = records.reduce(0) { $0 + $1.attempts }
        guard attempts > 0 else { return 0 }
        let weighted = records.reduce(0.0) {
            $0 + $1.progress().recentAccuracy * Double($1.attempts)
        }
        return Int((weighted / Double(attempts) * 100).rounded())
    }
    private var service: ProgressService {
        ProgressService(context: modelContext, profile: profile, appState: appState)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        metricCard(title: localizer.string(.learningTimeTitle),
                                   value: localizer.minutes(totalMinutes),
                                   symbol: "clock")
                        metricCard(title: localizer.string(.skillsPracticedTitle),
                                   value: localizer.format(practicedCount), symbol: "books.vertical")
                        metricCard(title: localizer.string(.masteryMastered),
                                   value: localizer.format(masteredCount), symbol: "star.fill")
                        metricCard(title: localizer.string(.perSkillTableAccuracy),
                                   value: "\(overallAccuracy)%", symbol: "chart.bar.fill")
                    }
                    dashboardCard(title: localizer.string(.masteryTitle)) {
                    if records.isEmpty {
                        Text(localizer.string(.noDataYet))
                    } else {
                        ForEach(records, id: \.persistentModelID) { record in
                            skillRow(record)
                        }
                    }
                    }
                    dashboardCard(title: localizer.string(.improvementTitle)) {
                        improvementContent
                    }
                    dashboardCard(title: localizer.string(.achievementsTitle)) {
                    if profile.achievements.isEmpty {
                        Text(localizer.string(.noDataYet))
                    } else {
                        ForEach(profile.achievements, id: \.persistentModelID) { achievement in
                            if let definition = AchievementCatalog.all.first(where: {
                                $0.id == achievement.achievementId
                            }) {
                                Label(localizer.string(definition.nameKey), systemImage: "rosette")
                            }
                        }
                    }
                    }
                    dashboardCard(title: localizer.string(.offlineActivitiesTitle)) {
                        Text(localizer.string(.teachingNoteForParents))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        offlineActivityContent
                    }
                    settingsSection
                    dashboardCard(title: localizer.string(.attributionTitle)) {
                        Text(localizer.string(.attributionText)).font(.footnote)
                        Text(localizer.string(.licenseNote)).font(.footnote)
                        Text(localizer.string(.curriculumNotice)).font(.footnote)
                    }
                }
                .padding(24)
            }
            .background(Color(red: 0.95, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle(localizer.string(.parentZoneTitle))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.string(.doneButton)) { dismiss() }
                        .accessibilityIdentifier("parent-dashboard-done")
                }
            }
        }
        .fontDesign(.default)
        .onChange(of: profile.languageCode) { _, value in
            appState.language = AppLanguage(rawValue: value) ?? .english
        }
    }

    private func metricCard(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(Theme.violet)
            Text(value).font(.system(size: 23, weight: .bold, design: .default))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title).font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func dashboardCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(Theme.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func skillRow(_ record: MasteryRecord) -> some View {
        let topic = appState.store.topic(record.topicId)
        let progress = record.progress()
        let name = topic.map { TaxonomyLocalization.displayName(of: $0, language: appState.language) }
            ?? record.topicId
        let domain = topic.map {
            TaxonomyLocalization.displayDomain(subject: $0.subject, domain: $0.domain,
                                               language: appState.language)
        } ?? ""
        let state = masteryLabel(progress)
        return VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.headline)
            Text(domain).font(.caption).foregroundStyle(.secondary)
            ProgressView(value: progress.recentAccuracy)
                .tint(progress.state == .mastered ? Theme.leaf : Theme.sun)
            HStack {
                Text(localizer.string(.perSkillTableAccuracy))
                Spacer()
                Text("\(Int(progress.recentAccuracy * 100))%")
                Spacer()
                Text(localizer.string(.perSkillTableAttempts))
                Text(localizer.format(progress.attempts))
                Spacer()
                Text(state)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(progress.state == .mastered ? Theme.leaf.opacity(0.16) : Theme.sun.opacity(0.18),
                                in: Capsule())
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var improvementContent: some View {
        let grouped = Dictionary(grouping: improvementRows.sorted { $0.count > $1.count }, by: \.domain)
        if grouped.isEmpty {
            Text(localizer.string(.noDataYet))
        } else {
            ForEach(grouped.keys.sorted(), id: \.self) { domain in
                VStack(alignment: .leading, spacing: 8) {
                    Text(TaxonomyLocalization.displayDomain(subject: "Mathematics", domain: domain,
                                                            language: appState.language))
                        .font(.headline)
                    ForEach(grouped[domain] ?? [], id: \.topicId) { row in
                        Text(row.name).font(.subheadline.bold())
                        if let note = row.nextMove {
                            Text(localizer.string(.teachingNoteForParents))
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Text(localizer.string(.researchTipPrefix) + note).font(.footnote)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var improvementRows: [ImprovementRow] {
        records.compactMap { record in
            let progress = record.progress()
            let strongest = progress.misconceptionCounts.max(by: { $0.value < $1.value })
            guard strongest != nil || progress.consecutiveStruggles > 0,
                  let topic = appState.store.topic(record.topicId) else { return nil }
            let matched = strongest.flatMap {
                ErrorPatternMatcher.match($0.key, in: appState.store.research(for: record.topicId))
            }
            return ImprovementRow(
                topicId: record.topicId,
                domain: topic.domain,
                name: TaxonomyLocalization.displayName(of: topic, language: appState.language),
                nextMove: matched?.nextMove,
                count: strongest?.value ?? progress.consecutiveStruggles
            )
        }
    }

    @ViewBuilder
    private var offlineActivityContent: some View {
        let practiced = records.filter { $0.attempts > 0 }.map(\.topicId)
        let frontier = appState.playableOrder.first(where: { service.isUnlocked($0) })
        let topicIds = Array(Set(practiced + (frontier.map { [$0] } ?? []))).sorted()
        let activities = topicIds.compactMap { topicId -> OfflineActivity? in
            guard let record = appState.store.research(for: topicId),
                  let activity = record.learn?.activities.first else { return nil }
            return OfflineActivity(topicId: topicId, activity: activity)
        }
        if activities.isEmpty {
            Text(localizer.string(.noDataYet))
        } else {
            ForEach(activities) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.store.topic(entry.topicId).map {
                        TaxonomyLocalization.displayName(of: $0, language: appState.language)
                    } ?? entry.topicId)
                    .font(.headline)
                    Text(entry.activity.title).font(.subheadline.bold())
                    ForEach(Array(entry.activity.learnerActions.prefix(3).enumerated()), id: \.offset) { _, action in
                        Text("• \(action)").font(.footnote)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }

    private var settingsSection: some View {
        dashboardCard(title: localizer.string(.settingsSectionTitle)) {
            VStack(alignment: .leading, spacing: 10) {
                Stepper(value: Binding(get: { profile.age }, set: {
                    profile.age = min(12, max(7, $0))
                    service.saveChanges()
                }), in: 7...12) {
                    Text(localizer.string(.parentAgeFormat, [.number(profile.age)]))
                }
                .frame(minHeight: 64)
                Picker(localizer.string(.difficultyLabel), selection: Binding(get: {
                    profile.difficultyOffset
                }, set: {
                    profile.difficultyOffset = $0
                    service.saveChanges()
                })) {
                    Text(localizer.string(.difficultyGentler)).tag(-1)
                    Text(localizer.string(.difficultyBalanced)).tag(0)
                    Text(localizer.string(.difficultyBolder)).tag(1)
                }
                .pickerStyle(.segmented)
                Picker(localizer.string(.languageLabel), selection: Binding(get: {
                    profile.languageCode
                }, set: {
                    profile.languageCode = $0
                    appState.language = AppLanguage(rawValue: $0) ?? .english
                    service.saveChanges()
                })) {
                    Text(localizer.string(.languageEnglish)).tag(AppLanguage.english.rawValue)
                    Text(localizer.string(.languageGerman)).tag(AppLanguage.german.rawValue)
                }
                Toggle(localizer.string(.audioLabel), isOn: Binding(get: {
                    profile.audioEnabled
                }, set: {
                    profile.audioEnabled = $0
                    service.saveChanges()
                }))
                .frame(minHeight: 64)
            }
        }
    }

    private func masteryLabel(_ progress: SkillProgress) -> String {
        switch progress.state.displayState(dueForReview: progress.nextReviewDate.map { $0 <= .now } ?? false) {
        case .notStarted: return localizer.string(.masteryNotStarted)
        case .learning: return localizer.string(.masteryLearning)
        case .mastered: return localizer.string(.masteryMastered)
        case .review: return localizer.string(.masteryReview)
        }
    }
}

private struct ImprovementRow {
    let topicId: String
    let domain: String
    let name: String
    let nextMove: String?
    let count: Int
}

private struct OfflineActivity: Identifiable {
    let topicId: String
    let activity: LearningActivity
    var id: String { topicId }
}
