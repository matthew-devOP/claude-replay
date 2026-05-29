import SwiftUI

struct ToastView: View {
    @Environment(AppState.self) private var appState
    let message: String
    var isError: Bool = false

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, DesignTokens.spaceMD)
            .padding(.vertical, DesignTokens.spaceSM)
            .background(
                (isError ? appState.theme.red : appState.theme.green).opacity(0.95),
                in: RoundedRectangle(cornerRadius: DesignTokens.cornerMedium, style: .continuous)
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
                    .padding(.bottom, DesignTokens.space32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(Motion.standard) { isPresented = false }
                        }
                    }
                    .animation(Motion.standard, value: isPresented)
            }
        }
        .animation(Motion.standard, value: isPresented)
    }
}

extension View {
    func toast(message: String, isError: Bool = false, isPresented: Binding<Bool>, duration: TimeInterval = 2.5) -> some View {
        modifier(ToastModifier(message: message, isError: isError, isPresented: isPresented, duration: duration))
    }
}
