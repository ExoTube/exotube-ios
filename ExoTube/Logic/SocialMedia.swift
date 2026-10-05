import AVFoundation
import Foundation

/** De qué red es un enlace pegado en el buscador. */
enum LinkSite: Equatable {
    case youtube(videoID: String)
    case tiktok, instagram, x, facebook

    var name: String {
        switch self {
        case .youtube: return "YouTube"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .x: return "X"
        case .facebook: return "Facebook"
        }
    }

    /** nil si el texto no es un enlace de una red que ExoTube sepa descargar. */
    static func detect(_ text: String) -> (URL, LinkSite)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed.hasPrefix("http") ? trimmed : "https://" + trimmed),
              var host = url.host?.lowercased(), host.contains(".") else { return nil }
        for prefix in ["www.", "m.", "mobile.", "music."] where host.hasPrefix(prefix) { host.removeFirst(prefix.count) }
        switch host {
        case "youtu.be":
            let id = url.pathComponents.dropFirst().first ?? ""
            return id.count == 11 ? (url, .youtube(videoID: id)) : nil
        case "youtube.com":
            if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value, v.count == 11 {
                return (url, .youtube(videoID: v))
            }
            let parts = url.pathComponents
            if parts.count >= 3, ["shorts", "live", "embed"].contains(parts[1]), parts[2].count == 11 { return (url, .youtube(videoID: parts[2])) }
            return nil
        case "tiktok.com", "vm.tiktok.com", "vt.tiktok.com": return (url, .tiktok)
        case "instagram.com": return (url, .instagram)
        case "x.com", "twitter.com": return (url, .x)
        case "facebook.com", "fb.watch", "fb.com": return (url, .facebook)
        default: return nil
        }
    }
}

/** Lo que yt-dlp sabe de una publicación antes de descargarla. */
struct SocialInfo: Codable, Equatable {
    let id: String?
    let title: String
    let uploader: String
    let duration: Double?
    let thumbnail: String?
    let site: String
    var path: String?
}

/**
 * Python vive en una sola cola: arrancarlo y llamarlo siempre desde el mismo sitio evita líos con
 * su candado interno (GIL). yt-dlp tarda segundos: nunca se llama desde el hilo de la pantalla.
 */
enum PythonRuntime {
    private static let queue = DispatchQueue(label: "exotube.python")

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func call(_ request: [String: Any]) async throws -> Any {
        let json = String(data: try JSONSerialization.data(withJSONObject: request), encoding: .utf8)!
        let answer: String = await withCheckedContinuation { done in
            queue.async { done.resume(returning: PythonBridge.call(json)) }
        }
        guard let object = try JSONSerialization.jsonObject(with: Data(answer.utf8)) as? [String: Any] else {
            throw Failure(message: "Respuesta rara de yt-dlp")
        }
        guard object["ok"] as? Bool == true else {
            throw Failure(message: object["error"] as? String ?? "Algo falló al leer el enlace.")
        }
        return object["result"] ?? [:]
    }
}

/** TikTok, Instagram, X y Facebook con yt-dlp (el mismo motor que la app de Android). */
enum SocialDownloader {

    static func version() async throws -> String {
        let result = try await PythonRuntime.call(["action": "version"]) as? [String: Any]
        return "yt-dlp \(result?["yt_dlp"] ?? "?") · Python \(result?["python"] ?? "?")"
    }

    static func info(_ url: URL) async throws -> SocialInfo {
        let result = try await PythonRuntime.call(["action": "info", "url": url.absoluteString])
        return try JSONDecoder().decode(SocialInfo.self, from: JSONSerialization.data(withJSONObject: result))
    }

    /** Descarga el video a una carpeta temporal. [progress] de 0 a 1. */
    static func download(_ url: URL, progress: @escaping (Double) -> Void) async throws -> SocialInfo {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let progressFile = folder.appendingPathComponent("avance.txt")
        // yt-dlp apunta su avance en un archivo pequeño; aquí se lee cada medio segundo.
        let watcher = Task {
            while !Task.isCancelled {
                if let text = try? String(contentsOf: progressFile), let p = parseProgress(text) { progress(p) }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        defer { watcher.cancel() }
        let result = try await PythonRuntime.call(["action": "download", "url": url.absoluteString,
                                                   "folder": folder.path, "progress_file": progressFile.path])
        progress(1)
        return try JSONDecoder().decode(SocialInfo.self, from: JSONSerialization.data(withJSONObject: result))
    }

    /** "1048576 4194304" → 0.25. */
    static func parseProgress(_ text: String) -> Double? {
        let parts = text.split(separator: " ").compactMap { Double($0) }
        guard parts.count == 2, parts[1] > 0 else { return nil }
        return min(1, parts[0] / parts[1])
    }

    /** Saca el sonido de un video a un M4A, con las herramientas del propio iPhone. */
    static func extractAudio(from video: URL, to output: URL) async throws {
        let asset = AVURLAsset(url: video)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw PythonRuntime.Failure(message: "No se pudo sacar el audio de este video.")
        }
        try? FileManager.default.removeItem(at: output)
        export.outputURL = output
        export.outputFileType = .m4a
        await export.export()
        if export.status != .completed {
            throw PythonRuntime.Failure(message: export.error?.localizedDescription ?? "No se pudo sacar el audio.")
        }
    }
}
