import SpriteKit
import UIKit

final class WorldMapScene: SKScene {
    var reduceMotion = false

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        layoutScenery()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil else { return }
        layoutScenery()
    }

    func updateMotionSetting(_ reduceMotion: Bool) {
        guard self.reduceMotion != reduceMotion else { return }
        self.reduceMotion = reduceMotion
        layoutScenery()
    }

    private func layoutScenery() {
        guard size.width > 0, size.height > 0 else { return }
        removeAllChildren()

        let sky = SKSpriteNode(texture: gradientTexture(size: size, colors: [
            SKColor(red: 0.42, green: 0.78, blue: 1, alpha: 1),
            SKColor(red: 0.75, green: 0.92, blue: 1, alpha: 1),
            SKColor(red: 0.91, green: 0.98, blue: 1, alpha: 1)
        ]), size: size)
        sky.zPosition = -10
        addChild(sky)

        let halo = SKShapeNode(circleOfRadius: size.height * 0.095)
        halo.position = CGPoint(x: size.width * 0.25, y: size.height * 0.27)
        halo.fillColor = SKColor(red: 1, green: 0.79, blue: 0.35, alpha: 0.25)
        halo.strokeColor = .clear
        addChild(halo)
        let sun = SKShapeNode(circleOfRadius: size.height * 0.052)
        sun.position = halo.position
        sun.fillColor = SKColor(red: 1, green: 0.76, blue: 0.22, alpha: 1)
        sun.strokeColor = .clear
        addChild(sun)

        for index in 0..<5 {
            addCloud(at: CGPoint(x: CGFloat(index) * size.width / 4 - size.width / 2,
                                 y: size.height * (0.28 + CGFloat(index % 2) * 0.12)),
                     scale: index.isMultiple(of: 2) ? 1 : 0.76,
                     drift: index.isMultiple(of: 2) ? 52 : -42)
        }

        let sea = SKSpriteNode(texture: gradientTexture(size: size,
                                                       colors: [SKColor(red: 0.35, green: 0.80, blue: 0.90, alpha: 1),
                                                                SKColor(red: 0.12, green: 0.50, blue: 0.69, alpha: 1)],
                                                       clip: seaPath(size: size)), size: size)
        sea.zPosition = -2
        addChild(sea)
        addWaves()
        addJourneyPath()
    }

    private func addCloud(at point: CGPoint, scale: CGFloat, drift: CGFloat) {
        let cloud = SKNode()
        cloud.position = point
        cloud.xScale = scale
        cloud.yScale = scale
        let color = SKColor.white.withAlphaComponent(0.70)
        let puffs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-30, 0, 94, 32), (-5, 12, 58, 42), (24, 3, 72, 34), (50, -1, 48, 26)
        ]
        for (x, y, width, height) in puffs {
            let puff = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
            puff.position = CGPoint(x: x, y: y)
            puff.fillColor = color
            puff.strokeColor = .clear
            cloud.addChild(puff)
        }
        addChild(cloud)
        if !reduceMotion {
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: drift, y: 0, duration: 12),
                .moveBy(x: -drift, y: 0, duration: 12)
            ])))
        }
    }

    private func addWaves() {
        for index in 0..<3 {
            let path = CGMutablePath()
            let baseY = -size.height * (0.22 + CGFloat(index) * 0.10)
            path.move(to: CGPoint(x: -size.width * 0.6, y: baseY))
            for segment in 0..<12 {
                let x = -size.width * 0.6 + CGFloat(segment) * size.width * 0.2
                path.addCurve(to: CGPoint(x: x + size.width * 0.2, y: baseY),
                              control1: CGPoint(x: x + size.width * 0.06, y: baseY + 8),
                              control2: CGPoint(x: x + size.width * 0.14, y: baseY - 8))
            }
            let wave = SKShapeNode(path: path)
            wave.strokeColor = SKColor.white.withAlphaComponent(index == 0 ? 0.35 : 0.22)
            wave.lineWidth = 3
            wave.zPosition = -1
            addChild(wave)
            if !reduceMotion {
                wave.run(.repeatForever(.sequence([
                    .moveBy(x: -120, y: 0, duration: 7),
                    .moveBy(x: 120, y: 0, duration: 7)
                ])))
            }
        }
    }

    private func addJourneyPath() {
        let fractions: [(CGFloat, CGFloat)] = [(0.18, 0.70), (0.43, 0.54), (0.82, 0.47),
                                               (0.64, 0.70), (0.82, 0.82)]
        let points = fractions.map {
            CGPoint(x: -size.width / 2 + size.width * $0.0,
                    y: size.height / 2 - size.height * $0.1)
        }
        let path = CGMutablePath()
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() {
            let previous = path.currentPoint
            let midpoint = (previous.x + point.x) / 2
            path.addCurve(to: point,
                          control1: CGPoint(x: midpoint, y: previous.y),
                          control2: CGPoint(x: midpoint, y: point.y))
        }
        let dashedPath = path.copy(dashingWithPhase: 0, lengths: [2, 16], transform: .identity)
        let trail = SKShapeNode(path: dashedPath)
        trail.strokeColor = SKColor.white.withAlphaComponent(0.68)
        trail.lineWidth = 5
        trail.lineCap = .round
        trail.zPosition = -1
        addChild(trail)
    }

    private func seaPath(size: CGSize) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height * 0.40))
        path.addCurve(to: CGPoint(x: size.width * 0.5, y: size.height * 0.38),
                      control1: CGPoint(x: size.width * 0.18, y: size.height * 0.33),
                      control2: CGPoint(x: size.width * 0.32, y: size.height * 0.45))
        path.addCurve(to: CGPoint(x: size.width, y: size.height * 0.39),
                      control1: CGPoint(x: size.width * 0.68, y: size.height * 0.31),
                      control2: CGPoint(x: size.width * 0.84, y: size.height * 0.44))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func gradientTexture(size: CGSize, colors: [SKColor], clip: CGPath? = nil) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            if let clip {
                cgContext.addPath(clip)
                cgContext.clip()
            }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let cgColors = colors.map(\.cgColor) as CFArray
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil) else {
                return
            }
            cgContext.drawLinearGradient(gradient,
                                        start: CGPoint(x: 0, y: 0),
                                        end: CGPoint(x: 0, y: size.height),
                                        options: [])
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}
