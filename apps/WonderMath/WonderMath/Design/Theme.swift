import SwiftUI

enum Theme {
    static let ink = Color(red: 34 / 255, green: 49 / 255, blue: 77 / 255)
    static let inkSoft = Color(red: 91 / 255, green: 107 / 255, blue: 134 / 255)
    static let cream = Color(red: 1, green: 248 / 255, blue: 236 / 255)
    static let paper = Color(red: 1, green: 253 / 255, blue: 247 / 255)
    static let sun = Color(red: 1, green: 182 / 255, blue: 39 / 255)
    static let sunLight = Color(red: 1, green: 201 / 255, blue: 77 / 255)
    static let sunDark = Color(red: 224 / 255, green: 142 / 255, blue: 0)
    static let sunInk = Color(red: 90 / 255, green: 55 / 255, blue: 0)
    static let leaf = Color(red: 92 / 255, green: 191 / 255, blue: 107 / 255)
    static let leafLight = Color(red: 120 / 255, green: 212 / 255, blue: 134 / 255)
    static let leafDark = Color(red: 59 / 255, green: 154 / 255, blue: 76 / 255)
    static let coral = Color(red: 1, green: 122 / 255, blue: 89 / 255)
    static let coralDark = Color(red: 217 / 255, green: 83 / 255, blue: 47 / 255)
    static let violet = Color(red: 139 / 255, green: 108 / 255, blue: 240 / 255)
    static let violetDark = Color(red: 100 / 255, green: 73 / 255, blue: 204 / 255)
    static let teal = Color(red: 43 / 255, green: 179 / 255, blue: 163 / 255)
    static let sky = Color(red: 108 / 255, green: 200 / 255, blue: 1)
    static let skyPale = Color(red: 232 / 255, green: 249 / 255, blue: 1)
    static let water = Color(red: 88 / 255, green: 205 / 255, blue: 230 / 255)
    static let waterDeep = Color(red: 31 / 255, green: 127 / 255, blue: 176 / 255)
    static let wood = Color(red: 192 / 255, green: 122 / 255, blue: 66 / 255)
    static let woodLight = Color(red: 227 / 255, green: 168 / 255, blue: 107 / 255)
    static let woodDark = Color(red: 138 / 255, green: 79 / 255, blue: 37 / 255)
    static let sand = Color(red: 243 / 255, green: 220 / 255, blue: 170 / 255)
    static let warmFeedback = Color(red: 1, green: 243 / 255, blue: 223 / 255)
    static let hintFeedback = Color(red: 238 / 255, green: 247 / 255, blue: 1)
    static let parentBackground = Color(red: 244 / 255, green: 246 / 255, blue: 250 / 255)

    static func roundedFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let sunGradient = LinearGradient(
        colors: [sunLight, sun],
        startPoint: .top,
        endPoint: .bottom
    )
    static let leafGradient = LinearGradient(
        colors: [leafLight, leaf],
        startPoint: .top,
        endPoint: .bottom
    )
    static let woodGradient = LinearGradient(
        colors: [woodLight, wood, woodDark],
        startPoint: .top,
        endPoint: .bottom
    )
    static let skyGradient = LinearGradient(
        colors: [sky, Color(red: 191 / 255, green: 234 / 255, blue: 1), skyPale],
        startPoint: .top,
        endPoint: .bottom
    )
    static let waterGradient = LinearGradient(
        colors: [water, waterDeep],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct ChunkyButtonStyle: ButtonStyle {
    let fill: LinearGradient
    let shadow: Color
    let foreground: Color
    let border: Color?
    let ledgeOpacity: Double
    let ledgeOffset: CGFloat

    init(fill: LinearGradient, shadow: Color, foreground: Color,
         border: Color? = nil, ledgeOpacity: Double = 1, ledgeOffset: CGFloat = 7) {
        self.fill = fill
        self.shadow = shadow
        self.foreground = foreground
        self.border = border
        self.ledgeOpacity = ledgeOpacity
        self.ledgeOffset = ledgeOffset
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.roundedFont(22, weight: .heavy))
            .foregroundStyle(foreground)
            .frame(minHeight: 64)
            .padding(.horizontal, 22)
            .background(fill, in: RoundedRectangle(cornerRadius: 22))
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(shadow.opacity(ledgeOpacity))
                    .frame(height: configuration.isPressed ? 3 : ledgeOffset)
                    .offset(y: configuration.isPressed ? 2 : ledgeOffset)
            }
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(border, lineWidth: 2)
                }
            }
            .shadow(color: shadow.opacity(0.28),
                    radius: configuration.isPressed ? 4 : 11,
                    x: 0, y: configuration.isPressed ? 3 : 10)
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var sun: ChunkyButtonStyle {
        ChunkyButtonStyle(fill: Theme.sunGradient, shadow: Theme.sunDark, foreground: Theme.sunInk)
    }

    static var leaf: ChunkyButtonStyle {
        ChunkyButtonStyle(fill: Theme.leafGradient, shadow: Theme.leafDark, foreground: .white)
    }

    static var ghost: ChunkyButtonStyle {
        ChunkyButtonStyle(
            fill: LinearGradient(colors: [Color(red: 227 / 255, green: 244 / 255, blue: 1)],
                                 startPoint: .top, endPoint: .bottom),
            shadow: Theme.waterDeep,
            foreground: Theme.ink,
            border: Theme.sky,
            ledgeOpacity: 0.35,
            ledgeOffset: 4
        )
    }
}

extension View {
    func chip() -> some View {
        font(Theme.roundedFont(20, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.white.opacity(0.92), in: Capsule())
            .shadow(color: Theme.ink.opacity(0.12), radius: 12, x: 0, y: 7)
    }
}
