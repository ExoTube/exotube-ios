import AVFoundation
import MediaPlayer
import UIKit

/** Algo que se puede reproducir: un video de YouTube o algo descargado. */
enum PlayItem: Equatable, Identifiable {
    case online(OnlineVideo)
    case local(MediaFile)

    var id: String {
        switch self {
        case .online(let v): return "yt:" + v.id
        case .local(let i): return "file:" + i.id
        }
    }
    var title: String {
        switch self { case .online(let v): return v.title; case .local(let i): return i.title }
    }
    var subtitle: String {
        switch self { case .online(let v): return v.channel; case .local(let i): return i.channel }
    }
    var thumbnailURL: URL? {
        switch self { case .online(let v): return v.thumbnailURL; case .local(let i): return i.thumbnailURL }
    }
    var isVideoFile: Bool { if case .local(let i) = self { return i.kind == .video }; return false }
}

/**
 * El reproductor de toda la app (uno solo, como en Android).
 *
 * - Sigue sonando con la pantalla apagada o en otra app (modo "audio" del Info.plist + la sesión
 *   de audio en .playback).
 * - Pone título, canal y portada en la pantalla de bloqueo, con sus botones.
 * - Al acabar una canción pasa sola a la siguiente de la cola.
 */
@MainActor
final class Player: ObservableObject {
    @Published private(set) var queue: [PlayItem] = []
    @Published private(set) var index = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var error: String?
    /** true = con imagen (videos de YouTube en 360p o archivos de video). */
    @Published private(set) var showsVideo = false

    let avPlayer = AVPlayer()
    var current: PlayItem? { queue.indices.contains(index) ? queue[index] : nil }

    /** Lo último que se escuchó de YouTube: la semilla de "Para ti". */
    let history = ListeningHistory()

    private var loadTask: Task<Void, Never>?
    private var artwork: MPMediaItemArtwork?

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in self?.tick(time) }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self, (note.object as? AVPlayerItem) === self.avPlayer.currentItem else { return }
                self.next()
            }
        }
        setUpRemoteCommands()
    }

    func play(_ items: [PlayItem], startAt start: Int = 0, withVideo: Bool = false) {
        queue = items
        index = max(0, min(start, items.count - 1))
        load(withVideo: withVideo)
    }

    func toggle() {
        if isPlaying { avPlayer.pause() } else { avPlayer.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func next() {
        guard index + 1 < queue.count else { avPlayer.pause(); isPlaying = false; updateNowPlaying(); return }
        index += 1
        load(withVideo: showsVideo)
    }

    func previous() {
        if position > 3 || index == 0 { seek(to: 0); return }
        index -= 1
        load(withVideo: showsVideo)
    }

    func seek(to seconds: Double) {
        avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        position = seconds
        updateNowPlaying()
    }

    /** Pasar de solo audio a con imagen (o al revés) sin perder por dónde iba. */
    func setVideo(_ on: Bool) {
        guard on != showsVideo, case .online = current else { showsVideo = on && (current?.isVideoFile ?? false); return }
        let at = position
        load(withVideo: on, resumeAt: at)
    }

    func stop() {
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        queue = []
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func load(withVideo: Bool, resumeAt: Double = 0) {
        guard let item = current else { return }
        loadTask?.cancel()
        error = nil
        isLoading = true
        position = resumeAt
        duration = 0
        artwork = nil
        loadTask = Task {
            do {
                let url: URL
                var withImage = false
                switch item {
                case .online(let video):
                    // Con imagen si se puede; si este video no tiene versión con imagen para
                    // iPhone, que al menos suene.
                    if withVideo, let videoURL = try? await StreamResolver.playableVideoURL(for: video.id) {
                        url = videoURL
                        withImage = true
                    } else {
                        url = try await StreamResolver.audioURL(for: video.id)
                    }
                    history.played(video)
                case .local(let file):
                    url = file.fileURL
                    withImage = file.kind == .video
                }
                try Task.checkCancellation()
                try? AVAudioSession.sharedInstance().setActive(true)
                // Para YouTube, la misma identificación con la que se pidió el enlace (si no, 403).
                let asset = url.isFileURL ? AVURLAsset(url: url)
                    : AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": StreamResolver.userAgent]])
                avPlayer.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                if resumeAt > 0 { await avPlayer.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600)) }
                avPlayer.play()
                showsVideo = withImage
                isPlaying = true
                isLoading = false
                updateNowPlaying()
                await loadArtwork(for: item)
            } catch is CancellationError {
            } catch {
                isLoading = false
                self.error = error.localizedDescription
            }
        }
    }

    private func tick(_ time: CMTime) {
        position = time.seconds.isFinite ? time.seconds : 0
        if let d = avPlayer.currentItem?.duration.seconds, d.isFinite, d > 0, d != duration {
            duration = d
            updateNowPlaying()
        }
    }

    // MARK: - Pantalla de bloqueo

    private func updateNowPlaying() {
        guard let item = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.subtitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for item: PlayItem) async {
        guard let url = item.thumbnailURL, let data = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: data), current == item else { return }
        artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        updateNowPlaying()
    }

    private func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == false { self?.toggle() } }; return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.toggle() } }; return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: e.positionTime) }
            return .success
        }
    }
}

/** Los últimos videos de YouTube escuchados (para "Para ti"). Se guardan en el teléfono. */
final class ListeningHistory {
    private let key = "historial"
    private let max = 30

    var recent: [OnlineVideo] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([OnlineVideo].self, from: data)) ?? []
    }

    func played(_ video: OnlineVideo) {
        var list = recent.filter { $0.id != video.id }
        list.insert(video, at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(max))) { UserDefaults.standard.set(data, forKey: key) }
    }
}
