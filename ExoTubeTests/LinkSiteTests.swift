import XCTest
@testable import ExoTube

/** Reconocer de qué red es un enlace pegado en el buscador (como LinkSites en Android). */
final class LinkSiteTests: XCTestCase {

    private func site(_ text: String) -> LinkSite? { LinkSite.detect(text)?.1 }

    func testEnlacesDeYouTubeDanElIdDelVideo() {
        XCTAssertEqual(site("https://www.youtube.com/watch?v=OX-us7PEfkc&t=30"), .youtube(videoID: "OX-us7PEfkc"))
        XCTAssertEqual(site("https://youtu.be/OX-us7PEfkc?si=abc"), .youtube(videoID: "OX-us7PEfkc"))
        XCTAssertEqual(site("https://m.youtube.com/shorts/OX-us7PEfkc"), .youtube(videoID: "OX-us7PEfkc"))
        XCTAssertEqual(site("https://music.youtube.com/watch?v=OX-us7PEfkc"), .youtube(videoID: "OX-us7PEfkc"))
        XCTAssertNil(site("https://www.youtube.com/@SodaStereo"), "un canal no es un video")
    }

    func testEnlacesDeLasOtrasRedes() {
        XCTAssertEqual(site("https://www.tiktok.com/@scout2015/video/6718335390845095173"), .tiktok)
        XCTAssertEqual(site("https://vm.tiktok.com/ZMabc123/"), .tiktok)
        XCTAssertEqual(site("https://www.instagram.com/reel/Chunk8-jurw/"), .instagram)
        XCTAssertEqual(site("https://x.com/starwars/status/665052190608723968"), .x)
        XCTAssertEqual(site("https://twitter.com/i/status/123"), .x)
        XCTAssertEqual(site("https://www.facebook.com/watch/?v=274175099429670"), .facebook)
        XCTAssertEqual(site("https://fb.watch/abc/"), .facebook)
    }

    func testSinHttpYConEspaciosTambien() {
        XCTAssertEqual(site("  x.com/starwars/status/665052190608723968 \n"), .x)
    }

    func testUnaBusquedaNormalNoEsUnEnlace() {
        XCTAssertNil(site("soda stereo"))
        XCTAssertNil(site("https://www.google.com/search?q=soda"))
    }

    func testAvanceDeYtDlp() {
        XCTAssertEqual(SocialDownloader.parseProgress("1048576 4194304"), 0.25)
        XCTAssertNil(SocialDownloader.parseProgress("100 0"), "sin tamaño total no se sabe el avance")
        XCTAssertNil(SocialDownloader.parseProgress(""))
    }
}
