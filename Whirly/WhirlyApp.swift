import SwiftUI

@main
struct WhirlyApp: App {
    var body: some Scene {
        WindowGroup {
            GameView().preferredColorScheme(.light)
        }
    }
}
