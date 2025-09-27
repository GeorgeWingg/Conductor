import SwiftUI

struct MenuBarIconView: View {
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        ZStack {
            Circle()
                .fill(gradientColor)
                .frame(width: 18, height: 18)
            Image(systemName: store.badgeSymbolName())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(2)
    }

    private var gradientColor: LinearGradient {
        let colors: [Color]
        switch store.badgeColor() {
        case .neutral:
            colors = [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        case .active:
            colors = [Color.blue, Color.cyan]
        case .attention:
            colors = [Color.orange, Color.yellow]
        case .success:
            colors = [Color.green, Color.mint]
        case .danger:
            colors = [Color.red, Color.pink]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
