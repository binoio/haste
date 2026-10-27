import SwiftUI

public struct ReportsView: View {
    @ObservedObject var store: DataStore

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reports & Graphs")
                            .font(.system(.title, design: .serif, weight: .bold))
                        Text("Category Spending & Financial Flow Analysis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                // Spending by Category Table & Visual Bars
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expense Breakdown by Category")
                        .font(.headline)

                    let cats = store.categorySpending
                    if cats.isEmpty {
                        Text("No categorized expenses recorded.")
                            .foregroundColor(.secondary)
                    } else {
                        let totalExp = cats.reduce(0.0) { $0 + $1.amount }
                        ForEach(cats, id: \.category) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.category)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    let pct = totalExp > 0 ? (item.amount / totalExp) * 100 : 0
                                    Text(String(format: "$%.2f (%.1f%%)", item.amount, pct))
                                        .font(.system(.subheadline, design: .monospaced))
                                }

                                GeometryReader { geo in
                                    let ratio = totalExp > 0 ? CGFloat(item.amount / totalExp) : 0
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: max(4, geo.size.width * ratio), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Cash Flow Summary Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cash Flow Summary")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", store.totalInflow))
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Expenses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", store.totalOutflow))
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundColor(.red)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Net Cash Flow")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            let net = store.totalInflow - store.totalOutflow
                            Text(String(format: "$%.2f", net))
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundColor(net >= 0 ? .green : .red)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(20)
        }
    }
}
