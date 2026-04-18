import SwiftUI
import SpriteKit
import SunTzuCore

/// SwiftUI wrapper around the SpriteKit board scene.
struct BoardView: View {
    let state: GameState
    @Binding var selectedCard: Card?
    var onProvinceTap: (Province) -> Void

    var body: some View {
        GeometryReader { geo in
            SpriteView(
                scene: sceneFor(size: geo.size),
                options: [.allowsTransparency, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea(edges: [])
            .background(Color(white: 0.05))
        }
    }

    private func sceneFor(size: CGSize) -> BoardScene {
        let scene = BoardScene(size: size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.update(state: state)
        scene.onProvinceTap = onProvinceTap
        return scene
    }
}
