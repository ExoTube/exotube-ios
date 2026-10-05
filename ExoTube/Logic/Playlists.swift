import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /** Los [MediaFile.id] de sus canciones, en orden. */
    var itemIDs: [String]
}

/** Las playlists del usuario. Se guardan en un archivo junto a la biblioteca. */
@MainActor
final class Playlists: ObservableObject {
    @Published private(set) var all: [Playlist] = []

    private var fileURL: URL { Library.folder.appendingPathComponent(".playlists.json") }

    init() {
        all = (try? JSONDecoder().decode([Playlist].self, from: Data(contentsOf: fileURL))) ?? []
    }

    @discardableResult
    func create(_ name: String) -> Playlist {
        let playlist = Playlist(id: UUID(), name: name.trimmingCharacters(in: .whitespaces), itemIDs: [])
        all.append(playlist)
        save()
        return playlist
    }

    func rename(_ playlist: Playlist, to name: String) { update(playlist.id) { $0.name = name } }

    func delete(_ playlist: Playlist) {
        all.removeAll { $0.id == playlist.id }
        save()
    }

    func add(_ itemID: String, to playlist: Playlist) {
        update(playlist.id) { if !$0.itemIDs.contains(itemID) { $0.itemIDs.append(itemID) } }
    }

    func remove(_ itemID: String, from playlist: Playlist) { update(playlist.id) { $0.itemIDs.removeAll { $0 == itemID } } }

    /** Las canciones de una playlist que siguen en la biblioteca (las borradas se saltan). */
    func items(of playlist: Playlist, in library: [MediaFile]) -> [MediaFile] {
        let byID = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return playlist.itemIDs.compactMap { byID[$0] }
    }

    private func update(_ id: UUID, _ change: (inout Playlist) -> Void) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        change(&all[i])
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(all) { try? data.write(to: fileURL, options: .atomic) }
    }
}
