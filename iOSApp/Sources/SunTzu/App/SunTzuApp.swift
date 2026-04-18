import SwiftUI

@main
struct SunTzuApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        NavigationStack {
            MainMenuView()
        }
    }
}
