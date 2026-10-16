import SwiftUI

struct AddTextView: View {
    @Environment(ClipboardManager.self) private var manager
    @Binding var isShowing: Bool
    @State private var text = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                // Label
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("New Snippet")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(text.isEmpty ? "" : "\(text.count) chars")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .animation(.none, value: text.count)
                }

                // Editor
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Type your snippet here…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .frame(height: 72)
                        .padding(4)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .stroke(Color.accentColor.opacity(focused ? 0.45 : 0.15), lineWidth: 1)
                )

                // Actions
                HStack {
                    Spacer()
                    Button("Cancel") {
                        text = ""
                        withAnimation(.spring(duration: 0.3)) { isShowing = false }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .padding(.trailing, 4)

                    Button("Add to History") {
                        manager.addManualText(text)
                        text = ""
                        withAnimation(.spring(duration: 0.3)) { isShowing = false }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .controlSize(.small)
                    .disabled(trimmed.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(14)
            .glassPanel(tint: .accentColor, tintOpacity: 0.06, cornerRadius: 20)
        }
        .onAppear { focused = true }
    }
}
