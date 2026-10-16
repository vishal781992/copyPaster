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

    /// Glass lens panel: faint color tint plus a hairline rim so edges stay crisp at 1x.
    func glassPanel(tint: Color = .clear, tintOpacity: Double = 0.08, cornerRadius: CGFloat = 16,
                    rim: Color = .white.opacity(0.18)) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .glassEffect(.regular.tint(tint.opacity(tintOpacity)), in: shape)
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
    }
}
