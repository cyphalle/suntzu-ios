import SwiftUI
import SpriteKit
import SunTzuCore

/// SwiftUI wrapper around the SpriteKit board scene.
///
/// The `BoardScene` lives in `@State` so SpriteView can reuse the same SKScene
/// across re-renders; `onAppear` / `onChange` hooks push state changes into it
/// in place. Recreating the scene each body pass would let SpriteView cache
/// the first snapshot it received and miss later updates (face-down markers
/// only surfacing after the next user tap).
struct BoardView: View {
    let state: GameState
    @Binding var selectedCard: Card?
    var onProvinceTap: (Province) -> Void

    @State private var scene: BoardScene = {
        let s = BoardScene(size: CGSize(width: 400, height: 400))
        s.scaleMode = .resizeFill
        s.backgroundColor = .clear
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            SpriteView(
                scene: scene,
                options: [.allowsTransparency, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea(edges: [])
            .background(Color(white: 0.05))
            .onAppear {
                configure(size: geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                scene.size = newSize
            }
            .onChange(of: state) { _, newState in
                scene.update(state: newState)
                scene.onProvinceTap = onProvinceTap
            }
        }
    }

    private func configure(size: CGSize) {
        scene.size = size
        scene.update(state: state)
        scene.onProvinceTap = onProvinceTap
    }
}
