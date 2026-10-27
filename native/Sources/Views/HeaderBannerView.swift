import SwiftUI

public struct HeaderBannerView: View {
    @ObservedObject var store: DataStore

    public var body: some View {
        HStack(spacing: 8) {
            // Activity Centers (Banking, Planning, Investing, Reports)
            HStack(spacing: 4) {
                centerButton(center: .banking, title: "Banking")
                centerButton(center: .planning, title: "Planning")
                centerButton(center: .investing, title: "Investing")
                centerButton(center: .reports, title: "Reports")
            }

            Spacer()

            // Net Worth Display
            VStack(alignment: .trailing, spacing: 1) {
                Text("Net Worth")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(String(format: "$%.2f", store.netWorth))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.35, blue: 0.20),
                    Color(red: 0.0, green: 0.25, blue: 0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func centerButton(center: QuickenCenter, title: String) -> some View {
        Button(action: {
            store.selectCenter(center)
        }) {
            Text(title)
                .font(.system(size: 11, weight: store.activeCenter == center ? .bold : .medium))
                .foregroundColor(store.activeCenter == center ? .yellow : .white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(store.activeCenter == center ? Color.black.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
