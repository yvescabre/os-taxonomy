import Foundation
import XCTest
@testable import WonderMathCore

final class VoiceClipTests: XCTestCase {
    private struct VoiceManifest: Decodable {
        let clips: [VoiceClip]
    }

    private struct VoiceClip: Decodable {
        let key: String
        let language: String
        let text: String
        let file: String
        let durationSeconds: Double
    }

    private let languages: [(code: String, language: AppLanguage)] = [
        ("en", .english),
        ("de", .german)
    ]

    func testPrerecordedLinesAreArgumentFreeInEveryLanguage() {
        for key in SpokenLines.prerecorded {
            for (_, language) in languages {
                let text = Localizer(language: language).string(LocalizedMessage(key))
                XCTAssertFalse(text.contains("{"), "\(key) has a placeholder in \(language.rawValue)")
            }
        }
    }

    func testEveryFixedSpokenHintAndFeedbackKeyIsCovered() throws {
        let store = try TestSupport.loadStore()
        var generators: [any PuzzleGenerator] = BridgeLibrary.all.map { $0 as any PuzzleGenerator }
        generators.append(contentsOf: PatternPathLibrary.all.map { $0 as any PuzzleGenerator })

        for generator in generators {
            for difficulty in 1...5 {
                for sequence in 0..<24 {
                    let puzzle = generator.makePuzzle(
                        sequence: sequence,
                        difficulty: difficulty,
                        store: store
                    )
                    for hint in puzzle.hints where hint.message.args.isEmpty {
                        XCTAssertTrue(
                            SpokenLines.prerecorded.contains(hint.message.key),
                            "\(puzzle.id) has an unbundled fixed hint: \(hint.message.key)"
                        )
                    }
                }
            }
        }

        for kind in MisconceptionKind.allCases {
            XCTAssertTrue(SpokenLines.prerecorded.contains(kind.feedbackKey), "\(kind.feedbackKey)")
        }
        let requiredKeys: [L10n.Key] = [
            .feedbackCorrect, .feedbackGenericWrong, .bridgeInstructions, .sequenceInstructions
        ]
        for key in requiredKeys {
            XCTAssertTrue(SpokenLines.prerecorded.contains(key), "\(key)")
        }
    }

    func testBundledManifestMatchesCurrentLocalizedLines() throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WonderMath/Resources/Voice")
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let manifest = try JSONDecoder().decode(VoiceManifest.self, from: Data(contentsOf: manifestURL))

        XCTAssertEqual(manifest.clips.count, SpokenLines.prerecorded.count * languages.count)
        for key in SpokenLines.prerecorded {
            for (code, language) in languages {
                let matches = manifest.clips.filter { $0.key == key.rawValue && $0.language == code }
                XCTAssertEqual(matches.count, 1, "expected one \(code) clip for \(key)")
                guard let clip = matches.first else { continue }

                XCTAssertEqual(clip.text, Localizer(language: language).string(LocalizedMessage(key)))
                XCTAssertGreaterThan(clip.durationSeconds, 0)
                let fileURL = clip.file
                    .split(separator: "/")
                    .reduce(directory) { current, component in
                        current.appendingPathComponent(String(component))
                    }
                XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), fileURL.path)
                let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                XCTAssertGreaterThan(size, 0, fileURL.path)
            }
        }
    }
}
