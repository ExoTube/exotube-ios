import Foundation

/**
 * Compara dos versiones escritas como "1.2" o "v1.10". Es la misma regla que en Android
 * (data/update/VersionNames.kt), para avisar de versiones nuevas.
 *
 * Se compara por NÚMERO y no por texto: como texto, "1.10" sería menor que "1.9".
 *  - se ignora la "v" de la etiqueta de la publicación;
 *  - las partes que falten cuentan como cero ("1.2" y "1.2.0" son la misma);
 *  - si algo no es un número, se responde que NO hay novedad: mejor no avisar que mandar a
 *    instalar algo raro.
 */
func isNewerVersion(_ remote: String, than local: String) -> Bool {
    guard let r = versionParts(remote), let l = versionParts(local) else { return false }
    for i in 0..<max(r.count, l.count) {
        let a = i < r.count ? r[i] : 0
        let b = i < l.count ? l[i] : 0
        if a != b { return a > b }
    }
    return false
}

private func versionParts(_ version: String) -> [Int]? {
    var cleaned = version.trimmingCharacters(in: .whitespaces)
    if cleaned.hasPrefix("v") || cleaned.hasPrefix("V") { cleaned.removeFirst() }
    guard !cleaned.isEmpty else { return nil }
    var parts: [Int] = []
    for piece in cleaned.split(separator: ".", omittingEmptySubsequences: false) {
        guard let n = Int(piece) else { return nil }
        parts.append(n)
    }
    return parts
}
