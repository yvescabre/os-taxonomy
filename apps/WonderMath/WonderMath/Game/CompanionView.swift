import SwiftUI

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
            Circle().fill(bodyColor).frame(width: size * 0.78, height: size * 0.78)
                .overlay(Circle().stroke(.white, lineWidth: max(2, size * 0.035)))
            switch species {
            case "owl":
                HStack(spacing: size * 0.08) {
                    eye
                    eye
                }.offset(y: size * 0.02)
            case "turtle":
                Image(systemName: "leaf.fill").font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            case "dragon":
                Image(systemName: "sparkles").font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(.white)
            default:
                Image(systemName: "hare.fill").font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            }
            if species == "fox" {
                HStack(spacing: size * 0.27) { eye; eye }.offset(y: size * 0.08)
            }
            if accessory != "none" {
                Image(systemName: accessory == "heart" ? "heart.fill" : "star.fill")
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(.yellow)
                    .offset(x: size * 0.25, y: -size * 0.25)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Circle().fill(.white).frame(width: size * 0.19, height: size * 0.19)
            .overlay(Circle().fill(Color(red: 0.16, green: 0.22, blue: 0.32))
                .frame(width: size * 0.08, height: size * 0.08))
    }
}
