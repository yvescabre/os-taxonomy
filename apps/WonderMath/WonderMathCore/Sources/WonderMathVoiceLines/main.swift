import Foundation
import WonderMathCore

private struct SpokenLine: Encodable {
    let key: String
    let language: String
    let text: String
}

let languages: [(code: String, appLanguage: AppLanguage)] = [
    ("en", .english),
    ("de", .german)
]

private let lines = SpokenLines.prerecorded
    .flatMap { key in
        languages.map { language in
            SpokenLine(
                key: key.rawValue,
                language: language.code,
                text: Localizer(language: language.appLanguage).string(LocalizedMessage(key))
            )
        }
    }
    .sorted {
        if $0.key != $1.key { return $0.key < $1.key }
        return $0.language < $1.language
    }

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let data = try encoder.encode(lines)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([0x0A]))
