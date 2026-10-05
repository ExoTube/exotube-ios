import SwiftUI

/** Lo que muestra Explorar, separado de la pantalla. */
@MainActor
final class ExploreModel: ObservableObject {
    enum Results: Equatable {
        case loading
        case forYou([OnlineVideo])
        case search([OnlineVideo])
        /** Se pegó un enlace de TikTok, Instagram, X o Facebook. */
        case link(URL, LinkSite, SocialInfo?)
        case failed(String)
    }

    @Published var query = ""
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var results: Results = .loading
    @Published private(set) var loadingMore = false

    private let client = YouTubeClient()
    private var continuation: String?
    private let cacheKey = "para_ti"

    /** "Para ti": los mixes de lo último escuchado. Sale al momento lo guardado y luego lo nuevo. */
    func loadForYou(history: ListeningHistory) async {
        if case .search = results { return }
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let saved = try? JSONDecoder().decode([OnlineVideo].self, from: data), !saved.isEmpty {
            results = .forYou(saved)
        }
        do {
            let seeds = history.recent.prefix(3)
            var videos: [OnlineVideo] = []
            if seeds.isEmpty {
                videos = try await client.search("música éxitos").videos   // sin historial todavía
            } else {
                let client = self.client   // copia: las tareas del grupo no corren en el hilo principal
                try await withThrowingTaskGroup(of: [OnlineVideo].self) { group in
                    for seed in seeds { group.addTask { try await client.mix(of: seed.id) } }
                    for try await mix in group { videos += mix }
                }
            }
            var seen = Set(history.recent.prefix(10).map(\.id))
            videos = videos.filter { seen.insert($0.id).inserted }
            guard !videos.isEmpty else { return }
            if case .search = results { return }
            results = .forYou(videos)
            UserDefaults.standard.set(try? JSONEncoder().encode(videos), forKey: cacheKey)
        } catch {
            if case .forYou = results { return }   // sin internet: se queda lo guardado
            results = .failed(error.localizedDescription)
        }
    }

    func search(_ text: String? = nil) async {
        let q = (text ?? query).trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        query = q
        suggestions = []
        if let link = LinkSite.detect(q) { await openLink(link.0, link.1); return }
        results = .loading
        do {
            let page = try await client.search(q)
            continuation = page.continuation
            results = .search(page.videos)
        } catch {
            results = .failed(error.localizedDescription)
        }
    }

    /**
     * Un enlace pegado en el buscador. Si es de YouTube, se muestra como un resultado más; si es
     * de otra red, yt-dlp lee la publicación (título, autor, miniatura) para enseñarla antes de
     * descargar.
     */
    private func openLink(_ url: URL, _ site: LinkSite) async {
        if case .youtube(let id) = site {
            results = .loading
            let video = await youTubeVideo(id: id, url: url)
            continuation = nil
            results = .search([video])
            return
        }
        results = .link(url, site, nil)
        do {
            results = .link(url, site, try await SocialDownloader.info(url))
        } catch {
            results = .failed(error.localizedDescription)
        }
    }

    /** Título y canal de un video de YouTube por su enlace (oEmbed, público y rápido). */
    private func youTubeVideo(id: String, url: URL) async -> OnlineVideo {
        var oembed = URLComponents(string: "https://www.youtube.com/oembed")!
        oembed.queryItems = [.init(name: "url", value: "https://www.youtube.com/watch?v=\(id)"), .init(name: "format", value: "json")]
        if let data = try? await URLSession.shared.data(from: oembed.url!).0,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return OnlineVideo(id: id, title: json["title"] as? String ?? "Video de YouTube",
                               channel: json["author_name"] as? String ?? "", durationSeconds: nil, views: nil)
        }
        return OnlineVideo(id: id, title: "Video de YouTube", channel: "", durationSeconds: nil, views: nil)
    }

    func loadMore() async {
        guard case .search(let current) = results, let token = continuation, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let page = try? await client.searchMore(token) {
            continuation = page.continuation
            let known = Set(current.map(\.id))
            results = .search(current + page.videos.filter { !known.contains($0.id) })
        }
    }

    func clearSearch(history: ListeningHistory) async {
        results = .loading
        await loadForYou(history: history)
    }

    /** Predicciones mientras se escribe. Se espera un poco entre letras para no pedir de más. */
    func updateSuggestions() async {
        let typed = query
        guard !typed.trimmingCharacters(in: .whitespaces).isEmpty else { suggestions = []; return }
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled, typed == query else { return }
        if let list = try? await client.suggestions(typed), typed == query { suggestions = Array(list.prefix(8)) }
    }
}

struct ExploreScreen: View {
    @StateObject private var model = ExploreModel()
    @EnvironmentObject private var player: Player

    var body: some View {
        NavigationStack {
            List {
                ScreenHeader(subtitle: "Videos y música en línea, sin anuncios.")
                content
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Exo.black)
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar en YouTube")
            .searchSuggestions {
                ForEach(model.suggestions, id: \.self) { s in
                    Label(s, systemImage: "magnifyingglass").searchCompletion(s)
                }
            }
            .onSubmit(of: .search) { Task { await model.search() } }
            .task(id: model.query) { await model.updateSuggestions() }
            .onChange(of: model.query) { q in
                if q.isEmpty, case .search = model.results { Task { await model.clearSearch(history: player.history) } }
            }
            .task {
                if let q = LaunchArguments.value(after: "-buscar") { await model.search(q) }
                else { await model.loadForYou(history: player.history) }
            }
            .refreshable { await model.loadForYou(history: player.history) }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.results {
        case .loading:
            HStack { Spacer(); ProgressView().tint(Exo.green); Spacer() }
                .padding(.vertical, 40).listRowBackground(Color.clear).listRowSeparator(.hidden)
        case .failed(let message):
            EmptyState(icon: "wifi.exclamationmark", text: message)
        case .forYou(let videos):
            Section {
                rows(videos)
            } header: {
                Text("Para ti").font(.headline).foregroundColor(Exo.green)
            }
        case .link(let url, let site, let info):
            LinkCard(url: url, site: site, info: info).listRowBackground(Color.clear)
        case .search(let videos):
            if videos.isEmpty {
                EmptyState(icon: "magnifyingglass", text: "No se encontró nada con «\(model.query)».")
            } else {
                rows(videos)
                if model.loadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                }
            }
        }
    }

    private func rows(_ videos: [OnlineVideo]) -> some View {
        ForEach(Array(videos.enumerated()), id: \.element.id) { i, video in
            VideoRow(video: video) {
                player.play(videos.map(PlayItem.online), startAt: i, withVideo: true)
            }
            .listRowBackground(Color.clear)
            .onAppear { if i == videos.count - 3 { Task { await model.loadMore() } } }
        }
    }
}

/** Una publicación de TikTok, Instagram, X o Facebook lista para descargar. */
struct LinkCard: View {
    let url: URL
    let site: LinkSite
    let info: SocialInfo?
    @EnvironmentObject private var downloads: Downloads
    @State private var started: MediaFile.Kind?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enlace de \(site.name)", systemImage: "link").font(.subheadline.weight(.semibold)).foregroundColor(Exo.green)
            if let info {
                HStack(alignment: .top, spacing: 12) {
                    Thumbnail(url: info.thumbnail.flatMap(URL.init(string:)), duration: info.duration.map { Int($0) }, icon: "film")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.title).font(.subheadline.weight(.medium)).lineLimit(3)
                        Text(info.uploader).font(.caption).foregroundColor(Exo.textSecondary).lineLimit(1)
                    }
                }
                if let started {
                    Label(started == .video ? "Descargando el video… míralo en la Biblioteca" : "Descargando la música… mírala en la Biblioteca",
                          systemImage: "checkmark.circle").font(.footnote).foregroundColor(Exo.green)
                } else {
                    HStack {
                        Button { start(.video) } label: { Label("Video", systemImage: "film") }.buttonStyle(.borderedProminent)
                        Button { start(.audio) } label: { Label("Música", systemImage: "music.note") }.buttonStyle(.bordered)
                    }
                    .tint(Exo.green)
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().tint(Exo.green)
                    Text("Leyendo la publicación…").font(.footnote).foregroundColor(Exo.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Exo.surfaceHigh, in: RoundedRectangle(cornerRadius: 16))
    }

    private func start(_ kind: MediaFile.Kind) {
        guard let info else { return }
        downloads.start(.link(url, info), as: kind)
        started = kind
    }
}
