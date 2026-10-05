import SwiftUI

/** Punto de entrada de la app de iPhone: crea las piezas compartidas y se las pasa a las pantallas. */
@main
struct ExoTubeApp: App {
    @StateObject private var library: Library
    @StateObject private var playlists = Playlists()
    @StateObject private var downloads: Downloads
    @StateObject private var player = Player()

    init() {
        let library = Library()
        _library = StateObject(wrappedValue: library)
        _downloads = StateObject(wrappedValue: Downloads(library: library))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(playlists)
                .environmentObject(downloads)
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .tint(Exo.green)
        }
    }
}

/** Lo que se pasa al lanzar la app: lo usan las capturas automáticas de GitHub. */
enum LaunchArguments {
    static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
