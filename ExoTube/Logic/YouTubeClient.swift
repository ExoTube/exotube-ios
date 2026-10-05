import Foundation

/** Una página de resultados y la ficha para pedir la siguiente (nil si no hay más). */
struct SearchPage {
    let videos: [OnlineVideo]
    let continuation: String?
}

enum YouTubeError: LocalizedError {
    case noConnection
    case unexpectedAnswer

    var errorDescription: String? {
        switch self {
        case .noConnection: return "Sin conexión. Revisa tu internet e inténtalo otra vez."
        case .unexpectedAnswer: return "YouTube respondió algo raro. Inténtalo en un momento."
        }
    }
}

/**
 * Búsqueda, predicciones y "Para ti", hablando directamente con YouTube como lo hace
 * youtube.com en el navegador (la API "InnerTube"). Sin cuentas ni llaves: es pública.
 * La lectura de las respuestas está en [YouTubeParsing], que tiene sus pruebas.
 */
struct YouTubeClient {
    var session: URLSession = .shared

    private static let base = URL(string: "https://www.youtube.com/youtubei/v1/")!
    private static let context: [String: Any] = [
        "client": ["clientName": "WEB", "clientVersion": "2.20260101.00.00", "hl": "es", "gl": "PE"],
    ]

    func search(_ query: String) async throws -> SearchPage {
        let json = try await post("search", ["query": query])
        return SearchPage(videos: YouTubeParsing.videos(fromSearch: json), continuation: YouTubeParsing.continuation(fromSearch: json))
    }

    func searchMore(_ continuation: String) async throws -> SearchPage {
        let json = try await post("search", ["continuation": continuation])
        return SearchPage(videos: YouTubeParsing.videos(fromSearch: json), continuation: YouTubeParsing.continuation(fromSearch: json))
    }

    /** El mix de un video: lo que YouTube pondría a continuación. Es la base de "Para ti". */
    func mix(of videoID: String) async throws -> [OnlineVideo] {
        let json = try await post("next", ["videoId": videoID, "playlistId": "RD" + videoID])
        return YouTubeParsing.videos(fromMix: json).filter { $0.id != videoID }
    }

    /** Las predicciones mientras se escribe en el buscador. */
    func suggestions(_ text: String) async throws -> [String] {
        var url = URLComponents(string: "https://suggestqueries.google.com/complete/search")!
        url.queryItems = [.init(name: "client", value: "firefox"), .init(name: "ds", value: "yt"),
                          .init(name: "hl", value: "es"), .init(name: "q", value: text)]
        let (data, _) = try await load(URLRequest(url: url.url!))
        return YouTubeParsing.suggestions(from: try JSONSerialization.jsonObject(with: data))
    }

    private func post(_ endpoint: String, _ body: [String: Any]) async throws -> Any {
        var request = URLRequest(url: URL(string: endpoint + "?prettyPrint=false", relativeTo: Self.base)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload = body
        payload["context"] = Self.context
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await load(request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw YouTubeError.unexpectedAnswer }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(error.code) {
            throw YouTubeError.noConnection
        }
    }
}
