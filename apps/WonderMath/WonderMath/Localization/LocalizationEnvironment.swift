import SwiftUI
import WonderMathCore

private struct LocalizerEnvironmentKey: EnvironmentKey {
    static let defaultValue = Localizer()
}

extension EnvironmentValues {
    var localizer: Localizer {
        get { self[LocalizerEnvironmentKey.self] }
        set { self[LocalizerEnvironmentKey.self] = newValue }
    }
}

func L(_ key: L10n.Key) -> LocalizedMessage {
    LocalizedMessage(key)
}

extension Text {
    init(localized message: LocalizedMessage, localizer: Localizer) {
        self.init(localizer.string(message))
    }

    init(localized key: L10n.Key, localizer: Localizer) {
        self.init(localizer.string(key))
    }
}
