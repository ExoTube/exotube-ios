import Foundation

/** Una canción o video descargado. Su [id] es el nombre del archivo dentro de la carpeta. */
struct LibraryItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case audio, video }

    let id: String
    var title: String
    var channel: String
    var durationSeconds: Int?
    let kind: Kind
    /** El video de YouTube del que vino, si se descargó con ExoTube. */
    let sourceID: String?
    let addedAt: Date

    var fileURL: URL { Library.folder.appendingPathComponent(id) }
    var thumbnailURL: URL? { sourceID.map { URL(string: "https://i.ytimg.com/vi/\($0)/hqdefault.jpg")! } }

    static func kind(ofFile name: String) -> Kind? {
        switch (name as NSString).pathExtension.lowercased() {
        case "m4a", "mp3", "aac", "wav", "flac", "opus", "ogg": return .audio
        case "mp4", "mov", "m4v": return .video
        default: return nil
        }
    }
}

/**
 * Lo descargado. Los archivos viven en Documentos/ExoTube, que también se ve desde la app
 * Archivos ("En mi iPhone → ExoTube"); al lado se guarda un índice con título, canal y duración.
 *
 * Si alguien mete o borra archivos desde Archivos, [reload] lo nota: los nuevos se añaden (con el
 * nombre del archivo como título) y los que ya no están desaparecen de la lista.
 */
@MainActor
final class Library: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []

    nonisolated static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("ExoTube", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private var indexURL: URL { Library.folder.appendingPathComponent(".biblioteca.json") }

    init() { reload() }

    func reload() {
        let saved = (try? JSONDecoder().decode([LibraryItem].self, from: Data(contentsOf: indexURL))) ?? []
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Library.folder.path)) ?? []
        items = reconcile(index: saved, files: files, now: Date())
        save()
    }

    func add(_ item: LibraryItem) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        save()
    }

    func delete(_ item: LibraryItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        items.removeAll { $0.id == item.id }
        save()
    }

    /** Un nombre de archivo libre: "Título.m4a", y si ya existe "Título (2).m4a". */
    func freeFileName(for title: String, extension ext: String) -> String {
        let base = safeFileName(title)
        var name = "\(base).\(ext)"
        var n = 2
        while FileManager.default.fileExists(atPath: Library.folder.appendingPathComponent(name).path) {
            name = "\(base) (\(n)).\(ext)"
            n += 1
        }
        return name
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: indexURL, options: .atomic) }
    }
}

/**
 * Junta el índice guardado con lo que de verdad hay en la carpeta: quita lo que ya no existe y
 * añade lo nuevo. Lo más reciente, primero.
 */
func reconcile(index: [LibraryItem], files: [String], now: Date) -> [LibraryItem] {
    let present = Set(files)
    var result = index.filter { present.contains($0.id) }
    let known = Set(result.map(\.id))
    for file in files where !known.contains(file) && !file.hasPrefix(".") {
        guard let kind = LibraryItem.kind(ofFile: file) else { continue }
        let title = (file as NSString).deletingPathExtension
        result.append(LibraryItem(id: file, title: title, channel: "", durationSeconds: nil, kind: kind, sourceID: nil, addedAt: now))
    }
    return result.sorted { $0.addedAt > $1.addedAt }
}
