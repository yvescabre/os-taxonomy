import Foundation

/// Translation layer for taxonomy content shown to children.
///
/// The dataset is English-only. Rather than leaking raw dataset strings into
/// a German UI, this table maps *playable* topic names and all domain names
/// into German. Topics without an entry fall back to English (acceptable in
/// the slice; extend the table as coverage grows). Research prose is never
/// shown to children at all — it feeds hints only through curated mechanics
/// and appears verbatim only in the Grown-Ups' Corner.
public enum TaxonomyLocalization {

    /// Human-readable name of a topic for child UI.
    public static func displayName(of topic: Topic, language: AppLanguage) -> String {
        guard language == .german else { return topic.name }
        return germanTopicNames[topic.id] ?? topic.name
    }

    /// Human-readable name of a domain, e.g. in the parent dashboard and map.
    public static func displayDomain(subject: String, domain: String, language: AppLanguage) -> String {
        guard language == .german else { return domain }
        return germanDomains[domain] ?? domain
    }

    /// German names for every playable topic in the slice.
    private static let germanTopicNames: [String: String] = [
        // World 1 — bridges (add/sub)
        "mt_s2mfRBoTal": "Zahlenfreunde bis 20",
        "mt_m1W6nTQJ2b": "Plus und Minus bis 20",
        "mt__t4afSyZRm": "Schnell rechnen bis 20",
        "mt_oIzycTBeE4": "Was das Gleichzeichen bedeutet",
        "mt_ezc2m_0dzN": "Die fehlende Zahl beim Plus",
        "mt_ehGS_uVSJv": "Umkehraufgaben: Plus und Minus",
        "mt_3JgrHY221M": "Lücken in Plus- und Minusaufgaben",
        "mt_glPPG-kTQY": "Plusrechnen bis 100",
        "mt_cChv2j_-Da": "Schnell rechnen bis 100",
        "mt_ewmuMMPAzP": "Plus und Minus bis 1000",
        "mt_XuHmIn2xje": "Zahlenrätsel mit Lücken",
        // World 1 — bridges (mult/div)
        "mt_HhuSDxwDNM": "Einmaleins mit 2, 5 und 10",
        "mt_wQ89AEXhz3": "Einmaleins mit 3, 4 und 8",
        "mt_K5jM7vlVhA": "Das ganze Einmaleins",
        "mt_WX30dzi4dt": "Schnelles Malnehmen und Teilen",
        "mt_C9ZfT-4cgn": "Malnehmen in jeder Reihenfolge",
        "mt_GDG9_SZmsO": "Teilen als verstecktes Malnehmen",
        "mt_xZvDCYA5Ae": "Lücken im Einmaleins",
        "mt_VUQNveSYjQ": "Mit Umkehraufgaben prüfen",
        // World 1 — stepping stones (patterns)
        "mt_nvdpxAJTBG": "In Zweierschritten zählen",
        "mt_IzQvs7k_sE": "Sprungzählen (4er, 8er, 50er, 100er)",
        "mt_tAtMET4EIU": "Vorwärts und rückwärts zählen",
        "mt_W3VOAuFwVw": "Wachsende Zahlenmuster",
        "mt_hBZwbst0ow": "Zahlenfolgen mit Regel",
    ]

    /// All 12 Mathematics + 7 Computing domain names.
    private static let germanDomains: [String: String] = [
        "Counting & Cardinality": "Zählen und Anzahlen",
        "Number Representation & Place Value": "Zahldarstellung und Stellenwert",
        "Addition & Subtraction": "Addition und Subtraktion",
        "Multiplication & Division": "Multiplikation und Division",
        "Fractions": "Brüche",
        "Ratio & Proportion": "Verhältnisse und Proportionen",
        "Algebra": "Algebra",
        "Mathematical Thinking": "Mathematisches Denken",
        "Geometry": "Geometrie",
        "Measurement": "Messen",
        "Data & Statistics": "Daten und Statistik",
        "Probability": "Wahrscheinlichkeit",
        "Algorithms & Programming": "Algorithmen und Programmieren",
        "Designing Digital Solutions": "Digitale Lösungen gestalten",
        "Digital Systems": "Digitale Systeme",
        "Privacy & Security": "Privatsphäre und Sicherheit",
        "Digital Tools & Collaboration": "Digitale Werkzeuge und Zusammenarbeit",
        "Artificial Intelligence": "Künstliche Intelligenz",
        "Data Representation": "Datendarstellung",
    ]
}
