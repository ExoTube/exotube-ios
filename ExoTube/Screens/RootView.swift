import SwiftUI

/** Las pestañas de abajo, las mismas que en Android. */
enum Tab: String, CaseIterable {
    case library = "biblioteca"
    case explore = "explorar"
    case playlists = "playlists"
    case settings = "ajustes"

    var title: String {
        switch self {
        case .library: return "Biblioteca"
        case .explore: return "Explorar"
        case .playlists: return "Playlists"
        case .settings: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .library: return "music.note.house"
        case .explore: return "safari"
        case .playlists: return "music.note.list"
        case .settings: return "gearshape"
        }
    }

    /** Normalmente Biblioteca; las capturas automáticas abren cada pestaña con "-tab explorar". */
    static var initial: Tab { LaunchArguments.value(after: "-tab").flatMap(Tab.init(rawValue:)) ?? .library }
}

struct RootView: View {
    @State private var tab = Tab.initial
    @State private var showsNowPlaying = false
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var downloads: Downloads

    var body: some View {
        TabView(selection: $tab) {
            screen(for: .library) { LibraryScreen() }
            screen(for: .explore) { ExploreScreen() }
            screen(for: .playlists) { PlaylistsScreen() }
            screen(for: .settings) { SettingsScreen() }
        }
        .sheet(isPresented: $showsNowPlaying) { NowPlayingView() }
        .task { runSelfTest() }
    }

    /**
     * Pruebas de verdad, con internet, para las capturas automáticas de GitHub (no hay un iPhone
     * físico donde probar): "-reproducir ID" abre el reproductor con ese video y "-descargar ID"
     * lo descarga como video. En el uso normal no se pasa nada de esto.
     */
    private func runSelfTest() {
        if let id = LaunchArguments.value(after: "-reproducir") {
            player.play([.online(OnlineVideo(id: id, title: "Prueba de reproducción", channel: "ExoTube", durationSeconds: nil, views: nil))],
                        withVideo: true)
            showsNowPlaying = true
        }
        if let id = LaunchArguments.value(after: "-descargar") {
            downloads.start(OnlineVideo(id: id, title: "Prueba de descarga", channel: "ExoTube", durationSeconds: nil, views: nil), as: .video)
            downloads.start(OnlineVideo(id: id, title: "Prueba de descarga", channel: "ExoTube", durationSeconds: nil, views: nil), as: .audio)
        }
    }

    /** Cada pestaña lleva debajo el mini reproductor, como en Android. */
    private func screen<Content: View>(for tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .bottom) { MiniPlayer { showsNowPlaying = true } }
            .tabItem { Label(tab.title, systemImage: tab.icon) }
            .tag(tab)
    }
}

/** El encabezado de cada pestaña: el logotipo y una línea debajo. */
struct ScreenHeader: View {
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ExoWordmark()
            Text(subtitle).font(.subheadline).foregroundColor(Exo.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

/** Una pantalla vacía con un ícono y un texto (sin descargas, sin resultados...). */
struct EmptyState: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(Exo.green)
            Text(text).multilineTextAlignment(.center).foregroundColor(Exo.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
