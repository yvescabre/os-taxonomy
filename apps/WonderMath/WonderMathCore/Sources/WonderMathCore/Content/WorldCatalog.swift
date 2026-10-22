import Foundation

/// The five regions of the WonderMath world map and which taxonomy content
/// they cover. Domain names below were verified against the bundled subset
/// (see tools/build_taxonomy_subset.py output); nothing is assumed.
public enum WorldID: String, CaseIterable, Codable, Sendable {
    case numberKingdom
    case logicLagoon
    case puzzlePeaks
    case inventorsWorkshop
    case mysteryIsland

    public var order: Int {
        switch self {
        case .numberKingdom: return 1
        case .logicLagoon: return 2
        case .puzzlePeaks: return 3
        case .inventorsWorkshop: return 4
        case .mysteryIsland: return 5
        }
    }
}

public enum WorldContentSource: Sendable {
    /// Powered by bundled taxonomy topics.
    case taxonomy
    /// Bundled taxonomy topics plus original WonderMath content.
    case taxonomyAndAuthored
    /// Original WonderMath content only (dataset has no suitable topics).
    case authored
}

public struct WorldDefinition: Sendable {
    public let id: WorldID
    /// Localization key for the world name.
    public let titleKey: L10n.Key
    public let subtitleKey: L10n.Key
    /// (subject, domain) pairs bundled into this world.
    public let domains: [(subject: String, domain: String)]
    public let contentSource: WorldContentSource
    /// Only World 1 ships in the vertical slice; other regions render as
    /// visibly locked, never as dead buttons.
    public let isPlayable: Bool

    public init(id: WorldID, titleKey: L10n.Key, subtitleKey: L10n.Key,
                domains: [(subject: String, domain: String)],
                contentSource: WorldContentSource, isPlayable: Bool) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.domains = domains
        self.contentSource = contentSource
        self.isPlayable = isPlayable
    }
}

public enum WorldCatalog {

    public static let worlds: [WorldDefinition] = [
        WorldDefinition(
            id: .numberKingdom,
            titleKey: .world1Title, subtitleKey: .world1Subtitle,
            domains: [
                ("Mathematics", "Counting & Cardinality"),
                ("Mathematics", "Number Representation & Place Value"),
                ("Mathematics", "Addition & Subtraction"),
                ("Mathematics", "Multiplication & Division"),
                ("Mathematics", "Fractions"),
                ("Mathematics", "Ratio & Proportion"),
                ("Mathematics", "Algebra"),
            ],
            contentSource: .taxonomy, isPlayable: true),

        // TODO(post-slice): mix Mathematical Thinking topics + Computing
        // Algorithms with authored logic puzzles; the dataset is thin here.
        WorldDefinition(
            id: .logicLagoon,
            titleKey: .world2Title, subtitleKey: .world2Subtitle,
            domains: [
                ("Mathematics", "Mathematical Thinking"),
                ("Computing", "Algorithms & Programming"),
            ],
            contentSource: .taxonomyAndAuthored, isPlayable: false),

        // TODO(post-slice): geometry/measurement puzzles; largely authored
        // interactions (build, rotate, estimate) on top of taxonomy topics.
        WorldDefinition(
            id: .puzzlePeaks,
            titleKey: .world3Title, subtitleKey: .world3Subtitle,
            domains: [
                ("Mathematics", "Geometry"),
                ("Mathematics", "Measurement"),
            ],
            contentSource: .taxonomyAndAuthored, isPlayable: false),

        WorldDefinition(
            id: .inventorsWorkshop,
            titleKey: .world4Title, subtitleKey: .world4Subtitle,
            domains: [
                ("Computing", "Designing Digital Solutions"),
                ("Computing", "Digital Systems"),
                ("Computing", "Privacy & Security"),
                ("Computing", "Digital Tools & Collaboration"),
                ("Computing", "Artificial Intelligence"),
                ("Computing", "Data Representation"),
            ],
            contentSource: .taxonomyAndAuthored, isPlayable: false),

        // TODO(post-slice): data & probability challenges + authored mystery
        // narrative; taxonomy Data & Statistics topics provide the content.
        WorldDefinition(
            id: .mysteryIsland,
            titleKey: .world5Title, subtitleKey: .world5Subtitle,
            domains: [
                ("Mathematics", "Data & Statistics"),
                ("Mathematics", "Probability"),
            ],
            contentSource: .taxonomyAndAuthored, isPlayable: false),
    ]

    public static func world(_ id: WorldID) -> WorldDefinition {
        worlds.first { $0.id == id }!
    }

    /// Topic ids that belong to a world (subset topics only).
    public static func topicIds(for world: WorldID, in store: TaxonomyStore) -> [String] {
        let def = Self.world(world)
        return store.topics
            .filter { t in def.domains.contains { $0.subject == t.subject && $0.domain == t.domain } }
            .map(\.id)
    }
}
