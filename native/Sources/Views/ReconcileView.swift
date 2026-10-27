import SwiftUI

public struct ReconcileView: View {
    @ObservedObject var store: DataStore

    @State private var statementBalanceStr: String = ""
    @State private var statementDate: Date = Date()
    @State private var isStarted: Bool = false
    @State private var statusAlert: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reconcile Bank Statement: \(store.selectedAccount?.name ?? "Account")")
                        .font(.title3.weight(.bold))
                    Text("Compare your paper or online bank statement against Haste transactions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Picker("Account", selection: $store.selectedAccountId) {
                    ForEach(store.accounts) { a in
                        Text(a.name).tag(a.id as String?)
                    }
                }
                .frame(width: 200)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()

            if !isStarted {
                // Initial Reconcile Setup View
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "checkmark.circle.badge.questionmark.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))

                    Text("Reconcile Bank Statement")
                        .font(.title2.bold())

                    Text("Enter the ending balance and statement date from your bank statement:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Statement Ending Balance:")
                                .font(.caption.bold())
                                .frame(width: 180, alignment: .trailing)
                            TextField("0.00", text: $statementBalanceStr)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }

                        HStack {
                            Text("Statement Ending Date:")
                                .font(.caption.bold())
                                .frame(width: 180, alignment: .trailing)
                            DatePicker("", selection: $statementDate, displayedComponents: [.date])
                                .labelsHidden()
                                .frame(width: 140)
                        }
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    Button(action: startReconcile) {
                        Text("Start Reconciling")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.0, green: 0.35, blue: 0.20))

                    Spacer()
                }
                .padding()
            } else {
                // Active Reconcile Workspace: Two Columns (Payments vs Deposits)
                if let acct = store.selectedAccount {
                    let payments = acct.transactions.filter { $0.amount < 0 }
                    let deposits = acct.transactions.filter { $0.amount > 0 }
                    let clearedBalance = store.reconcileClearedBalance(for: acct)
                    let diff = store.reconcileDifference(for: acct)

                    HStack(spacing: 0) {
                        // Left: Checks and Payments
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Payments and Checks (Outflow)")
                                    .font(.caption.bold())
                                Spacer()
                                let clearedP = payments.filter { store.reconcileClearedIds.contains($0.id) }
                                Text("\(clearedP.count) Cleared (\(String(format: "$%.2f", clearedP.reduce(0) { $0 + abs($1.amount) })))")
                                    .font(.caption2.monospaced())
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            Divider()

                            List(payments) { tx in
                                HStack {
                                    Button(action: { store.toggleReconcileCleared(txId: tx.id) }) {
                                        Image(systemName: store.reconcileClearedIds.contains(tx.id) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(store.reconcileClearedIds.contains(tx.id) ? .accentColor : .secondary)
                                    }
                                    .buttonStyle(.plain)

                                    Text(tx.dateString).font(.caption2.monospaced())
                                    Text(tx.checkNumber).font(.caption2.monospaced()).frame(width: 40)
                                    Text(tx.payee).font(.caption).lineLimit(1)
                                    Spacer()
                                    Text(String(format: "$%.2f", abs(tx.amount)))
                                        .font(.caption.monospaced().bold())
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        Divider()

                        // Right: Deposits and Credits
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Deposits and Credits (Inflow)")
                                    .font(.caption.bold())
                                Spacer()
                                let clearedD = deposits.filter { store.reconcileClearedIds.contains($0.id) }
                                Text("\(clearedD.count) Cleared (\(String(format: "$%.2f", clearedD.reduce(0) { $0 + $1.amount })))")
                                    .font(.caption2.monospaced())
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            Divider()

                            List(deposits) { tx in
                                HStack {
                                    Button(action: { store.toggleReconcileCleared(txId: tx.id) }) {
                                        Image(systemName: store.reconcileClearedIds.contains(tx.id) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(store.reconcileClearedIds.contains(tx.id) ? .accentColor : .secondary)
                                    }
                                    .buttonStyle(.plain)

                                    Text(tx.dateString).font(.caption2.monospaced())
                                    Text(tx.payee).font(.caption).lineLimit(1)
                                    Spacer()
                                    Text(String(format: "$%.2f", tx.amount))
                                        .font(.caption.monospaced().bold())
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }

                    Divider()

                    // Bottom Summary & Reconciliation Status (Haste style)
                    HStack(alignment: .center, spacing: 20) {
                        HStack(spacing: 8) {
                            Button("Mark All") { store.markAllReconcileCleared(true) }
                                .buttonStyle(.bordered)
                            Button("Clear All") { store.markAllReconcileCleared(false) }
                                .buttonStyle(.bordered)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "Cleared Balance: $%.2f", clearedBalance))
                                .font(.caption.monospaced())
                            Text(String(format: "Statement Ending: $%.2f", store.reconcileStatementBalance))
                                .font(.caption.monospaced())
                            HStack(spacing: 4) {
                                Text("Difference:")
                                    .font(.caption.bold())
                                Text(String(format: "$%.2f", diff))
                                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                    .foregroundColor(abs(diff) < 0.01 ? .green : .red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(abs(diff) < 0.01 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                        .cornerRadius(6)

                        HStack(spacing: 8) {
                            Button("Cancel") { isStarted = false }
                                .buttonStyle(.bordered)

                            if abs(diff) > 0.01 {
                                Button("Auto-Adjust & Finish") {
                                    store.finishReconciliation(autoAdjust: true)
                                    isStarted = false
                                }
                                .buttonStyle(.bordered)
                            }

                            Button("Finished") {
                                store.finishReconciliation(autoAdjust: false)
                                isStarted = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
    }

    private func startReconcile() {
        let clean = statementBalanceStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let bal = Double(clean) ?? (store.selectedAccount?.balance ?? 0.0)
        store.startReconciliation(statementEndingBalance: bal, statementDate: statementDate)
        isStarted = true
    }
}
