import SwiftUI

struct LibraryScreen: View {
    enum Filter: String, CaseIterable { case all = "Todo", audio = "Audio", video = "Video" }

    @EnvironmentObject private var library: Library
    @EnvironmentObject private var playlists: Playlists
    @EnvironmentObject private var downloads: Downloads
    @EnvironmentObject private var player: Player
    @State private var filter = Filter.all
    @State private var query = ""
    @State private var toDelete: MediaFile?

    private var visible: [MediaFile] {
        library.items.filter { item in
            switch filter {
            case .all: return true
            case .audio: return item.kind == .audio
            case .video: return item.kind == .video
            }
        }
        .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.channel.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                ScreenHeader(subtitle: library.items.count == 1 ? "1 descarga" : "\(library.items.count) descargas")
                Picker("Mostrar", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if !downloads.jobs.isEmpty {
                    Section {
                        ForEach(downloads.jobs) { DownloadRow(job: $0).listRowBackground(Color.clear) }
                        if downloads.jobs.contains(where: { $0.state != .running }) {
                            Button("Quitar las terminadas") { downloads.clearFinished() }.font(.footnote).listRowBackground(Color.clear)
                        }
                    } header: { Text("Descargando").foregroundColor(Exo.green) }
                }

                if visible.isEmpty {
                    EmptyState(icon: "arrow.down.circle",
                               text: library.items.isEmpty ? "Todavía no hay nada aquí.\nDescarga música y videos desde Explorar." : "Nada con ese filtro.")
                }
                ForEach(Array(visible.enumerated()), id: \.element.id) { i, item in
                    Button { player.play(visible.map(PlayItem.local), startAt: i) } label: { LibraryRow(item: item) }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(role: .destructive) { toDelete = item } label: { Label("Borrar", systemImage: "trash") }
                        }
                        .contextMenu {
                            Menu {
                                ForEach(playlists.all) { list in
                                    Button(list.name) { playlists.add(item.id, to: list) }
                                }
                                Button("Nueva playlist…") { playlists.add(item.id, to: playlists.create("Mi playlist \(playlists.all.count + 1)")) }
                            } label: { Label("Añadir a playlist", systemImage: "text.badge.plus") }
                            ShareLink(item: item.fileURL) { Label("Compartir archivo", systemImage: "square.and.arrow.up") }
                            Button(role: .destructive) { toDelete = item } label: { Label("Borrar", systemImage: "trash") }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Exo.black)
            .searchable(text: $query, prompt: "Buscar canción o artista")
            .refreshable { library.reload() }
            .onAppear { library.reload() }
            .alert("¿Borrar «\(toDelete?.title ?? "")»?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
                Button("Borrar", role: .destructive) { if let item = toDelete { library.delete(item) } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se borra el archivo del iPhone.")
            }
        }
    }
}
