import SpriteKit
import UIKit
import WonderMathCore

final class BridgeScene: SKScene {
    private var gapNodes: [SKShapeNode] = []
    private var nextGapIndex = 0
    private var companionNode: SKSpriteNode?
    private var companionTexture: SKTexture?
    private var isSequence = false
    var reduceMotion = false

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    func configureCompanion(texture: SKTexture?) {
        companionTexture = texture
    }

    func configure(tokens: [BridgeToken]) {
        resetScene(sequence: false)
        let spacing = min(158, (size.width - 150) / CGFloat(max(tokens.count, 1)))
        for (index, token) in tokens.enumerated() {
            let x = CGFloat(index) * spacing - CGFloat(tokens.count - 1) * spacing / 2
            let point = CGPoint(x: x, y: -size.height * 0.05)
            switch token {
            case .number(let value):
                addPlank(text: "\(value)", at: point, width: spacing - 8)
            case .operation(let operation):
                addOperator(operation.symbol, at: point)
            case .equals:
                addOperator("=", at: point)
            case .gap:
                addGap(at: point, width: spacing - 8, height: 66)
            }
        }
        addCompanion(at: CGPoint(x: -size.width * 0.39, y: -size.height * 0.10))
    }

    func configure(sequence terms: [Int?]) {
        resetScene(sequence: true)
        let spacing = min(145, (size.width - 150) / CGFloat(max(terms.count, 1)))
        for (index, term) in terms.enumerated() {
            let x = CGFloat(index) * spacing - CGFloat(terms.count - 1) * spacing / 2
            let stone = SKShapeNode(ellipseOf: CGSize(width: 88, height: 62))
            stone.position = CGPoint(x: x, y: -size.height * 0.05)
            stone.fillColor = term == nil ? .clear : SKColor(red: 0.52, green: 0.67, blue: 0.49, alpha: 1)
            stone.strokeColor = .white
            stone.lineWidth = 4
            addChild(stone)
            if let term {
                addLabel("\(term)", to: stone, size: 24)
            } else {
                gapNodes.append(stone)
                styleGap(stone)
            }
        }
        addCompanion(at: CGPoint(x: -size.width * 0.39, y: -size.height * 0.10))
    }

    func fill(gapWith value: Int) {
        guard !gapNodes.isEmpty else { return }
        let node = gapNodes[min(nextGapIndex, gapNodes.count - 1)]
        nextGapIndex = min(nextGapIndex + 1, gapNodes.count)
        node.removeAllChildren()
        node.fillColor = isSequence ? SKColor(red: 0.52, green: 0.67, blue: 0.49, alpha: 1) :
            SKColor(red: 0.75, green: 0.44, blue: 0.22, alpha: 1)
        node.strokeColor = isSequence ? .white : SKColor(red: 0.40, green: 0.23, blue: 0.13, alpha: 1)
        let label = shadowedLabel("\(value)", size: isSequence ? 24 : 27)
        node.addChild(label)
    }

    func clearGap() {
        for node in gapNodes {
            node.removeAllChildren()
            node.fillColor = .clear
            styleGap(node)
            addQuestionMark(to: node)
        }
        nextGapIndex = 0
    }

    func celebrate() {
        if let companionNode {
            companionNode.run(.moveBy(x: size.width * 0.72, y: 0, duration: reduceMotion ? 0.2 : 0.8))
        }
        let colors: [SKColor] = [.systemYellow, .systemPink, .systemTeal, .systemOrange, .systemPurple]
        for _ in 0..<60 {
            let confetti = SKShapeNode(rectOf: CGSize(width: 9, height: 13), cornerRadius: 2)
            confetti.fillColor = colors.randomElement() ?? .systemYellow
            confetti.strokeColor = .clear
            confetti.position = CGPoint(x: CGFloat.random(in: -size.width * 0.48...size.width * 0.48),
                                        y: CGFloat.random(in: 0...size.height * 0.48))
            addChild(confetti)
            let fall = SKAction.group([
                .moveBy(x: CGFloat.random(in: -50...50), y: -size.height * 0.75, duration: 1.6),
                .rotate(byAngle: .pi * 4, duration: 1.6),
                .fadeOut(withDuration: 1.6)
            ])
            confetti.run(.sequence([fall, .removeFromParent()]))
        }
    }

    func wobble() {
        guard let gapNode = gapNodes.last else { return }
        gapNode.run(.sequence([
            .moveBy(x: -8, y: 0, duration: 0.08),
            .moveBy(x: 16, y: 0, duration: 0.16),
            .moveBy(x: -8, y: 0, duration: 0.08)
        ]))
    }

    private func resetScene(sequence: Bool) {
        removeAllChildren()
        gapNodes.removeAll()
        nextGapIndex = 0
        isSequence = sequence
        drawLandscape()
    }

    private func drawLandscape() {
        addChild(SKSpriteNode(texture: gradientTexture(size: size,
            colors: [.init(red: 0.42, green: 0.78, blue: 1, alpha: 1),
                     .init(red: 0.91, green: 0.98, blue: 1, alpha: 1)]), size: size))
        let sun = SKShapeNode(circleOfRadius: size.height * 0.08)
        sun.position = CGPoint(x: size.width * 0.34, y: size.height * 0.29)
        sun.fillColor = SKColor(red: 1, green: 0.78, blue: 0.24, alpha: 1)
        sun.strokeColor = .clear
        addChild(sun)
        for (index, color) in [SKColor(red: 0.65, green: 0.85, blue: 0.52, alpha: 1),
                               SKColor(red: 0.48, green: 0.76, blue: 0.43, alpha: 1)].enumerated() {
            let hill = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.25,
                                                     height: size.height * (0.55 - CGFloat(index) * 0.06)))
            hill.position = CGPoint(x: index == 0 ? -size.width * 0.12 : size.width * 0.12,
                                    y: size.height * (0.17 - CGFloat(index) * 0.08))
            hill.fillColor = color
            hill.strokeColor = .clear
            addChild(hill)
        }
        let waterPath = CGMutablePath()
        waterPath.move(to: CGPoint(x: -size.width / 2, y: -size.height * 0.16))
        waterPath.addLine(to: CGPoint(x: size.width / 2, y: -size.height * 0.16))
        waterPath.addLine(to: CGPoint(x: size.width / 2, y: -size.height / 2))
        waterPath.addLine(to: CGPoint(x: -size.width / 2, y: -size.height / 2))
        waterPath.closeSubpath()
        let water = SKShapeNode(path: waterPath)
        water.fillColor = SKColor(red: 0.20, green: 0.65, blue: 0.81, alpha: 1)
        water.strokeColor = .clear
        addChild(water)
        for side in [-1, 1] {
            let cliff = SKShapeNode(rectOf: CGSize(width: size.width * 0.24, height: size.height * 0.47),
                                    cornerRadius: 16)
            cliff.position = CGPoint(x: CGFloat(side) * size.width * 0.39, y: -size.height * 0.22)
            cliff.fillColor = SKColor(red: 0.66, green: 0.40, blue: 0.23, alpha: 1)
            cliff.strokeColor = .clear
            addChild(cliff)
            let grass = SKShapeNode(rectOf: CGSize(width: size.width * 0.24, height: 18), cornerRadius: 9)
            grass.position = CGPoint(x: cliff.position.x, y: -size.height * 0.02)
            grass.fillColor = SKColor(red: 0.37, green: 0.72, blue: 0.38, alpha: 1)
            grass.strokeColor = .clear
            addChild(grass)
            let post = SKShapeNode(rectOf: CGSize(width: 14, height: 75), cornerRadius: 7)
            post.position = CGPoint(x: CGFloat(side) * size.width * 0.37, y: size.height * 0.04)
            post.fillColor = SKColor(red: 0.44, green: 0.26, blue: 0.15, alpha: 1)
            post.strokeColor = .clear
            addChild(post)
        }
        let ropePath = CGMutablePath()
        ropePath.move(to: CGPoint(x: -size.width * 0.37, y: size.height * 0.06))
        ropePath.addQuadCurve(to: CGPoint(x: size.width * 0.37, y: size.height * 0.06),
                              control: CGPoint(x: 0, y: -size.height * 0.03))
        let rope = SKShapeNode(path: ropePath)
        rope.strokeColor = SKColor(red: 0.48, green: 0.27, blue: 0.14, alpha: 1)
        rope.lineWidth = 6
        addChild(rope)
        for row in 0..<2 {
            let wavePath = CGMutablePath()
            let y = -size.height * (0.23 + CGFloat(row) * 0.10)
            wavePath.move(to: CGPoint(x: -size.width * 0.5, y: y))
            wavePath.addCurve(to: CGPoint(x: size.width * 0.5, y: y),
                              control1: CGPoint(x: -size.width * 0.16, y: y + 12),
                              control2: CGPoint(x: size.width * 0.16, y: y - 12))
            let wave = SKShapeNode(path: wavePath)
            wave.strokeColor = .white.withAlphaComponent(0.42)
            wave.lineWidth = 4
            addChild(wave)
            if !reduceMotion {
                wave.run(.repeatForever(.sequence([.moveBy(x: -100, y: 0, duration: 6),
                                                   .moveBy(x: 100, y: 0, duration: 6)])))
            }
        }
    }

    private func addPlank(text: String, at point: CGPoint, width: CGFloat) {
        let plankSize = CGSize(width: max(52, width), height: 62)
        let plank = SKSpriteNode(texture: woodTexture(size: plankSize), size: plankSize)
        plank.position = point
        addChild(plank)
        let outline = SKShapeNode(rectOf: plankSize, cornerRadius: 12)
        outline.position = point
        outline.fillColor = .clear
        outline.strokeColor = SKColor(red: 0.40, green: 0.23, blue: 0.13, alpha: 1)
        outline.lineWidth = 4
        addChild(outline)
        addChild(shadowedLabel(text, size: 27).settingPosition(point))
    }

    private func addGap(at point: CGPoint, width: CGFloat, height: CGFloat) {
        let gap = SKShapeNode(rectOf: CGSize(width: max(52, width), height: height), cornerRadius: 13)
        gap.position = point
        gap.fillColor = .clear
        gapNodes.append(gap)
        styleGap(gap)
        addChild(gap)
        addQuestionMark(to: gap)
    }

    private func styleGap(_ gap: SKShapeNode) {
        gap.strokeColor = .clear
        gap.lineWidth = 5
        gap.glowWidth = 7
        if let path = gap.path?.copy(dashingWithPhase: 0, lengths: [10, 7], transform: .identity) {
            let dashedOutline = SKShapeNode(path: path)
            dashedOutline.strokeColor = SKColor(red: 1, green: 0.69, blue: 0.12, alpha: 1)
            dashedOutline.lineWidth = 5
            dashedOutline.glowWidth = 7
            gap.addChild(dashedOutline)
        }
        if !reduceMotion {
            gap.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.8),
                                              .fadeAlpha(to: 1, duration: 0.8)])))
        }
    }

    private func addQuestionMark(to node: SKShapeNode) {
        let question = shadowedLabel("?", size: 32)
        question.fontColor = SKColor(red: 1, green: 0.68, blue: 0.1, alpha: 1)
        node.addChild(question)
    }

    private func addOperator(_ text: String, at point: CGPoint) {
        let pill = SKShapeNode(rectOf: CGSize(width: 68, height: 56), cornerRadius: 26)
        pill.position = point
        pill.fillColor = .white
        pill.strokeColor = SKColor(red: 0.80, green: 0.88, blue: 0.94, alpha: 1)
        pill.lineWidth = 4
        addChild(pill)
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 29
        label.fontColor = SKColor(red: 0.13, green: 0.19, blue: 0.30, alpha: 1)
        label.verticalAlignmentMode = .center
        pill.addChild(label)
    }

    private func addLabel(_ text: String, to node: SKNode, size: CGFloat) {
        node.addChild(shadowedLabel(text, size: size))
    }

    private func shadowedLabel(_ text: String, size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position.y = 2
        let shadow = SKLabelNode(text: text)
        shadow.fontName = label.fontName
        shadow.fontSize = size
        shadow.fontColor = SKColor.black.withAlphaComponent(0.28)
        shadow.verticalAlignmentMode = .center
        shadow.position.y = -2
        shadow.zPosition = -1
        label.addChild(shadow)
        return label
    }

    private func addCompanion(at point: CGPoint) {
        guard let companionTexture else { return }
        let sprite = SKSpriteNode(texture: companionTexture, size: CGSize(width: 96, height: 96))
        sprite.position = point
        sprite.zPosition = 12
        addChild(sprite)
        companionNode = sprite
    }

    private func gradientTexture(size: CGSize, colors: [SKColor]) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors.map(\.cgColor) as CFArray,
                                            locations: nil) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: image)
    }

    private func woodTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: [UIColor(red: 0.89, green: 0.65, blue: 0.40, alpha: 1).cgColor,
                                                     UIColor(red: 0.62, green: 0.35, blue: 0.18, alpha: 1).cgColor] as CFArray,
                                            locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                end: CGPoint(x: 0, y: size.height), options: [])
            context.cgContext.setStrokeColor(UIColor(red: 0.40, green: 0.23, blue: 0.13, alpha: 0.16).cgColor)
            context.cgContext.setLineWidth(2)
            for x in stride(from: CGFloat(18), to: size.width, by: CGFloat(24)) {
                context.cgContext.move(to: CGPoint(x: x, y: 0))
                context.cgContext.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.cgContext.strokePath()
        }
        return SKTexture(image: image)
    }
}

private extension SKLabelNode {
    func settingPosition(_ point: CGPoint) -> SKLabelNode {
        position = point
        return self
    }
}
