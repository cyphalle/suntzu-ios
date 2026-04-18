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

    /// Score display — single attributed label with inline highlighting.
    private let scoreLabel = SKLabelNode()

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

        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.numberOfLines = 1
        addChild(scoreLabel)

        armiesLabel.fontName = "AvenirNext-Bold"
        armiesLabel.fontSize = 26
        armiesLabel.fontColor = .white
        armiesLabel.verticalAlignmentMode = .center
        addChild(armiesLabel)

        for (label, color) in [
            (blueSixMarker, UIColor.systemBlue),
            (redSixMarker, UIColor.systemRed),
        ] {
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 12
            label.fontColor = color
            label.text = "6"
            label.verticalAlignmentMode = .center
            label.alpha = 0
            addChild(label)
        }

        placementsIndicator.fontName = "AvenirNext-Regular"
        placementsIndicator.fontSize = 14
        placementsIndicator.fontColor = .white
        placementsIndicator.alpha = 0.75
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

        // Build a single attributed string "T3 · T6 · T9" with the next scoring
        // turn's value highlighted.
        let nextTurn = Self.nextScoringTurn(turn)
        if let d = display {
            scoreLabel.attributedText = Self.scoreDisplayString(
                t3: d.t3, t6: d.t6, t9: d.t9, nextTurn: nextTurn
            )
        } else {
            scoreLabel.text = "—"
            scoreLabel.fontColor = UIColor.white.withAlphaComponent(0.4)
        }

        blueSixMarker.alpha = provinceState.sixMarkers.contains(.blue) ? 1 : 0
        redSixMarker.alpha = provinceState.sixMarkers.contains(.red) ? 1 : 0

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

        nameLabel.position = CGPoint(x: 0, y: radius * 0.62)
        scoreLabel.position = CGPoint(x: 0, y: radius * 0.30)
        armiesLabel.position = CGPoint(x: 0, y: -radius * 0.18)
        blueSixMarker.position = CGPoint(x: -radius * 0.55, y: -radius * 0.58)
        redSixMarker.position = CGPoint(x: radius * 0.55, y: -radius * 0.58)
        placementsIndicator.position = CGPoint(x: 0, y: -radius * 1.05)
    }

    // MARK: - attributed score display

    private static func scoreDisplayString(
        t3: Int,
        t6: Int,
        t9: Int,
        nextTurn: Int
    ) -> NSAttributedString {
        let base = UIFont(name: "AvenirNext-Medium", size: 12)
            ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        let highlight = UIFont(name: "AvenirNext-Bold", size: 15)
            ?? UIFont.systemFont(ofSize: 15, weight: .bold)

        let dimAttrs: [NSAttributedString.Key: Any] = [
            .font: base,
            .foregroundColor: UIColor.white.withAlphaComponent(0.55),
        ]
        let sepAttrs: [NSAttributedString.Key: Any] = [
            .font: base,
            .foregroundColor: UIColor.white.withAlphaComponent(0.35),
        ]
        let highlightAttrs: [NSAttributedString.Key: Any] = [
            .font: highlight,
            .foregroundColor: UIColor.systemYellow,
        ]

        let string = NSMutableAttributedString()
        for (i, pair) in [(t3, 3), (t6, 6), (t9, 9)].enumerated() {
            if i > 0 {
                string.append(NSAttributedString(string: " · ", attributes: sepAttrs))
            }
            let attrs = pair.1 == nextTurn ? highlightAttrs : dimAttrs
            string.append(NSAttributedString(string: "\(pair.0)", attributes: attrs))
        }
        return string
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
