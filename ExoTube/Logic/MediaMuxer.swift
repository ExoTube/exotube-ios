import AVFoundation

/**
 * Junta la imagen y el sonido (que YouTube da por separado) en un solo MP4, sin volver a
 * comprimir nada: solo se copian las pistas tal cual ("passthrough"), así que es rápido y no
 * pierde calidad.
 */
enum MediaMuxer {

    enum Failure: LocalizedError {
        case missingTrack, exportFailed(String)
        var errorDescription: String? {
            switch self {
            case .missingTrack: return "El video descargado vino incompleto."
            case .exportFailed(let why): return "No se pudo armar el video: \(why)"
            }
        }
    }

    static func merge(video: URL, audio: URL, into output: URL) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let audioAsset = AVURLAsset(url: audio)
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first
        else { throw Failure.missingTrack }

        let duration = try await videoAsset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: duration)
        let v = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try v?.insertTimeRange(range, of: videoTrack, at: .zero)
        v?.preferredTransform = try await videoTrack.load(.preferredTransform)
        let audioDuration = try await audioAsset.load(.duration)
        let a = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try a?.insertTimeRange(CMTimeRange(start: .zero, duration: min(duration, audioDuration)), of: audioTrack, at: .zero)

        try? FileManager.default.removeItem(at: output)
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw Failure.exportFailed("el iPhone no lo permite")
        }
        export.outputURL = output
        export.outputFileType = .mp4
        await export.export()
        if export.status != .completed {
            throw Failure.exportFailed(export.error?.localizedDescription ?? "estado \(export.status.rawValue)")
        }
    }
}
