import UIKit

/**
 * Las descargas en marcha. Cada una: buscar los enlaces → bajar por partes → (video) juntar
 * imagen y sonido → añadir a la biblioteca.
 */
@MainActor
final class Downloads: ObservableObject {

    struct Job: Identifiable, Equatable {
        enum State: Equatable { case running, failed(String), done }
        let id: String
        let video: OnlineVideo
        let kind: MediaFile.Kind
        var progress: Double = 0
        var state: State = .running
    }

    @Published private(set) var jobs: [Job] = []
    private var tasks: [String: Task<Void, Never>] = [:]
    private let library: Library

    init(library: Library) { self.library = library }

    func start(_ video: OnlineVideo, as kind: MediaFile.Kind) {
        let id = "\(video.id)-\(kind.rawValue)"
        if let job = jobs.first(where: { $0.id == id }), job.state == .running { return }
        jobs.removeAll { $0.id == id }
        jobs.insert(Job(id: id, video: video, kind: kind), at: 0)
        tasks[id] = Task { await run(id: id, video: video, kind: kind) }
    }

    func cancel(_ job: Job) {
        tasks[job.id]?.cancel()
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() { jobs.removeAll { $0.state != .running } }

    private func run(id: String, video: OnlineVideo, kind: MediaFile.Kind) async {
        // iOS pausa la app al poco de salir de ella: se pide un rato extra para terminar.
        let background = UIApplication.shared.beginBackgroundTask(withName: id)
        defer { UIApplication.shared.endBackgroundTask(background) }
        let temp = FileManager.default.temporaryDirectory
        do {
            let downloader = ChunkedDownloader()
            let fileName: String
            switch kind {
            case .audio:
                let url = try await StreamResolver.audioURL(for: video.id)
                fileName = library.freeFileName(for: video.title, extension: "m4a")
                try await downloader.download(url, to: Library.folder.appendingPathComponent(fileName)) { p in
                    Task { @MainActor in self.update(id) { $0.progress = p } }
                }
            case .video:
                let streams = try await StreamResolver.videoDownload(for: video.id)
                let v = temp.appendingPathComponent("\(id)-imagen.mp4"), a = temp.appendingPathComponent("\(id)-sonido.m4a")
                defer { try? FileManager.default.removeItem(at: v); try? FileManager.default.removeItem(at: a) }
                // El video pesa mucho más que el audio: cuenta como el 85 % del avance.
                try await downloader.download(streams.video, to: v) { p in
                    Task { @MainActor in self.update(id) { $0.progress = p * 0.85 } }
                }
                try await downloader.download(streams.audio, to: a) { p in
                    Task { @MainActor in self.update(id) { $0.progress = 0.85 + p * 0.13 } }
                }
                fileName = library.freeFileName(for: video.title, extension: "mp4")
                try await MediaMuxer.merge(video: v, audio: a, into: Library.folder.appendingPathComponent(fileName))
            }
            library.add(MediaFile(id: fileName, title: video.title, channel: video.channel, durationSeconds: video.durationSeconds,
                                    kind: kind, sourceID: video.id, addedAt: Date()))
            update(id) { $0.progress = 1; $0.state = .done }
        } catch is CancellationError {
            // la canceló el usuario: ya se quitó de la lista
        } catch {
            update(id) { $0.state = .failed(error.localizedDescription) }
        }
        tasks[id] = nil
    }

    private func update(_ id: String, _ change: (inout Job) -> Void) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[i])
    }
}
