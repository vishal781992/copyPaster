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
            Divider()

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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.05))
                        .stroke(Color.accentColor.opacity(focused ? 0.35 : 0.12), lineWidth: 1)
                )

                // Actions
                HStack {
                    Spacer()
                    Button("Cancel") {
                        text = ""
                        withAnimation(.spring(duration: 0.3)) { isShowing = false }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.trailing, 4)

                    Button("Add to History") {
                        manager.addManualText(text)
                        text = ""
                        withAnimation(.spring(duration: 0.3)) { isShowing = false }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(trimmed.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear { focused = true }
    }
}
