import SpriteKit
import WonderMathCore

final class BridgeScene: SKScene {
    private let water = SKColor(red: 0.25, green: 0.72, blue: 0.82, alpha: 1)
    private let plankColor = SKColor(red: 0.63, green: 0.39, blue: 0.22, alpha: 1)
    private let gapGlow = SKColor(red: 1, green: 0.88, blue: 0.31, alpha: 1)
    private var gapNodes: [SKShapeNode] = []
    private var nextGapIndex = 0
    private var companionNode: SKShapeNode?
    private var isSequence = false

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .aspectFill
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .aspectFill
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.62, green: 0.85, blue: 0.96, alpha: 1)
    }

    func configure(tokens: [BridgeToken]) {
        removeAllChildren()
        gapNodes.removeAll()
        nextGapIndex = 0
        isSequence = false
        drawRiverAndBanks()
        let count = max(tokens.count, 1)
        let width = min(112, (size.width - 160) / CGFloat(count))
        for (index, token) in tokens.enumerated() {
            let x = CGFloat(index) * width - CGFloat(count - 1) * width / 2
            let y: CGFloat = token == .equals ? -12 : 3
            switch token {
            case .number(let value):
                addPlank(text: "\(value)", at: CGPoint(x: x, y: y), width: width - 8)
            case .operation(let operation):
                addTokenLabel(operation.symbol, at: CGPoint(x: x, y: y + 7))
            case .equals:
                addTokenLabel("=", at: CGPoint(x: x, y: y + 7))
            case .gap:
                addGap(at: CGPoint(x: x, y: y), width: width - 8)
            }
        }
        addCompanion(at: CGPoint(x: size.width * 0.37, y: 112))
    }

    func configure(sequence terms: [Int?]) {
        removeAllChildren()
        gapNodes.removeAll()
        nextGapIndex = 0
        isSequence = true
        drawRiverAndBanks()
        let count = max(terms.count, 1)
        let spacing = min(132, (size.width - 140) / CGFloat(count))
        for (index, term) in terms.enumerated() {
            let x = CGFloat(index) * spacing - CGFloat(count - 1) * spacing / 2
            let stone = SKShapeNode(ellipseOf: CGSize(width: 88, height: 58))
            stone.position = CGPoint(x: x, y: 2)
            stone.fillColor = term == nil ? gapGlow : SKColor(red: 0.57, green: 0.68, blue: 0.53, alpha: 1)
            stone.strokeColor = .white
            stone.lineWidth = 4
            addChild(stone)
            if let term {
                let label = SKLabelNode(text: "\(term)")
                label.fontName = "AvenirNext-Bold"
                label.fontSize = 23
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                stone.addChild(label)
            } else {
                gapNodes.append(stone)
                stone.glowWidth = 7
            }
        }
        addCompanion(at: CGPoint(x: size.width * 0.37, y: 112))
    }

    func fill(gapWith value: Int) {
        guard !gapNodes.isEmpty else { return }
        let index = min(nextGapIndex, gapNodes.count - 1)
        let node = gapNodes[index]
        nextGapIndex = min(nextGapIndex + 1, gapNodes.count)
        node.removeAllChildren()
        node.fillColor = isSequence ? SKColor(red: 0.57, green: 0.68, blue: 0.53, alpha: 1) : plankColor
        node.strokeColor = isSequence ? .white : SKColor(red: 0.39, green: 0.23, blue: 0.13, alpha: 1)
        let label = SKLabelNode(text: "\(value)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = isSequence ? 23 : 21
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)
    }

    func clearGap() {
        for node in gapNodes {
            node.removeAllChildren()
            node.fillColor = isSequence ? gapGlow : gapGlow.withAlphaComponent(0.45)
            node.strokeColor = gapGlow
            node.glowWidth = 8
        }
        nextGapIndex = 0
    }

    func celebrate() {
        guard let companionNode else { return }
        let walk = SKAction.moveBy(x: size.width * 0.22, y: 0, duration: 0.8)
        walk.timingMode = .easeInEaseOut
        companionNode.run(walk)
        for _ in 0..<18 {
            let sparkle = SKShapeNode(circleOfRadius: 5)
            sparkle.fillColor = [SKColor.yellow, .white, .orange].randomElement() ?? .yellow
            sparkle.strokeColor = .clear
            sparkle.position = CGPoint(x: CGFloat.random(in: -size.width * 0.3...size.width * 0.3),
                                       y: CGFloat.random(in: 20...size.height * 0.28))
            addChild(sparkle)
            sparkle.run(.sequence([.group([.moveBy(x: 0, y: 45, duration: 0.7),
                                           .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        }
    }

    func wobble() {
        guard let gapNode = gapNodes.last else { return }
        let move = SKAction.sequence([.moveBy(x: -8, y: 0, duration: 0.08),
                                      .moveBy(x: 16, y: 0, duration: 0.16),
                                      .moveBy(x: -8, y: 0, duration: 0.08)])
        gapNode.run(move)
    }

    private func drawRiverAndBanks() {
        let river = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.28))
        river.position = CGPoint(x: 0, y: -size.height * 0.21)
        river.fillColor = water
        river.strokeColor = .clear
        addChild(river)
        for x in [-size.width * 0.39, size.width * 0.39] {
            let bank = SKShapeNode(rectOf: CGSize(width: size.width * 0.25, height: 95),
                                   cornerRadius: 24)
            bank.position = CGPoint(x: x, y: 34)
            bank.fillColor = SKColor(red: 0.43, green: 0.68, blue: 0.39, alpha: 1)
            bank.strokeColor = .clear
            addChild(bank)
        }
    }

    private func addPlank(text: String, at point: CGPoint, width: CGFloat) {
        let plank = SKShapeNode(rectOf: CGSize(width: max(52, width), height: 48), cornerRadius: 9)
        plank.position = point
        plank.fillColor = plankColor
        plank.strokeColor = SKColor(red: 0.39, green: 0.23, blue: 0.13, alpha: 1)
        plank.lineWidth = 3
        addChild(plank)
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 21
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        plank.addChild(label)
    }

    private func addGap(at point: CGPoint, width: CGFloat) {
        let gap = SKShapeNode(rectOf: CGSize(width: max(52, width), height: 52), cornerRadius: 12)
        gap.position = point
        gap.fillColor = gapGlow.withAlphaComponent(0.45)
        gap.strokeColor = gapGlow
        gap.lineWidth = 5
        gap.glowWidth = 8
        addChild(gap)
        gapNodes.append(gap)
    }

    private func addTokenLabel(_ text: String, at point: CGPoint) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 27
        label.fontColor = SKColor(red: 0.23, green: 0.33, blue: 0.48, alpha: 1)
        label.position = point
        addChild(label)
    }

    private func addCompanion(at point: CGPoint) {
        let body = SKShapeNode(circleOfRadius: 25)
        body.position = point
        body.fillColor = SKColor(red: 1, green: 0.65, blue: 0.28, alpha: 1)
        body.strokeColor = .white
        body.lineWidth = 3
        addChild(body)
        let face = SKLabelNode(text: "☺")
        face.fontSize = 30
        face.verticalAlignmentMode = .center
        face.fontColor = .white
        body.addChild(face)
        companionNode = body
    }
}
