import AVKit
import SwiftUI

/** La barra de abajo con lo que suena. Al tocarla se abre "Reproduciendo". */
struct MiniPlayer: View {
    let onOpen: () -> Void
    @EnvironmentObject private var player: Player

    var body: some View {
        if let item = player.current {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        Thumbnail(url: item.thumbnailURL, width: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.footnote.weight(.semibold)).lineLimit(1)
                            Text(player.error ?? item.subtitle).font(.caption2)
                                .foregroundColor(player.error == nil ? Exo.textSecondary : .red).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                if player.isLoading {
                    ProgressView().tint(Exo.green)
                } else {
                    Button(action: player.toggle) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                    }
                    .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
                }
                Button(action: player.next) { Image(systemName: "forward.fill").font(.title3) }
                    .accessibilityLabel("Siguiente")
            }
            .foregroundColor(Exo.textPrimary)
            .padding(10)
            .background(Exo.surfaceHigh, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
        }
    }
}

/** La pantalla grande del reproductor: imagen o video, barra de tiempo y botones. */
struct NowPlayingView: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var downloads: Downloads
    @Environment(\.dismiss) private var dismiss
    @State private var dragging: Double?

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Exo.outline).frame(width: 40, height: 5).padding(.top, 8)
            if let item = player.current {
                artwork(item)
                VStack(spacing: 4) {
                    Text(item.title).font(.title3.weight(.bold)).multilineTextAlignment(.center).lineLimit(3)
                    Text(item.subtitle).font(.subheadline).foregroundColor(Exo.green)
                }
                if let error = player.error { Text(error).font(.footnote).foregroundColor(.red) }
                timeline
                controls
                if case .online(let video) = item { extras(video) }
            } else {
                Spacer()
                Text("No hay nada sonando").foregroundColor(Exo.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Exo.black.ignoresSafeArea())
    }

    @ViewBuilder private func artwork(_ item: PlayItem) -> some View {
        if player.showsVideo {
            VideoPlayer(player: player.avPlayer)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            AsyncImage(url: item.thumbnailURL) { $0.resizable().scaledToFill() } placeholder: {
                ZStack { Exo.surfaceHigh; Image(systemName: "music.note").font(.system(size: 60)).foregroundColor(Exo.green) }
            }
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private var timeline: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(get: { dragging ?? player.position }, set: { dragging = $0 }),
                   in: 0...max(player.duration, 1)) { editing in
                if !editing, let to = dragging { player.seek(to: to); dragging = nil }
            }
            HStack {
                Text(clockText(Int(dragging ?? player.position)))
                Spacer()
                Text(player.duration > 0 ? clockText(Int(player.duration)) : "--:--")
            }
            .font(.caption.monospacedDigit()).foregroundColor(Exo.textSecondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 44) {
            Button(action: player.previous) { Image(systemName: "backward.fill").font(.title) }
                .accessibilityLabel("Anterior")
            Button(action: player.toggle) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34)).foregroundColor(Exo.ink)
                    .frame(width: 76, height: 76).background(Exo.green, in: Circle())
            }
            .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
            Button(action: player.next) { Image(systemName: "forward.fill").font(.title) }
                .accessibilityLabel("Siguiente")
        }
        .foregroundColor(Exo.textPrimary)
    }

    private func extras(_ video: OnlineVideo) -> some View {
        HStack(spacing: 12) {
            Button { player.setVideo(!player.showsVideo) } label: {
                Label(player.showsVideo ? "Solo audio" : "Ver video", systemImage: player.showsVideo ? "music.note" : "play.rectangle")
            }
            Menu {
                Button("Música (M4A)") { downloads.start(video, as: .audio) }
                Button("Video (MP4, hasta 1080p)") { downloads.start(video, as: .video) }
            } label: { Label("Descargar", systemImage: "arrow.down.circle") }
        }
        .buttonStyle(.bordered)
        .tint(Exo.green)
    }
}
