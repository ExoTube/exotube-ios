import SwiftUI

/**
 * Los colores de ExoTube, los mismos que en Android: verde sobre negro.
 * Los nombres siguen a los de Android (ui/theme/Color.kt) para que sea fácil comparar.
 */
enum Exo {
    static let green = Color(hex: 0x2EE67A)
    static let greenDeep = Color(hex: 0x0F3D22)
    static let black = Color(hex: 0x000000)
    static let ink = Color(hex: 0x00210D)          // texto sobre verde
    static let surfaceLow = Color(hex: 0x0B110D)
    static let surfaceMid = Color(hex: 0x101813)
    static let surfaceHigh = Color(hex: 0x16201A)
    static let textPrimary = Color(hex: 0xE6EEE8)
    static let textSecondary = Color(hex: 0x9FB3A6)
    static let outline = Color(hex: 0x3F5046)
}

extension Color {
    /** Un color escrito como en la web: Color(hex: 0x2EE67A). */
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/** El logotipo de texto: "Exo" en blanco y "Tube" en verde, como arriba en la app de Android. */
struct ExoWordmark: View {
    var size: CGFloat = 34

    var body: some View {
        (Text("Exo").foregroundColor(Exo.textPrimary) + Text("Tube").foregroundColor(Exo.green))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .accessibilityLabel("ExoTube")
    }
}
