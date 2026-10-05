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

    /**
     * La pestaña con la que abre la app. Normalmente Biblioteca; las capturas automáticas de
     * GitHub abren cada pestaña pasando "-tab explorar" al lanzar la app.
     */
    static var initial: Tab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = Tab(rawValue: args[i + 1]) {
            return tab
        }
        return .library
    }
}

struct RootView: View {
    @State private var tab = Tab.initial

    var body: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                PlaceholderScreen(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
    }
}

/** Pantalla provisional mientras se construye cada parte de la app de iPhone. */
struct PlaceholderScreen: View {
    let tab: Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ExoWordmark()
            Text(tab.title)
                .font(.title3.weight(.semibold))
                .foregroundColor(Exo.textSecondary)
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 48))
                        .foregroundColor(Exo.green)
                    Text("Muy pronto en iPhone")
                        .foregroundColor(Exo.textSecondary)
                }
                Spacer()
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Exo.black)
    }
}
