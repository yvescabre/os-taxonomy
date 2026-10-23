import Foundation
import WonderMathCore

@MainActor
final class VoiceClips {
    private struct Manifest: Decodable {
        let clips: [Clip]
    }

    private struct Clip: Decodable {
        let key: String
        let language: String
        let text: String
        let file: String
    }

    private struct ClipKey: Hashable {
        let key: String
        let language: String
    }

    private let directoryURL: URL?
    private let clips: [ClipKey: Clip]

    init(bundle: Bundle = .main) {
        guard let manifestURL = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "Voice"
        ),
        let data = try? Data(contentsOf: manifestURL),
        let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            directoryURL = nil
            clips = [:]
            return
        }

        var indexedClips: [ClipKey: Clip] = [:]
        for clip in manifest.clips {
            indexedClips[ClipKey(key: clip.key, language: clip.language)] = clip
        }
        directoryURL = manifestURL.deletingLastPathComponent()
        clips = indexedClips
    }

    func url(for message: LocalizedMessage, language: String, text: String) -> URL? {
        guard message.args.isEmpty,
              let directoryURL,
              let clip = clips[ClipKey(key: message.key.rawValue, language: language)],
              clip.text == text else {
            return nil
        }
        let url = clip.file
            .split(separator: "/")
            .reduce(directoryURL) { current, component in
                current.appendingPathComponent(String(component))
            }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
