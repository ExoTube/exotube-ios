import Foundation
import YouTubeKit

/**
 * Elige qué enlace de YouTube usar para escuchar, ver o descargar. Es el único archivo que habla
 * con YouTubeKit, así que si algún día hay que cambiar de biblioteca, se cambia aquí.
 *
 * YouTube separa casi siempre la imagen y el sonido ("adaptativo"); solo da video CON sonido
 * ("progresivo") en calidad baja, 360p. Por eso:
 *  - para escuchar: solo el audio, en M4A (AAC), que el iPhone reproduce sin más;
 *  - para ver: el progresivo, que se reproduce directo;
 *  - para descargar video: la mejor imagen hasta 1080p + el mejor audio, que luego se juntan en
 *    un solo MP4 dentro del teléfono (ver [MediaMuxer]).
 */
enum StreamResolver {

    struct VideoDownload {
        let video: URL
        let audio: URL
        let height: Int
    }

    enum Failure: LocalizedError {
        case nothingPlayable
        var errorDescription: String? { "Este video no se puede reproducir en iPhone." }
    }

    static func audioURL(for videoID: String) async throws -> URL {
        let streams = try await YouTube(videoID: videoID).streams
        guard let best = streams.filterAudioOnly().filter({ $0.fileExtension == .m4a && $0.isNativelyPlayable })
            .highestAudioBitrateStream() else { throw Failure.nothingPlayable }
        return best.url
    }

    static func playableVideoURL(for videoID: String) async throws -> URL {
        let streams = try await YouTube(videoID: videoID).streams
        guard let best = streams.filterVideoAndAudio().filter(\.isNativelyPlayable).highestResolutionStream()
        else { throw Failure.nothingPlayable }
        return best.url
    }

    static func videoDownload(for videoID: String, maxHeight: Int = 1080) async throws -> VideoDownload {
        let streams = try await YouTube(videoID: videoID).streams
        let videos = streams.filterVideoOnly()
            .filter { $0.fileExtension == .mp4 && $0.isNativelyPlayable && ($0.videoResolution ?? 0) <= maxHeight }
        guard let video = videos.highestResolutionStream(),
              let audio = streams.filterAudioOnly().filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream()
        else { throw Failure.nothingPlayable }
        return VideoDownload(video: video.url, audio: audio.url, height: video.videoResolution ?? 0)
    }
}
