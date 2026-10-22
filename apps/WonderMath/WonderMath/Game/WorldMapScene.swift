import SpriteKit

final class WorldMapScene: SKScene {
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.47, green: 0.78, blue: 0.91, alpha: 1)
        layoutScenery()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil else { return }
        layoutScenery()
    }

    private func layoutScenery() {
        removeAllChildren()
        for index in 0..<6 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 120, height: 38))
            cloud.fillColor = .white.withAlphaComponent(0.62)
            cloud.strokeColor = .clear
            cloud.position = CGPoint(x: CGFloat(index) * size.width / 5 - size.width / 2,
                                     y: CGFloat(index % 2) * 80 + size.height * 0.31)
            addChild(cloud)
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: 34, y: 0, duration: 6),
                .moveBy(x: -34, y: 0, duration: 6)
            ])))
        }
        for index in 0..<5 {
            let island = SKShapeNode(ellipseOf: CGSize(width: 230, height: 76))
            island.fillColor = [SKColor(red: 0.45, green: 0.73, blue: 0.39, alpha: 1),
                                SKColor(red: 0.75, green: 0.65, blue: 0.37, alpha: 1),
                                SKColor(red: 0.65, green: 0.73, blue: 0.83, alpha: 1),
                                SKColor(red: 0.82, green: 0.58, blue: 0.35, alpha: 1),
                                SKColor(red: 0.63, green: 0.57, blue: 0.8, alpha: 1)][index]
            island.strokeColor = .white
            island.lineWidth = 4
            island.position = CGPoint(x: CGFloat(index - 2) * size.width * 0.19, y: -size.height * 0.2)
            addChild(island)
            island.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 5, duration: 1.8),
                .moveBy(x: 0, y: -5, duration: 1.8)
            ])))
        }
    }
}
