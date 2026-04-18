import SpriteKit
import SunTzuCore

/// 2D board rendered with SpriteKit. Each province is a circular node placed
/// in approximately canonical positions (top cluster = northern provinces).
/// Taps bubble back to `onProvinceTap`.
final class BoardScene: SKScene {
    var onProvinceTap: ((Province) -> Void)?
    private var nodes: [Province: ProvinceNode] = [:]
    private var currentState: GameState?

    // Relative positions in [0, 1] range; scaled to scene size on layout.
    private static let relativePositions: [Province: CGPoint] = [
        .qin:    CGPoint(x: 0.25, y: 0.80),
        .jinYan: CGPoint(x: 0.75, y: 0.80),
        .hanQi:  CGPoint(x: 0.50, y: 0.55),
        .chu:    CGPoint(x: 0.25, y: 0.25),
        .wu:     CGPoint(x: 0.75, y: 0.25),
    ]

    override func didMove(to view: SKView) {
        layoutProvinces()
        if let state = currentState { update(state: state) }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutProvinces()
    }

    func update(state: GameState) {
        currentState = state
        for province in Province.allCases {
            guard let node = nodes[province], let pv = state.provinces[province] else { continue }
            node.apply(
                provinceState: pv,
                placementsHere: placements(on: province, in: state),
                display: state.scoreDisplays[province],
                turn: state.turn
            )
        }
    }

    // MARK: - tap routing

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        for (province, node) in nodes where node.containsScenePoint(location) {
            onProvinceTap?(province)
            return
        }
    }

    // MARK: - layout

    private func layoutProvinces() {
        let radius = min(size.width, size.height) * 0.14

        if nodes.isEmpty {
            for province in Province.allCases {
                let node = ProvinceNode(province: province, radius: radius)
                nodes[province] = node
                addChild(node)
            }
            drawAdjacencyLines()
        }

        for province in Province.allCases {
            guard let node = nodes[province],
                  let relative = Self.relativePositions[province] else { continue }
            node.position = CGPoint(x: relative.x * size.width, y: relative.y * size.height)
            node.setRadius(radius)
        }
    }

    private func drawAdjacencyLines() {
        for (from, targets) in Province.adjacency {
            guard let a = Self.relativePositions[from] else { continue }
            for to in targets where from.hashValue < to.hashValue {
                guard let b = Self.relativePositions[to] else { continue }
                let line = SKShapeNode()
                line.strokeColor = UIColor(white: 1, alpha: 0.08)
                line.lineWidth = 1
                let path = CGMutablePath()
                path.move(to: CGPoint(x: a.x * size.width, y: a.y * size.height))
                path.addLine(to: CGPoint(x: b.x * size.width, y: b.y * size.height))
                line.path = path
                line.zPosition = -1
                addChild(line)
            }
        }
    }

    private func placements(on province: Province, in state: GameState) -> [Placement] {
        state.placements.filter { $0.province == province }
    }
}
