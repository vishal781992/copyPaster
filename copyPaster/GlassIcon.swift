import SwiftUI

// Liquid Glass needs macOS 26. These wrappers use it there and fall back to
// frosted materials on macOS 15, so the app runs on Sequoia and later.

extension View {
    /// Liquid Glass in `shape` on macOS 26+, a material fill with the same tint on earlier releases.
    @ViewBuilder
    func adaptiveGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            let base = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self.background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint { shape.fill(tint) }
                }
            }
        }
    }

    /// Highlight for the selected segment. Glass morphs between segments via glassEffectID on macOS 26+;
    /// earlier releases slide a material capsule with matchedGeometryEffect.
    @ViewBuilder
    func adaptiveGlassSelection(_ selected: Bool, id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(selected ? .regular.tint(Color.primary.opacity(0.08)).interactive() : .identity,
                             in: Capsule())
                .glassEffectID(selected ? "selection" : id, in: namespace)
        } else {
            self.background {
                if selected {
                    Capsule()
                        .fill(.thickMaterial)
                        .overlay(Capsule().fill(Color.primary.opacity(0.08)))
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
        }
    }

    /// `.glass` / `.glassProminent` button styles on macOS 26+, bordered equivalents before that.
    @ViewBuilder
    func adaptiveGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }
}

/// GlassEffectContainer on macOS 26+ so nearby glass shapes blend; a passthrough on earlier releases.
struct AdaptiveGlassContainer<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

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
            .adaptiveGlass(in: Circle(), tint: tint?.opacity(0.85), interactive: true)
    }

    /// Wide capsule version of glassIcon for the primary action — about two icon buttons wide,
    /// so it's an easier target, with room for a "Copied" label.
    func glassPill(_ tint: Color = .accentColor, width: CGFloat = 62, height: CGFloat = 24, iconSize: CGFloat = 11) -> some View {
        self
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: width, height: height)
            .contentShape(Capsule())
            .adaptiveGlass(in: Capsule(), tint: tint.opacity(0.85), interactive: true)
    }

    /// Glass lens panel: optional faint tint plus a hairline rim so edges stay crisp at 1x.
    /// The default rim uses the separator color so it reads in both light and dark mode.
    func glassPanel(tint: Color = .clear, tintOpacity: Double = 0.08, cornerRadius: CGFloat = 16,
                    rim: Color = Color(nsColor: .separatorColor)) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .adaptiveGlass(in: shape, tint: tint.opacity(tintOpacity))
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
