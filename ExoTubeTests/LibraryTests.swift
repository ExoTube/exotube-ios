import XCTest
@testable import ExoTube

/** La biblioteca, los nombres de archivo y las descargas por partes. */
final class LibraryTests: XCTestCase {

    private func item(_ id: String, kind: LibraryItem.Kind = .audio, added: TimeInterval) -> LibraryItem {
        LibraryItem(id: id, title: id, channel: "Canal", durationSeconds: 200, kind: kind, sourceID: "abc", addedAt: Date(timeIntervalSince1970: added))
    }

    func testLoQueSeBorroDesdeArchivosDesapareceDeLaLista() {
        let index = [item("a.m4a", added: 1), item("b.m4a", added: 2)]
        let result = reconcile(index: index, files: ["b.m4a"], now: Date())
        XCTAssertEqual(result.map(\.id), ["b.m4a"])
    }

    func testLoQueSeMetioDesdeArchivosAparece() {
        let result = reconcile(index: [item("a.m4a", added: 1)], files: ["a.m4a", "Mi canción.mp3", "Clip.mp4", "notas.txt", ".biblioteca.json"],
                               now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(Set(result.map(\.id)), ["a.m4a", "Mi canción.mp3", "Clip.mp4"])
        let song = try? XCTUnwrap(result.first { $0.id == "Mi canción.mp3" })
        XCTAssertEqual(song?.title, "Mi canción")
        XCTAssertEqual(song?.kind, .audio)
        XCTAssertEqual(result.first { $0.id == "Clip.mp4" }?.kind, .video)
    }

    func testLoMasRecienteVaPrimero() {
        let result = reconcile(index: [item("viejo.m4a", added: 1), item("nuevo.m4a", added: 50)],
                               files: ["viejo.m4a", "nuevo.m4a"], now: Date())
        XCTAssertEqual(result.map(\.id), ["nuevo.m4a", "viejo.m4a"])
    }

    func testNombresDeArchivoSeguros() {
        XCTAssertEqual(safeFileName("AC/DC: Back in Black"), "AC DC Back in Black")
        XCTAssertEqual(safeFileName("¿Qué? \"Hola\" <mundo>"), "¿Qué Hola mundo")
        XCTAssertEqual(safeFileName("..."), "ExoTube")
        XCTAssertEqual(safeFileName(String(repeating: "a", count: 200)).count, 80)
    }

    func testTamanoTotalDeUnaDescargaPorPartes() {
        XCTAssertEqual(ChunkedDownloader.totalSize(fromContentRange: "bytes 0-1048575/12345678"), 12_345_678)
        XCTAssertNil(ChunkedDownloader.totalSize(fromContentRange: "bytes 0-10/*"))
        XCTAssertNil(ChunkedDownloader.totalSize(fromContentRange: nil))
    }

    func testDuracionesComoReloj() {
        XCTAssertEqual(clockText(290), "4:50")
        XCTAssertEqual(clockText(3723), "1:02:03")
        XCTAssertEqual(clockText(7), "0:07")
    }
}
