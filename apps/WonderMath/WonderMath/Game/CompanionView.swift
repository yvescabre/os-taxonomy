import SwiftUI
import UIKit

struct CompanionView: View {
    let species: String
    let colorName: String
    var accessory: String = "none"
    var size: CGFloat = 66

    private var bodyColor: Color {
        switch colorName {
        case "blue": return Color(red: 0.28, green: 0.56, blue: 0.88)
        case "green": return Color(red: 0.25, green: 0.66, blue: 0.48)
        case "violet": return Color(red: 0.57, green: 0.4, blue: 0.78)
        case "pink": return Color(red: 0.91, green: 0.46, blue: 0.63)
        default: return Color(red: 0.96, green: 0.56, blue: 0.24)
        }
    }

    var body: some View {
        ZStack {
            if species == "fox" { tail }
            if species == "dragon" { dragonWings }

            Ellipse().fill(bodyColor)
                .frame(width: size * 0.58, height: size * 0.44)
                .overlay(Ellipse().stroke(.white.opacity(0.9), lineWidth: max(1.5, size * 0.025)))
                .offset(y: size * 0.26)
            Ellipse().fill(cream)
                .frame(width: size * 0.30, height: size * 0.29)
                .offset(y: size * 0.29)

            if species == "turtle" { shell }
            if species == "fox" || species == "owl" { ears }
            if species == "dragon" { hornsAndSpikes }

            Circle().fill(bodyColor)
                .frame(width: size * 0.68, height: size * 0.68)
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: max(2, size * 0.03)))
                .offset(y: -size * 0.10)
            FaceMask().fill(cream)
                .frame(width: size * 0.58, height: size * 0.30)
                .offset(y: size * 0.03)
            HStack(spacing: size * 0.20) { eye; eye }
                .offset(y: -size * 0.12)
            HStack(spacing: size * 0.43) {
                cheek
                cheek
            }
            .offset(y: size * 0.08)
            Ellipse().fill(Theme.ink)
                .frame(width: size * 0.10, height: size * 0.07)
                .offset(y: size * 0.13)
            Smile()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: max(1.8, size * 0.035), lineCap: .round))
                .frame(width: size * 0.15, height: size * 0.08)
                .offset(y: size * 0.20)

            if species == "owl" {
                Triangle().fill(Theme.sun)
                    .frame(width: size * 0.14, height: size * 0.13)
                    .offset(y: size * 0.11)
            }
            if accessory != "none" {
                Image(systemName: accessory == "heart" ? "heart.fill" : "star.fill")
                    .font(.system(size: size * 0.20, weight: .heavy))
                    .foregroundStyle(Theme.sun)
                    .padding(size * 0.035)
                    .background(.white, in: Circle())
                    .overlay(Circle().stroke(Theme.sun.opacity(0.55), lineWidth: 1.5))
                    .offset(x: size * 0.31, y: -size * 0.34)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @MainActor
    func renderedImage(size imageSize: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: self.frame(width: imageSize.width, height: imageSize.height))
        renderer.scale = 2
        return renderer.uiImage
    }

    private var cream: Color { Color(red: 1, green: 0.96, blue: 0.89) }

    private var cheek: some View {
        Circle().fill(Color(red: 1, green: 0.42, blue: 0.54).opacity(0.48))
            .frame(width: size * 0.10, height: size * 0.10)
    }

    private var eye: some View {
        Circle().fill(Theme.ink)
            .frame(width: size * 0.105, height: size * 0.14)
            .overlay(alignment: .topTrailing) {
                Circle().fill(.white)
                    .frame(width: size * 0.045, height: size * 0.045)
                    .offset(x: -size * 0.012, y: size * 0.022)
            }
    }

    private var tail: some View {
        ZStack {
            TailShape().fill(bodyColor)
            TailTip().fill(cream)
        }
        .frame(width: size * 0.38, height: size * 0.29)
        .rotationEffect(.degrees(-15))
        .offset(x: size * 0.32, y: size * 0.23)
    }

    private var ears: some View {
        HStack(spacing: size * 0.18) {
            EarShape().fill(bodyColor).overlay(EarInsetShape().fill(Theme.woodDark))
            EarShape().fill(bodyColor).overlay(EarInsetShape().fill(Theme.woodDark))
        }
        .frame(width: size * 0.74, height: size * 0.43)
        .offset(y: -size * 0.32)
    }

    private var shell: some View {
        ZStack {
            ShellShape().fill(bodyColor.opacity(0.88))
                .overlay(ShellShape().stroke(Theme.woodDark.opacity(0.7), lineWidth: max(1.5, size * 0.025)))
            ShellPattern().stroke(Theme.woodDark.opacity(0.58),
                                  style: StrokeStyle(lineWidth: max(1, size * 0.018), lineCap: .round))
        }
        .frame(width: size * 0.51, height: size * 0.32)
        .offset(y: size * 0.28)
    }

    private var dragonWings: some View {
        HStack(spacing: size * 0.40) {
            WingShape().fill(bodyColor.opacity(0.82))
            WingShape().fill(bodyColor.opacity(0.82)).scaleEffect(x: -1, y: 1)
        }
        .frame(width: size * 0.88, height: size * 0.34)
        .offset(y: size * 0.10)
    }

    private var hornsAndSpikes: some View {
        ZStack {
            HStack(spacing: size * 0.42) {
                HornShape().fill(cream)
                HornShape().fill(cream).scaleEffect(x: -1, y: 1)
            }
            .frame(width: size * 0.46, height: size * 0.26)
            .offset(y: -size * 0.37)
            HStack(spacing: size * 0.025) {
                ForEach(0..<4) { _ in
                    Triangle().fill(Theme.coral).frame(width: size * 0.11, height: size * 0.13)
                }
            }
            .rotationEffect(.degrees(90))
            .offset(x: -size * 0.35, y: size * 0.15)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct FaceMask: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.16))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                              control: CGPoint(x: rect.width * 0.24, y: rect.maxY * 1.12))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.16),
                              control: CGPoint(x: rect.width * 0.76, y: rect.maxY * 1.12))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.16),
                              control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.70))
            path.closeSubpath()
        }
    }
}

private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                              control: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.75))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control1: CGPoint(x: rect.width * 0.35, y: rect.minY),
                          control2: CGPoint(x: rect.width * 0.75, y: rect.height * 0.15))
            path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.75),
                          control1: CGPoint(x: rect.width * 0.85, y: rect.height * 0.9),
                          control2: CGPoint(x: rect.width * 0.35, y: rect.height * 0.58))
            path.closeSubpath()
        }
    }
}

private struct TailTip: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.73, y: rect.height * 0.25))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control1: CGPoint(x: rect.width * 0.88, y: rect.height * 0.06),
                          control2: CGPoint(x: rect.maxX, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.47),
                          control1: CGPoint(x: rect.width * 0.93, y: rect.height * 0.24),
                          control2: CGPoint(x: rect.width * 0.86, y: rect.height * 0.42))
            path.closeSubpath()
        }
    }
}

private struct EarShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.80))
            path.closeSubpath()
        }
    }
}

private struct EarInsetShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.75))
            path.addLine(to: CGPoint(x: rect.width * 0.48, y: rect.height * 0.26))
            path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.76))
            path.closeSubpath()
        }
    }
}

private struct ShellShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                          control1: CGPoint(x: rect.width * 0.05, y: rect.minY),
                          control2: CGPoint(x: rect.width * 0.95, y: rect.minY))
            path.closeSubpath()
        }
    }
}

private struct ShellPattern: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.23))
            path.addLine(to: CGPoint(x: rect.width * 0.40, y: rect.height * 0.56))
            path.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.86))
            path.move(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.23))
            path.addLine(to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.56))
            path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.86))
        }
    }
}

private struct WingShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18),
                          control1: CGPoint(x: rect.width * 0.22, y: rect.minY),
                          control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.08))
            path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                          control1: CGPoint(x: rect.width * 0.70, y: rect.height * 0.92),
                          control2: CGPoint(x: rect.width * 0.24, y: rect.height * 0.60))
            path.closeSubpath()
        }
    }
}

private struct HornShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                              control: CGPoint(x: rect.width * 0.35, y: rect.minY))
            path.closeSubpath()
        }
    }
}
