import AVFoundation
import WonderMathCore

@MainActor
final class Speech {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ message: LocalizedMessage, localizer: Localizer, enabled: Bool) {
        guard enabled else { return }
        let utterance = AVSpeechUtterance(string: localizer.string(message))
        utterance.voice = AVSpeechSynthesisVoice(language: localizer.language == .german ? "de-CH" : "en-US")
            ?? AVSpeechSynthesisVoice(language: localizer.language == .german ? "de-DE" : "en")
        synthesizer.speak(utterance)
    }
}
