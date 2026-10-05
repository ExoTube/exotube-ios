import SwiftUI

struct SettingsScreen: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    var body: some View {
        NavigationStack {
            List {
                ScreenHeader(subtitle: "Ajustes")
                Section {
                    Label("Tus descargas también están en la app Archivos: En mi iPhone → ExoTube.", systemImage: "folder")
                    Label("La música sigue sonando con la pantalla apagada y se controla desde la pantalla de bloqueo.", systemImage: "lock.iphone")
                } header: { Text("Cómo funciona").foregroundColor(Exo.green) }
                .listRowBackground(Exo.surfaceLow)

                Section {
                    Link(destination: URL(string: "https://exotube.github.io")!) {
                        Label("exotube.github.io", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://github.com/ExoTube/exotube-ios")!) {
                        Label("Código abierto (GPLv3)", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: { Text("ExoTube").foregroundColor(Exo.green) }
                .listRowBackground(Exo.surfaceLow)

                Text("ExoTube para iPhone \(version) · gratis, sin anuncios y sin registro")
                    .font(.footnote).foregroundColor(Exo.textSecondary)
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Exo.black)
        }
    }
}
