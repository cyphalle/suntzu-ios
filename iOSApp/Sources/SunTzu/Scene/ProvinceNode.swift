import SpriteKit
import SunTzuCore

/// A single province token on the board.
/// Shows: name, current armies, score-display values (T3 · T6 · T9 with the
/// next scoring turn highlighted), 6-marker badges per player, face-down
/// placement dots.
final class ProvinceNode: SKNode {
    let province: Province
    private let disc = SKShapeNode()
    private let nameLabel = SKLabelNode()
    private let armiesLabel = SKLabelNode()
    private let placementsIndicator = SKLabelNode()

    // Score display values — three small labels in a row.
    private let t3Label = SKLabelNode()
    private let t6Label = SKLabelNode()
    private let t9Label = SKLabelNode()

    // One badge per player who's already played a 6 here.
    private let blueSixMarker = SKLabelNode()
    private let redSixMarker = SKLabelNode()

    private var radius: CGFloat = 60

    init(province: Province, radius: CGFloat) {
        self.province = province
        super.init()
        self.radius = radius
        addChild(disc)

        nameLabel.fontName = "AvenirNext-DemiBold"
        nameLabel.fontSize = 13
        nameLabel.fontColor = .white
        nameLabel.text = Self.displayName(province)
        nameLabel.verticalAlignmentMode = .center
        addChild(nameLabel)

        for (label, placeholder) in [(t3Label, "1"), (t6Label, "1"), (t9Label, "1")] {
            label.fontName = "AvenirNext-Medium"
            label.fontSize = 11
            label.text = placeholder
            label.fontColor = UIColor.white.withAlphaComponent(0.5)
            label.verticalAlignmentMode = .center
            addChild(label)
        }

        armiesLabel.fontName = "AvenirNext-Bold"
        armiesLabel.fontSize = 24
        armiesLabel.fontColor = .white
        armiesLabel.verticalAlignmentMode = .center
        addChild(armiesLabel)

        for (label, color) in [
            (blueSixMarker, UIColor.systemBlue),
            (redSixMarker, UIColor.systemRed),
        ] {
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 11
            label.fontColor = color
            label.text = "6"
            label.verticalAlignmentMode = .center
            label.alpha = 0
            addChild(label)
        }

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

    func apply(
        provinceState: ProvinceState,
        placementsHere: [Placement],
        display: ScoreDisplay?,
        turn: Int
    ) {
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

        // Score displays — highlight the upcoming scoring value.
        let nextTurn = Self.nextScoringTurn(turn)
        if let d = display {
            t3Label.text = "\(d.t3)"
            t6Label.text = "\(d.t6)"
            t9Label.text = "\(d.t9)"
        } else {
            t3Label.text = "—"
            t6Label.text = "—"
            t9Label.text = "—"
        }
        for (label, t) in [(t3Label, 3), (t6Label, 6), (t9Label, 9)] {
            if t == nextTurn {
                label.fontColor = .systemYellow
                label.fontSize = 13
            } else {
                label.fontColor = UIColor.white.withAlphaComponent(0.45)
                label.fontSize = 11
            }
        }

        // Six-markers per player.
        blueSixMarker.alpha = provinceState.sixMarkers.contains(.blue) ? 1 : 0
        redSixMarker.alpha = provinceState.sixMarkers.contains(.red) ? 1 : 0

        // Face-down placement dots.
        let bluePlaced = placementsHere.contains { $0.player == .blue }
        let redPlaced = placementsHere.contains { $0.player == .red }
        var tokens: [String] = []
        if bluePlaced { tokens.append("⬤") }
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

        nameLabel.position = CGPoint(x: 0, y: radius * 0.55)

        let scoreY = radius * 0.28
        let dx = radius * 0.24
        t3Label.position = CGPoint(x: -dx, y: scoreY)
        t6Label.position = CGPoint(x: 0, y: scoreY)
        t9Label.position = CGPoint(x: dx, y: scoreY)

        armiesLabel.position = CGPoint(x: 0, y: -radius * 0.15)

        blueSixMarker.position = CGPoint(x: -radius * 0.55, y: -radius * 0.55)
        redSixMarker.position = CGPoint(x: radius * 0.55, y: -radius * 0.55)

        placementsIndicator.position = CGPoint(x: 0, y: -radius * 0.88)
    }

    // MARK: - helpers

    private static func displayName(_ p: Province) -> String {
        switch p {
        case .qin:    return "QIN"
        case .chu:    return "CHU"
        case .jinYan: return "JIN-YAN"
        case .hanQi:  return "HAN-QI"
        case .wu:     return "WU"
        }
    }

    private static func nextScoringTurn(_ turn: Int) -> Int {
        if turn <= 3 { return 3 }
        if turn <= 6 { return 6 }
        return 9
    }
}
