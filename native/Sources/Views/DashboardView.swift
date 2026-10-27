import SwiftUI

public struct DashboardView: View {
    @ObservedObject var store: DataStore

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Banner: Haste Financial Center Snapshot
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Financial Center")
                            .font(.system(.title, design: .serif, weight: .bold))
                        Text("Haste • Overview of Balances, Bills, and Spending")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Quick Action Buttons
                    HStack(spacing: 8) {
                        Button(action: { store.activeQuickTab = "writeChecks" }) {
                            Label("Write Check", systemImage: "pencil.and.outline")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { store.activeQuickTab = "reconcile" }) {
                            Label("Reconcile", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { store.activeQuickTab = "register" }) {
                            Label("Register", systemImage: "list.bullet.rectangle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
                    }
                }

                // Summary KPI Cards
                HStack(spacing: 14) {
                    summaryCard(
                        title: "Total Net Worth",
                        amount: store.netWorth,
                        icon: "dollarsign.circle.fill",
                        color: store.netWorth >= 0 ? .green : .red
                    )
                    summaryCard(
                        title: "Total Inflow (Deposits)",
                        amount: store.totalInflow,
                        icon: "arrow.down.left.circle.fill",
                        color: .green
                    )
                    summaryCard(
                        title: "Total Outflow (Expenses)",
                        amount: store.totalOutflow,
                        icon: "arrow.up.right.circle.fill",
                        color: .red
                    )
                    summaryCard(
                        title: "Active Accounts",
                        count: store.accounts.count,
                        icon: "building.columns.circle.fill",
                        color: .blue
                    )
                }

                // Two-column layout: Account Overview & Upcoming Reminders
                HStack(alignment: .top, spacing: 16) {
                    // Accounts Overview Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Account Balances")
                                .font(.headline)
                            Spacer()
                            Button("Open Register") {
                                store.activeQuickTab = "register"
                            }
                            .font(.caption)
                        }

                        if store.accounts.isEmpty {
                            Text("No accounts loaded. Open a folder or click New Account.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(store.accounts.prefix(6)) { acct in
                                Button(action: {
                                    store.selectedAccountId = acct.id
                                    store.activeQuickTab = "register"
                                }) {
                                    HStack {
                                        Image(systemName: acct.type.iconName)
                                            .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                                            .frame(width: 18)
                                        Text(acct.name)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        Spacer()
                                        Text(String(format: "$%.2f", acct.balance))
                                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                                            .foregroundColor(acct.balance < 0 ? .red : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)

                    // Upcoming Bills & Scheduled Reminders
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Bills & Scheduled Reminders")
                                .font(.headline)
                            Spacer()
                            Button("View All") {
                                store.activeQuickTab = "reminders"
                            }
                            .font(.caption)
                        }

                        if store.scheduledBills.isEmpty {
                            Text("No upcoming bills scheduled.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(store.scheduledBills.prefix(4)) { bill in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bill.payee)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        Text("Due: \(bill.formattedDueDate) • \(bill.accountName)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "$%.2f", bill.amount))
                                        .font(.system(.caption, design: .monospaced, weight: .bold))

                                    Button("Record") {
                                        store.recordBillInRegister(bill: bill)
                                    }
                                    .font(.caption2.bold())
                                    .buttonStyle(.bordered)
                                }
                                Divider()
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
                }

                // Two-column layout: Top Spending Categories & Recent Activity
                HStack(alignment: .top, spacing: 16) {
                    // Category Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Spending Categories")
                            .font(.headline)

                        let topCats = Array(store.categorySpending.prefix(7))
                        if topCats.isEmpty {
                            Text("No category transactions recorded.")
                                .foregroundColor(.secondary)
                        } else {
                            let maxAmt = topCats.first?.amount ?? 1.0
                            ForEach(topCats, id: \.category) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.category)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(String(format: "$%.2f", item.amount))
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    GeometryReader { geo in
                                        let ratio = maxAmt > 0 ? CGFloat(item.amount / maxAmt) : 0
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(red: 0.0, green: 0.35, blue: 0.20).opacity(0.8))
                                            .frame(width: max(4, geo.size.width * ratio), height: 6)
                                    }
                                    .frame(height: 6)
                                }
                                .padding(.vertical, 1)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)

                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Transactions")
                            .font(.headline)

                        let recent = Array(store.allTransactions.prefix(7))
                        if recent.isEmpty {
                            Text("No transactions loaded.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(recent) { tx in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tx.payee)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                        Text("\(tx.dateString) • \(tx.accountName)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "%@$%.2f", tx.amount < 0 ? "-" : "+", abs(tx.amount)))
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundColor(tx.amount < 0 ? .red : .green)
                                }
                                Divider()
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
        }
    }

    private func summaryCard(title: String, amount: Double? = nil, count: Int? = nil, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if let amt = amount {
                    Text(String(format: "$%.2f", amt))
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                } else if let c = count {
                    Text("\(c)")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
