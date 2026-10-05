import Foundation

/** Un video de YouTube tal como sale en una búsqueda o en "Para ti". */
struct OnlineVideo: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let channel: String
    let durationSeconds: Int?
    let views: String?

    var thumbnailURL: URL { URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")! }
    var watchURL: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
}

/**
 * Lee las respuestas de YouTube (las mismas que usa youtube.com en el navegador).
 *
 * YouTube cambia a menudo DÓNDE pone las cosas dentro de la respuesta, pero no cómo se llama cada
 * pieza ("videoRenderer" es un video de la búsqueda, "playlistPanelVideoRenderer" uno del mix).
 * Por eso no se sigue una ruta fija: se recorre toda la respuesta buscando esas piezas, que es
 * mucho más resistente a los cambios. NewPipe, en Android, hace algo parecido.
 */
enum YouTubeParsing {

    /** Los videos de una página de búsqueda, en orden y sin repetidos. */
    static func videos(fromSearch json: Any) -> [OnlineVideo] {
        unique(collect("videoRenderer", in: json).compactMap(video))
    }

    /** La "ficha" para pedir la página siguiente de resultados, si hay más. */
    static func continuation(fromSearch json: Any) -> String? {
        collect("continuationCommand", in: json).compactMap { $0["token"] as? String }.first
    }

    /** Los videos de un mix ("RD" + id): la base de "Para ti", como en Android. */
    static func videos(fromMix json: Any) -> [OnlineVideo] {
        unique(collect("playlistPanelVideoRenderer", in: json).compactMap(video))
    }

    /** Las predicciones del buscador: ["lo escrito", ["predicción 1", "predicción 2", ...]]. */
    static func suggestions(from json: Any) -> [String] {
        guard let array = json as? [Any], array.count > 1, let list = array[1] as? [String] else { return [] }
        return list
    }

    /** "4:50" → 290, "1:02:03" → 3723. */
    static func seconds(fromClock clock: String) -> Int? {
        let parts = clock.split(separator: ":").map { Int($0) }
        guard !parts.isEmpty, parts.count <= 3, !parts.contains(where: { $0 == nil }) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }

    // MARK: - Piezas

    private static func video(_ node: [String: Any]) -> OnlineVideo? {
        guard let id = node["videoId"] as? String, let title = text(node["title"]), !title.isEmpty else { return nil }
        let channel = text(node["ownerText"]) ?? text(node["shortBylineText"]) ?? text(node["longBylineText"]) ?? ""
        let duration = text(node["lengthText"]).flatMap(seconds(fromClock:))
        let views = text(node["shortViewCountText"]) ?? text(node["viewCountText"])
        return OnlineVideo(id: id, title: title, channel: channel, durationSeconds: duration, views: views)
    }

    /** Los textos vienen como {"simpleText": "..."} o como {"runs": [{"text": "..."}, ...]}. */
    private static func text(_ node: Any?) -> String? {
        guard let dict = node as? [String: Any] else { return nil }
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    /** Todas las piezas llamadas [key], estén donde estén dentro de la respuesta. */
    private static func collect(_ key: String, in node: Any) -> [[String: Any]] {
        var found: [[String: Any]] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                for (k, v) in dict {
                    if k == key, let piece = v as? [String: Any] { found.append(piece) } else { walk(v) }
                }
            } else if let array = node as? [Any] {
                array.forEach(walk)
            }
        }
        walk(node)
        return found
    }

    /**
     * Sin repetidos, conservando el orden. Ojo: los diccionarios de JSON no guardan orden, así
     * que [collect] puede devolver las piezas de un mismo nivel desordenadas; dentro de las listas
     * (que es donde están los videos) el orden sí se respeta.
     */
    private static func unique(_ videos: [OnlineVideo]) -> [OnlineVideo] {
        var seen = Set<String>()
        return videos.filter { seen.insert($0.id).inserted }
    }
}
