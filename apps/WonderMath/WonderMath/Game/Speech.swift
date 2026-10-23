import AVFoundation
import WonderMathCore

@MainActor
final class Speech {
    private struct VoiceSelection {
        let voice: AVSpeechSynthesisVoice?
        let isPersonal: Bool
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var voiceCache: [String: VoiceSelection] = [:]
    private var activeLanguage: String?
    private var cachedPersonalVoicePreference: Bool?
    private var voiceObserver: NSObjectProtocol?

    init() {
        voiceObserver = NotificationCenter.default.addObserver(
            forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.invalidateVoiceCache()
            }
        }
    }

    deinit {
        if let voiceObserver {
            NotificationCenter.default.removeObserver(voiceObserver)
        }
    }

    func speak(_ message: LocalizedMessage, localizer: Localizer, enabled: Bool) {
        guard enabled else { return }
        let language = languageCode(for: localizer)
        let selection = voiceSelection(for: language)
        let utterance = AVSpeechUtterance(string: localizer.string(message))
        utterance.voice = selection.voice
        if !selection.isPersonal {
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
            utterance.pitchMultiplier = 1.05
            utterance.preUtteranceDelay = 0.1
        }

        #if DEBUG
        let voiceName = selection.voice?.name ?? localizer.string(.voiceNameDefault)
        let quality = selection.voice.map { qualityName($0.quality, localizer: localizer) }
            ?? localizer.string(.voiceQualityDefault)
        print("[Speech] language=\(language) voice=\(voiceName) quality=\(quality) personal=\(selection.isPersonal)")
        #endif

        synthesizer.speak(utterance)
    }

    func hasPersonalVoice(for localizer: Localizer) -> Bool {
        personalVoice(for: languageCode(for: localizer)) != nil
    }

    func currentVoiceDescription(localizer: Localizer) -> String {
        let language = languageCode(for: localizer)
        let selection = voiceSelection(for: language)
        let name = selection.voice?.name ?? localizer.string(.voiceNameDefault)
        let quality = selection.voice.map { qualityName($0.quality, localizer: localizer) }
            ?? localizer.string(.voiceQualityDefault)
        return localizer.string(.voiceCurrentFormat, [.text(name), .text(quality)])
    }

    func invalidateVoiceCache() {
        voiceCache.removeAll()
    }

    private func voiceSelection(for language: String) -> VoiceSelection {
        let usePersonalVoice = UserDefaults.standard.bool(forKey: "usePersonalVoice")
        if cachedPersonalVoicePreference != usePersonalVoice {
            voiceCache.removeAll()
            cachedPersonalVoicePreference = usePersonalVoice
        }
        if activeLanguage != language {
            voiceCache.removeValue(forKey: language)
            activeLanguage = language
        }
        if let cached = voiceCache[language] { return cached }

        let selection = selectVoice(for: language, usePersonalVoice: usePersonalVoice)
        voiceCache[language] = selection
        return selection
    }

    private func selectVoice(for language: String, usePersonalVoice: Bool) -> VoiceSelection {
        if usePersonalVoice,
           let personalVoice = personalVoice(for: language) {
            return VoiceSelection(voice: personalVoice, isPersonal: true)
        }

        let matchingVoices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            !voice.voiceTraits.contains(.isPersonalVoice) &&
                voice.language.lowercased().hasPrefix("\(language)-")
        }
        let preferredVoices: [AVSpeechSynthesisVoice]
        if language == "de" {
            let swissVoices = matchingVoices.filter {
                $0.language.caseInsensitiveCompare("de-CH") == .orderedSame
            }
            preferredVoices = swissVoices.isEmpty ? matchingVoices : swissVoices
        } else {
            preferredVoices = matchingVoices
        }
        let bestInstalledVoice = preferredVoices.max {
            qualityRank($0.quality) < qualityRank($1.quality)
        }
        let fallbackLanguages = language == "de" ? ["de-CH", "de-DE"] : ["en-US", "en"]
        let fallbackVoice = fallbackLanguages
            .compactMap(AVSpeechSynthesisVoice.init(language:))
            .first { !$0.voiceTraits.contains(.isPersonalVoice) }

        return VoiceSelection(voice: bestInstalledVoice ?? fallbackVoice, isPersonal: false)
    }

    private func personalVoice(for language: String) -> AVSpeechSynthesisVoice? {
        guard AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .authorized else { return nil }
        return AVSpeechSynthesisVoice.speechVoices().first {
            $0.voiceTraits.contains(.isPersonalVoice) &&
                $0.language.lowercased().hasPrefix(language)
        }
    }

    private func languageCode(for localizer: Localizer) -> String {
        localizer.language == .german ? "de" : "en"
    }

    private func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }

    private func qualityName(_ quality: AVSpeechSynthesisVoiceQuality,
                             localizer: Localizer) -> String {
        switch quality {
        case .premium: return localizer.string(.voiceQualityPremium)
        case .enhanced: return localizer.string(.voiceQualityEnhanced)
        default: return localizer.string(.voiceQualityDefault)
        }
    }
}
