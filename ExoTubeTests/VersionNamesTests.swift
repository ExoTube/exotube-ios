import XCTest
@testable import ExoTube

/** Las mismas pruebas que en Android (UpdateLogicTest): las dos apps deben decidir igual. */
final class VersionNamesTests: XCTestCase {

    func testUnaVersionPosteriorEsMasNueva() {
        XCTAssertTrue(isNewerVersion("1.2", than: "1.1"))
        XCTAssertFalse(isNewerVersion("1.1", than: "1.2"))
    }

    /** Como texto, "1.10" es menor que "1.9": por número no. */
    func testLa110EsPosteriorALa19() {
        XCTAssertTrue(isNewerVersion("1.10", than: "1.9"))
        XCTAssertFalse(isNewerVersion("1.9", than: "1.10"))
    }

    func testSeIgnoraLaVDeLaEtiqueta() {
        XCTAssertTrue(isNewerVersion("v1.2", than: "1.1"))
        XCTAssertFalse(isNewerVersion("v1.1", than: "1.1"))
    }

    func testLasPartesQueFaltanCuentanComoCero() {
        XCTAssertFalse(isNewerVersion("1.2.0", than: "1.2"))
        XCTAssertTrue(isNewerVersion("1.8.1", than: "1.8"))
    }

    func testUnaEtiquetaQueNoSonNumerosNoCuenta() {
        XCTAssertFalse(isNewerVersion("beta", than: "1.1"))
        XCTAssertFalse(isNewerVersion("v1.2-rc1", than: "1.1"))
        XCTAssertFalse(isNewerVersion("", than: "1.1"))
    }
}
