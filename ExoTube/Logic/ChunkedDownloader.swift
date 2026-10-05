import Foundation

/**
 * Descarga un archivo en trozos de 10 MB.
 *
 * YouTube frena las descargas que piden el archivo entero de una vez (las deja a la velocidad
 * de reproducción); pidiéndolo por partes ("Range") va a toda velocidad. yt-dlp hace lo mismo.
 */
struct ChunkedDownloader {
    var session: URLSession = .shared
    var chunkSize: Int64 = 10 * 1024 * 1024
    var userAgent: String? = nil

    enum Failure: LocalizedError {
        case badAnswer(Int)
        var errorDescription: String? {
            switch self {
            case .badAnswer(let code): return "La descarga falló (código \(code)). Inténtalo otra vez."
            }
        }
    }

    /** Descarga [url] en [destination]. [progress] recibe de 0 a 1. */
    func download(_ url: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        do {
            try await fill(handle, from: url, progress: progress)
        } catch {
            // Que no quede un archivo a medias (o vacío) en la biblioteca.
            try? handle.close()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private func fill(_ handle: FileHandle, from url: URL, progress: @escaping (Double) -> Void) async throws {
        var start: Int64 = 0
        var total: Int64?
        repeat {
            try Task.checkCancellation()
            var request = URLRequest(url: url)
            request.setValue("bytes=\(start)-\(start + chunkSize - 1)", forHTTPHeaderField: "Range")
            if let userAgent { request.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 206 || http.statusCode == 200 else {
                throw Failure.badAnswer((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            try handle.write(contentsOf: data)
            start += Int64(data.count)
            if http.statusCode == 200 {
                total = start   // el servidor ignoró "Range" y mandó todo de una vez
            } else if total == nil {
                total = Self.totalSize(fromContentRange: http.value(forHTTPHeaderField: "Content-Range"))
            }
            if let total, total > 0 { progress(min(1, Double(start) / Double(total))) }
            if data.isEmpty { break }
        } while start < (total ?? 0)
        progress(1)
    }

    /** "bytes 0-1048575/12345678" → 12345678. */
    static func totalSize(fromContentRange header: String?) -> Int64? {
        guard let header, let slash = header.lastIndex(of: "/") else { return nil }
        return Int64(header[header.index(after: slash)...].trimmingCharacters(in: .whitespaces))
    }
}

/** Un nombre de archivo seguro a partir de un título: sin "/", ":" ni otros caracteres prohibidos. */
func safeFileName(_ title: String, maxLength: Int = 80) -> String {
    let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
    let cleaned = title.components(separatedBy: forbidden).joined(separator: " ")
        .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    let short = String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    return short.isEmpty ? "ExoTube" : short
}
