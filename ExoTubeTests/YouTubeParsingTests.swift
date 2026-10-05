import XCTest
@testable import ExoTube

/** Respuestas de verdad de YouTube (guardadas en Fixtures): lo que la app tiene que entender. */
final class YouTubeParsingTests: XCTestCase {

    private func fixture(_ name: String) throws -> Any {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "falta \(name).json")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    }

    func testLaBusquedaDaLosVideosConSusDatos() throws {
        let videos = YouTubeParsing.videos(fromSearch: try fixture("youtube-busqueda"))

        XCTAssertGreaterThanOrEqual(videos.count, 15)
        let first = try XCTUnwrap(videos.first { $0.id == "OX-us7PEfkc" })
        XCTAssertEqual(first.title, "Soda Stereo - De Musica Ligera (El Último Concierto)")
        XCTAssertEqual(first.channel, "Soda Stereo")
        XCTAssertEqual(first.durationSeconds, 290)
        XCTAssertEqual(first.thumbnailURL.absoluteString, "https://i.ytimg.com/vi/OX-us7PEfkc/hqdefault.jpg")
    }

    func testLaBusquedaNoRepiteVideos() throws {
        let videos = YouTubeParsing.videos(fromSearch: try fixture("youtube-busqueda"))
        XCTAssertEqual(videos.count, Set(videos.map(\.id)).count)
    }

    func testLaBusquedaTraeLaFichaParaMasResultados() throws {
        XCTAssertNotNil(YouTubeParsing.continuation(fromSearch: try fixture("youtube-busqueda")))
    }

    func testElMixDaLosVideosDeParaTi() throws {
        let videos = YouTubeParsing.videos(fromMix: try fixture("youtube-mix"))

        XCTAssertGreaterThanOrEqual(videos.count, 20)
        let furia = try XCTUnwrap(videos.first { $0.id == "VoGwvVoaoCw" })
        XCTAssertEqual(furia.title, "Soda Stereo - En La Ciudad De La Furia (Gira Me Verás Volver)")
        XCTAssertEqual(furia.channel, "Soda Stereo")
        XCTAssertEqual(furia.durationSeconds, 401)
    }

    func testLasPrediccionesDelBuscador() throws {
        let json = try JSONSerialization.jsonObject(with: Data(#"["soda",["soda pop","soda stereo"],[],{}]"#.utf8))
        XCTAssertEqual(YouTubeParsing.suggestions(from: json), ["soda pop", "soda stereo"])
        XCTAssertEqual(YouTubeParsing.suggestions(from: [String: Any]()), [])
    }

    func testDuracionesEscritasComoReloj() {
        XCTAssertEqual(YouTubeParsing.seconds(fromClock: "4:50"), 290)
        XCTAssertEqual(YouTubeParsing.seconds(fromClock: "1:02:03"), 3723)
        XCTAssertEqual(YouTubeParsing.seconds(fromClock: "0:07"), 7)
        XCTAssertNil(YouTubeParsing.seconds(fromClock: "EN VIVO"))
    }
}
