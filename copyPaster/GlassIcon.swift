import SwiftUI

extension View {
    /// Circular Liquid Glass icon used for every icon button in the app.
    /// Plain glass with a secondary glyph by default, like a native toolbar button.
    /// Pass a `tint` only for primary or "on" states: the glass takes the color and the glyph turns white.
    func glassIcon(_ tint: Color? = nil, size: CGFloat = 24, iconSize: CGFloat = 11) -> some View {
        self
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(tint == nil ? Color.secondary : Color.white)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .glassEffect(tint.map { .regular.tint($0.opacity(0.85)).interactive() } ?? .regular.interactive(),
                         in: Circle())
    }

    /// Wide capsule version of glassIcon for the primary action — about two icon buttons wide,
    /// so it's an easier target, with room for a "Copied" label.
    func glassPill(_ tint: Color = .accentColor, width: CGFloat = 62, height: CGFloat = 24, iconSize: CGFloat = 11) -> some View {
        self
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: width, height: height)
            .contentShape(Capsule())
            .glassEffect(.regular.tint(tint.opacity(0.85)).interactive(), in: Capsule())
    }

    /// Glass lens panel: optional faint tint plus a hairline rim so edges stay crisp at 1x.
    /// The default rim uses the separator color so it reads in both light and dark mode.
    func glassPanel(tint: Color = .clear, tintOpacity: Double = 0.08, cornerRadius: CGFloat = 16,
                    rim: Color = Color(nsColor: .separatorColor)) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .glassEffect(.regular.tint(tint.opacity(tintOpacity)), in: shape)
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
    }
}

/// Glass buttons sink and dim while held, then spring back, so a click visibly registers.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .brightness(configuration.isPressed ? -0.12 : 0)
            .animation(.spring(duration: 0.22, bounce: 0.45), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
