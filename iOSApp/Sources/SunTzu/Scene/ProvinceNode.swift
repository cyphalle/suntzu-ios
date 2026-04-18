import SpriteKit
import SunTzuCore

/// A single province token on the board.
final class ProvinceNode: SKNode {
    let province: Province
    private let disc = SKShapeNode()
    private let nameLabel = SKLabelNode()
    private let armiesLabel = SKLabelNode()
    private let placementsIndicator = SKLabelNode()
    private var radius: CGFloat = 60

    init(province: Province, radius: CGFloat) {
        self.province = province
        super.init()
        self.radius = radius
        addChild(disc)

        nameLabel.fontName = "AvenirNext-DemiBold"
        nameLabel.fontSize = 14
        nameLabel.fontColor = .white
        nameLabel.text = Self.displayName(province)
        nameLabel.verticalAlignmentMode = .center
        addChild(nameLabel)

        armiesLabel.fontName = "AvenirNext-Bold"
        armiesLabel.fontSize = 22
        armiesLabel.fontColor = .white
        armiesLabel.verticalAlignmentMode = .center
        addChild(armiesLabel)

        placementsIndicator.fontName = "AvenirNext-Regular"
        placementsIndicator.fontSize = 12
        placementsIndicator.fontColor = .white
        placementsIndicator.alpha = 0.7
        placementsIndicator.verticalAlignmentMode = .center
        addChild(placementsIndicator)

        layout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func setRadius(_ r: CGFloat) {
        radius = r
        layout()
    }

    func apply(provinceState: ProvinceState, placementsHere: [Placement]) {
        switch provinceState.controller {
        case .blue:
            disc.fillColor = UIColor.systemBlue.withAlphaComponent(0.35)
            disc.strokeColor = UIColor.systemBlue
        case .red:
            disc.fillColor = UIColor.systemRed.withAlphaComponent(0.35)
            disc.strokeColor = UIColor.systemRed
        case nil:
            disc.fillColor = UIColor.white.withAlphaComponent(0.08)
            disc.strokeColor = UIColor.white.withAlphaComponent(0.3)
        }
        disc.lineWidth = 2
        armiesLabel.text = provinceState.armies == 0 ? "" : "\(provinceState.armies)"

        // Dots per placed (face-down) card, colour-coded by player.
        let bluePlaced = placementsHere.contains { $0.player == .blue }
        let redPlaced = placementsHere.contains { $0.player == .red }
        var tokens: [String] = []
        if bluePlaced { tokens.append("⬤") } // placeholder — blue dot via colour later
        if redPlaced  { tokens.append("⬤") }
        placementsIndicator.text = tokens.joined(separator: " ")
    }

    // MARK: - hit testing

    /// True if `point` (scene coordinates) falls inside the disc.
    func containsScenePoint(_ point: CGPoint) -> Bool {
        let dx = point.x - position.x
        let dy = point.y - position.y
        return dx * dx + dy * dy <= radius * radius
    }

    // MARK: - layout

    private func layout() {
        let rect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
        disc.path = CGPath(ellipseIn: rect, transform: nil)
        nameLabel.position = CGPoint(x: 0, y: radius * 0.35)
        armiesLabel.position = CGPoint(x: 0, y: -radius * 0.05)
        placementsIndicator.position = CGPoint(x: 0, y: -radius * 0.5)
    }

    private static func displayName(_ p: Province) -> String {
        switch p {
        case .qin:    return "QIN"
        case .chu:    return "CHU"
        case .jinYan: return "JIN-YAN"
        case .hanQi:  return "HAN-QI"
        case .wu:     return "WU"
        }
    }
}
