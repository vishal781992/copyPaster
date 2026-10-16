import SwiftUI

extension View {
    /// Circular Liquid Glass icon used for every icon button in the app.
    /// `filled` tints the glass with the action's color and draws a white glyph;
    /// otherwise the glass stays clear and the glyph carries the color (used for off states).
    /// The tint stays translucent so the refraction still reads through the color.
    func glassIcon(_ tint: Color, size: CGFloat = 24, iconSize: CGFloat = 11, filled: Bool = true) -> some View {
        self
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(filled ? Color.white : tint)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .glassEffect(filled ? .regular.tint(tint.opacity(0.65)).interactive() : .regular.interactive(), in: Circle())
    }

    /// Wide capsule version of glassIcon for the primary action — about two icon buttons wide,
    /// so it's an easier target, with room for a "Copied" label.
    func glassPill(_ tint: Color, width: CGFloat = 62, height: CGFloat = 24, iconSize: CGFloat = 11) -> some View {
        self
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: width, height: height)
            .contentShape(Capsule())
            .glassEffect(.regular.tint(tint.opacity(0.65)).interactive(), in: Capsule())
    }

    /// Glass lens panel: faint color tint plus a hairline rim so edges stay crisp at 1x.
    func glassPanel(tint: Color = .clear, tintOpacity: Double = 0.08, cornerRadius: CGFloat = 16,
                    rim: Color = .white.opacity(0.18)) -> some View {
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
