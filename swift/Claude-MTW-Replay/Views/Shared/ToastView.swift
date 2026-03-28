import SwiftUI
struct ToastView: View {
    let message: String; var isError: Bool = false
    var body: some View {
        Text(message).font(.caption).padding(8).background(isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9), in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
    }
}
