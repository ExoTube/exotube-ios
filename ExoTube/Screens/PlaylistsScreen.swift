import SwiftUI

struct PlaylistsScreen: View {
    @EnvironmentObject private var playlists: Playlists
    @EnvironmentObject private var library: Library
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ScreenHeader(subtitle: "Tus listas, para escuchar sin internet.")
                if playlists.all.isEmpty {
                    EmptyState(icon: "music.note.list",
                               text: "Crea una playlist con el botón +.\nPara añadir canciones, mantén pulsada una en la Biblioteca.")
                }
                ForEach(playlists.all) { list in
                    NavigationLink(value: list) {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list").font(.title2).foregroundColor(Exo.green)
                                .frame(width: 52, height: 52).background(Exo.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading) {
                                Text(list.name).font(.body.weight(.medium))
                                Text("\(playlists.items(of: list, in: library.items).count) canciones")
                                    .font(.caption).foregroundColor(Exo.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions { Button(role: .destructive) { playlists.delete(list) } label: { Label("Borrar", systemImage: "trash") } }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Exo.black)
            .navigationDestination(for: Playlist.self) { PlaylistDetail(playlistID: $0.id) }
            .toolbar {
                Button { newName = ""; naming = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nueva playlist")
            }
            .alert("Nueva playlist", isPresented: $naming) {
                TextField("Nombre", text: $newName)
                Button("Crear") { if !newName.trimmingCharacters(in: .whitespaces).isEmpty { playlists.create(newName) } }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }
}

struct PlaylistDetail: View {
    let playlistID: UUID
    @EnvironmentObject private var playlists: Playlists
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player

    var body: some View {
        if let list = playlists.all.first(where: { $0.id == playlistID }) {
            let items = playlists.items(of: list, in: library.items)
            List {
                if items.isEmpty {
                    EmptyState(icon: "music.note", text: "Esta playlist está vacía.\nMantén pulsada una canción en la Biblioteca para añadirla.")
                } else {
                    Button { player.play(items.map(PlayItem.local)) } label: {
                        Label("Reproducir todo", systemImage: "play.fill").font(.headline)
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Button { player.play(items.map(PlayItem.local), startAt: i) } label: { LibraryRow(item: item) }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions { Button(role: .destructive) { playlists.remove(item.id, from: list) } label: { Label("Quitar", systemImage: "minus.circle") } }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Exo.black)
            .navigationTitle(list.name)
        }
    }
}
