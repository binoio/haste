import SwiftUI

public struct SidebarView: View {
    @ObservedObject var store: DataStore

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Section: Haste Centers
                VStack(alignment: .leading, spacing: 3) {
                    Text("HASTE CENTERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    sidebarButton(id: "financialCenter", title: "Financial Center", icon: "chart.pie.fill")
                    sidebarButton(id: "register", title: "Account Registers", icon: "list.bullet.rectangle.fill")
                    sidebarButton(id: "writeChecks", title: "Write Checks", icon: "pencil.and.outline")
                    sidebarButton(id: "reconcile", title: "Reconcile Account", icon: "checkmark.circle.badge.questionmark.fill")
                    sidebarButton(id: "reminders", title: "Bills & Reminders", icon: "clock.badge.exclamationmark.fill", badge: "\(store.scheduledBills.count)")
                    sidebarButton(id: "budget", title: "Planning & Budgets", icon: "dollarsign.square.fill")
                    sidebarButton(id: "reports", title: "Reports & Graphs", icon: "chart.bar.xaxis")
                }

                Divider()
                    .padding(.horizontal, 8)

                // Section: Accounts
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("ACCOUNTS (\(store.accounts.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)

                    ForEach(store.accounts) { account in
                        let isSelected = store.selectedAccountId == account.id && store.activeQuickTab == "register"
                        Button(action: {
                            store.selectedAccountId = account.id
                            store.activeQuickTab = "register"
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: account.type.iconName)
                                    .foregroundColor(account.type == .creditCard ? .orange : Color(red: 0.0, green: 0.35, blue: 0.20))
                                    .frame(width: 18, alignment: .center)

                                Text(account.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 4)

                                Text(String(format: "$%.2f", account.balance))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(account.balance < 0 ? .red : .secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(width: 240)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func sidebarButton(id: String, title: String, icon: String, badge: String? = nil) -> some View {
        let isSelected = store.activeQuickTab == id
        return Button(action: {
            store.activeQuickTab = id
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? Color(red: 0.0, green: 0.35, blue: 0.20) : .secondary)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
