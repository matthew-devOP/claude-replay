import SwiftUI

struct ToastView: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - Toast ViewModifier

struct ToastModifier: ViewModifier {
    let message: String
    var isError: Bool = false
    @Binding var isPresented: Bool
    var duration: TimeInterval = 2.5

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                ToastView(message: message, isError: isError)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation { isPresented = false }
                        }
                    }
                    .animation(.easeInOut, value: isPresented)
            }
        }
        .animation(.easeInOut, value: isPresented)
    }
}

extension View {
    func toast(message: String, isError: Bool = false, isPresented: Binding<Bool>, duration: TimeInterval = 2.5) -> some View {
        modifier(ToastModifier(message: message, isError: isError, isPresented: isPresented, duration: duration))
    }
}
