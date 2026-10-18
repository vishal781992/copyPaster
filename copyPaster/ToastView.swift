import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .adaptiveGlass(in: Capsule())
    }
}
