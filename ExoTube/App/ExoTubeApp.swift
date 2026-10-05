import SwiftUI

/** Punto de entrada de la app de iPhone. */
@main
struct ExoTubeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Exo.green)
        }
    }
}
