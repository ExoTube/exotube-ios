import SwiftUI

/** 290 → "4:50", 3723 → "1:02:03". */
func clockText(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

/** Una miniatura con esquinas redondeadas y la duración encima, como en YouTube. */
struct Thumbnail: View {
    let url: URL?
    var duration: Int?
    var icon = "music.note"
    var width: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack { Exo.surfaceHigh; Image(systemName: icon).foregroundColor(Exo.green) }
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            if let duration {
                Text(clockText(duration))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
    }
}

/** Un video de YouTube en una lista: miniatura, título, canal y el botón de descargar. */
struct VideoRow: View {
    let video: OnlineVideo
    let onPlay: () -> Void
    @EnvironmentObject private var downloads: Downloads
    @State private var asksFormat = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    Thumbnail(url: video.thumbnailURL, duration: video.durationSeconds)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title).font(.subheadline.weight(.medium)).lineLimit(2).foregroundColor(Exo.textPrimary)
                        Text(video.channel).font(.caption).foregroundColor(Exo.green).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            Button { asksFormat = true } label: {
                Image(systemName: "arrow.down.circle").font(.title2).foregroundColor(Exo.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Descargar")
        }
        .confirmationDialog("Descargar «\(video.title)»", isPresented: $asksFormat, titleVisibility: .visible) {
            Button("Música (M4A)") { downloads.start(video, as: .audio) }
            Button("Video (MP4, hasta 1080p)") { downloads.start(video, as: .video) }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

/** Algo descargado en una lista. */
struct LibraryRow: View {
    let item: MediaFile

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(url: item.thumbnailURL, duration: item.durationSeconds,
                      icon: item.kind == .video ? "film" : "music.note", width: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2).foregroundColor(Exo.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: item.kind == .video ? "film" : "music.note").font(.caption2)
                    Text(item.channel.isEmpty ? (item.kind == .video ? "Video" : "Audio") : item.channel).lineLimit(1)
                }
                .font(.caption).foregroundColor(Exo.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

/** Una descarga en marcha (o que falló) en lo alto de la Biblioteca. */
struct DownloadRow: View {
    let job: Downloads.Job
    @EnvironmentObject private var downloads: Downloads

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(url: job.thumbnailURL, width: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(job.title).font(.footnote.weight(.medium)).lineLimit(1)
                switch job.state {
                case .running:
                    ProgressView(value: job.progress).tint(Exo.green)
                    Text(job.kind == .video ? "Descargando video… \(Int(job.progress * 100)) %" : "Descargando música… \(Int(job.progress * 100)) %")
                        .font(.caption2).foregroundColor(Exo.textSecondary)
                case .failed(let why):
                    Text(why).font(.caption2).foregroundColor(.red).lineLimit(2)
                case .done:
                    Text("Listo").font(.caption2).foregroundColor(Exo.green)
                }
            }
            if case .failed = job.state {
                Button("Reintentar") { downloads.retry(job) }.font(.caption).buttonStyle(.bordered)
            } else if job.state == .running {
                Button { downloads.cancel(job) } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Exo.textSecondary) }
                    .buttonStyle(.plain)
            }
        }
    }
}
