import SwiftUI
import UniformTypeIdentifiers

enum DropZone {
    case above
    case onTarget
    case below
}

public struct SidebarView: View {
    @ObservedObject var store: DataStore

    @State private var draggedAccountId: String? = nil
    @State private var currentDropTargetId: String? = nil
    @State private var currentDropZone: DropZone? = nil

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
                        accountRow(account: account)
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

    @ViewBuilder
    private func accountRow(account: Account) -> some View {
        let isSelected = store.selectedAccountId == account.id && store.activeQuickTab == "register"
        let isMultiSelected = store.multiSelectedAccountIds.contains(account.id)
        let isTargeted = currentDropTargetId == account.id
        let isDraggingThis = draggedAccountId == account.id

        VStack(spacing: 0) {
            // Drop indicator above
            if isTargeted && currentDropZone == .above {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .padding(.horizontal, 4)
            }

            Button(action: {
                handleAccountClick(account)
            }) {
                HStack(spacing: 6) {
                    if store.multiSelectedAccountIds.count > 1 && isMultiSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                            .font(.system(size: 10))
                    }

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
                .background(
                    isTargeted && currentDropZone == .onTarget
                        ? Color.green.opacity(0.25)
                        : (isSelected || isMultiSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isTargeted && currentDropZone == .onTarget ? Color.green : Color.clear, lineWidth: 1.5)
                )
                .cornerRadius(5)
                .opacity(isDraggingThis ? 0.4 : 1.0)
            }
            .buttonStyle(.plain)
            .onDrag {
                draggedAccountId = account.id
                return NSItemProvider(object: account.id as NSString)
            }
            .onDrop(of: [.plainText, .text], delegate: AccountDropDelegate(
                targetAccount: account,
                store: store,
                draggedAccountId: $draggedAccountId,
                currentDropTargetId: $currentDropTargetId,
                currentDropZone: $currentDropZone
            ))
            .contextMenu {
                Button("Open Register") {
                    store.selectedAccountId = account.id
                    store.multiSelectedAccountIds = [account.id]
                    store.activeQuickTab = "register"
                }

                if store.accounts.count > 1 {
                    Button("Merge…") {
                        triggerMergeFromAccount(account)
                    }
                }

                Divider()

                Button("Delete Account…", role: .destructive) {
                    store.deleteAccount(id: account.id)
                }
            }

            // Drop indicator below
            if isTargeted && currentDropZone == .below {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func handleAccountClick(_ account: Account) {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        if flags.contains(.command) {
            if store.multiSelectedAccountIds.contains(account.id) {
                store.multiSelectedAccountIds.remove(account.id)
            } else {
                store.multiSelectedAccountIds.insert(account.id)
            }
            if let first = store.multiSelectedAccountIds.first {
                store.selectedAccountId = first
            }
        } else if flags.contains(.shift) {
            if let selId = store.selectedAccountId,
               let startIdx = store.accounts.firstIndex(where: { $0.id == selId }),
               let endIdx = store.accounts.firstIndex(where: { $0.id == account.id }) {
                let low = min(startIdx, endIdx)
                let high = max(startIdx, endIdx)
                for i in low...high {
                    store.multiSelectedAccountIds.insert(store.accounts[i].id)
                }
            } else {
                store.multiSelectedAccountIds = [account.id]
                store.selectedAccountId = account.id
            }
        } else {
            store.multiSelectedAccountIds = [account.id]
            store.selectedAccountId = account.id
            store.activeQuickTab = "register"
        }
    }

    private func triggerMergeFromAccount(_ account: Account) {
        if store.multiSelectedAccountIds.contains(account.id) && store.multiSelectedAccountIds.count > 1 {
            store.pendingMergeSourceIds = Array(store.multiSelectedAccountIds.filter { $0 != account.id })
            store.pendingMergeTargetId = account.id
        } else {
            store.pendingMergeSourceIds = [account.id]
            store.pendingMergeTargetId = store.accounts.first(where: { $0.id != account.id })?.id
        }
        store.isMergeSheetPresented = true
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

struct AccountDropDelegate: DropDelegate {
    let targetAccount: Account
    let store: DataStore
    @Binding var draggedAccountId: String?
    @Binding var currentDropTargetId: String?
    @Binding var currentDropZone: DropZone?

    func dropEntered(info: DropInfo) {
        currentDropTargetId = targetAccount.id
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let sourceId = draggedAccountId, sourceId != targetAccount.id else {
            return DropProposal(operation: .cancel)
        }
        let y = info.location.y
        if y < 7 {
            currentDropZone = .above
        } else if y > 21 {
            currentDropZone = .below
        } else {
            currentDropZone = .onTarget
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if currentDropTargetId == targetAccount.id {
            currentDropTargetId = nil
            currentDropZone = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        let sourceId = draggedAccountId
        let zone = currentDropZone
        currentDropTargetId = nil
        currentDropZone = nil
        draggedAccountId = nil

        guard let srcId = sourceId, srcId != targetAccount.id else { return false }

        switch zone {
        case .above:
            store.moveAccount(id: srcId, before: targetAccount.id)
            return true
        case .below:
            store.moveAccount(id: srcId, after: targetAccount.id)
            return true
        case .onTarget:
            // Dragged on top of target: trigger merge dialog!
            if store.multiSelectedAccountIds.contains(srcId) && store.multiSelectedAccountIds.count > 1 {
                store.pendingMergeSourceIds = Array(store.multiSelectedAccountIds.filter { $0 != targetAccount.id })
            } else {
                store.pendingMergeSourceIds = [srcId]
            }
            store.pendingMergeTargetId = targetAccount.id
            store.isMergeSheetPresented = true
            return true
        case .none:
            return false
        }
    }
}
