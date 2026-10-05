import UIKit

/**
 * Las descargas en marcha.
 *  - YouTube: buscar los enlaces (YouTubeKit) → bajar por partes → (video) juntar imagen y sonido.
 *  - TikTok, Instagram, X y Facebook: yt-dlp baja el video → (música) se le saca el sonido.
 * Al terminar, todo va a la biblioteca.
 */
@MainActor
final class Downloads: ObservableObject {

    enum Source: Equatable {
        case youtube(OnlineVideo)
        case link(URL, SocialInfo)
    }

    struct Job: Identifiable, Equatable {
        enum State: Equatable { case running, failed(String), done }
        let id: String
        let source: Source
        let kind: MediaFile.Kind
        var progress: Double = 0
        var state: State = .running

        var title: String {
            switch source { case .youtube(let v): return v.title; case .link(_, let i): return i.title }
        }
        var thumbnailURL: URL? {
            switch source {
            case .youtube(let v): return v.thumbnailURL
            case .link(_, let i): return i.thumbnail.flatMap(URL.init(string:))
            }
        }
    }

    @Published private(set) var jobs: [Job] = []
    private var tasks: [String: Task<Void, Never>] = [:]
    private let library: Library

    init(library: Library) { self.library = library }

    func start(_ video: OnlineVideo, as kind: MediaFile.Kind) { start(.youtube(video), as: kind) }

    func start(_ source: Source, as kind: MediaFile.Kind) {
        let key: String
        switch source {
        case .youtube(let v): key = v.id
        case .link(let url, _): key = url.absoluteString
        }
        let id = "\(key)-\(kind.rawValue)"
        if let job = jobs.first(where: { $0.id == id }), job.state == .running { return }
        jobs.removeAll { $0.id == id }
        jobs.insert(Job(id: id, source: source, kind: kind), at: 0)
        tasks[id] = Task { await run(id: id, source: source, kind: kind) }
    }

    func retry(_ job: Job) { start(job.source, as: job.kind) }

    func cancel(_ job: Job) {
        tasks[job.id]?.cancel()
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() { jobs.removeAll { $0.state != .running } }

    private func run(id: String, source: Source, kind: MediaFile.Kind) async {
        // iOS pausa la app al poco de salir de ella: se pide un rato extra para terminar.
        let background = UIApplication.shared.beginBackgroundTask(withName: id)
        defer { UIApplication.shared.endBackgroundTask(background) }
        let report: (Double) -> Void = { p in Task { @MainActor in self.update(id) { $0.progress = p } } }
        do {
            let item: MediaFile
            switch source {
            case .youtube(let video): item = try await downloadFromYouTube(video, kind: kind, progress: report)
            case .link(let url, _): item = try await downloadLink(url, kind: kind, progress: report)
            }
            library.add(item)
            update(id) { $0.progress = 1; $0.state = .done }
        } catch is CancellationError {
            // la canceló el usuario: ya se quitó de la lista
        } catch {
            update(id) { $0.state = .failed(error.localizedDescription) }
        }
        tasks[id] = nil
    }

    private func downloadFromYouTube(_ video: OnlineVideo, kind: MediaFile.Kind, progress: @escaping (Double) -> Void) async throws -> MediaFile {
        let downloader = ChunkedDownloader()
        let fileName: String
        switch kind {
        case .audio:
            let url = try await StreamResolver.audioURL(for: video.id)
            fileName = library.freeFileName(for: video.title, extension: "m4a")
            try await downloader.download(url, to: Library.folder.appendingPathComponent(fileName), progress: progress)
        case .video:
            let streams = try await StreamResolver.videoDownload(for: video.id)
            let temp = FileManager.default.temporaryDirectory
            let v = temp.appendingPathComponent("\(video.id)-imagen.mp4"), a = temp.appendingPathComponent("\(video.id)-sonido.m4a")
            defer { try? FileManager.default.removeItem(at: v); try? FileManager.default.removeItem(at: a) }
            // El video pesa mucho más que el audio: cuenta como el 85 % del avance.
            try await downloader.download(streams.video, to: v) { progress($0 * 0.85) }
            try await downloader.download(streams.audio, to: a) { progress(0.85 + $0 * 0.13) }
            fileName = library.freeFileName(for: video.title, extension: "mp4")
            try await MediaMuxer.merge(video: v, audio: a, into: Library.folder.appendingPathComponent(fileName))
        }
        return MediaFile(id: fileName, title: video.title, channel: video.channel, durationSeconds: video.durationSeconds,
                         kind: kind, sourceID: video.id, addedAt: Date())
    }

    private func downloadLink(_ url: URL, kind: MediaFile.Kind, progress: @escaping (Double) -> Void) async throws -> MediaFile {
        let info = try await SocialDownloader.download(url) { progress($0 * (kind == .audio ? 0.9 : 1)) }
        guard let path = info.path else { throw PythonRuntime.Failure(message: "yt-dlp no dijo dónde quedó el archivo.") }
        let downloaded = URL(fileURLWithPath: path)
        defer { try? FileManager.default.removeItem(at: downloaded.deletingLastPathComponent()) }
        let title = info.title.isEmpty ? "\(info.site) \(info.id ?? "")" : info.title
        let fileName: String
        switch kind {
        case .audio:
            fileName = library.freeFileName(for: title, extension: "m4a")
            try await SocialDownloader.extractAudio(from: downloaded, to: Library.folder.appendingPathComponent(fileName))
        case .video:
            fileName = library.freeFileName(for: title, extension: downloaded.pathExtension.isEmpty ? "mp4" : downloaded.pathExtension)
            try FileManager.default.moveItem(at: downloaded, to: Library.folder.appendingPathComponent(fileName))
        }
        return MediaFile(id: fileName, title: title, channel: info.uploader, durationSeconds: info.duration.map { Int($0) },
                         kind: kind, sourceID: nil, addedAt: Date(), thumbnail: info.thumbnail)
    }

    private func update(_ id: String, _ change: (inout Job) -> Void) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[i])
    }
}
