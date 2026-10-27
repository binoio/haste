import SwiftUI

public struct RegisterView: View {
    @ObservedObject var store: DataStore
    @Environment(\.colorScheme) private var colorScheme

    // Active entry state (for new or editing transaction)
    @State private var editingTxId: UUID? = nil
    @State private var entryDate: Date = Date()
    @State private var entryDateString: String = ""
    @State private var entryNum: String = ""
    @State private var entryPayee: String = ""
    @State private var entryCategory: String = ""
    @State private var entryMemo: String = ""
    @State private var entryPaymentString: String = ""
    @State private var entryDepositString: String = ""
    @State private var entryCleared: String = ""
    @State private var entrySplits: [SplitItem] = []

    @State private var expandedSplitsTxId: UUID? = nil
    @State private var showSplitSheet: Bool = false
    @State private var statusFeedback: String = ""

    private var targetSplitAmount: Double {
        let pClean = entryPaymentString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        if let p = Double(pClean), p > 0 { return p }
        let dClean = entryDepositString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        if let d = Double(dClean), d > 0 { return d }
        return 0.0
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Register Header Bar
            HStack {
                if let acct = store.selectedAccount {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: acct.type.iconName)
                                .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                            Text(acct.name)
                                .font(.title3.weight(.bold))
                        }
                        Text("Type: \(acct.type.rawValue) • \(acct.transactions.count) Transactions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("All Accounts Register")
                        .font(.title3.weight(.bold))
                }

                Spacer()

                // Account switcher picker
                Picker("Account", selection: $store.selectedAccountId) {
                    Text("All Accounts").tag(nil as String?)
                    ForEach(store.accounts) { a in
                        Text(a.name).tag(a.id as String?)
                    }
                }
                .frame(width: 200)

                // Actions: Export & Reconcile
                Button(action: { store.activeQuickTab = "reconcile" }) {
                    Label("Reconcile...", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)

                Button(action: exportCSV) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()

            // Classic Quicken Register Column Header
            HStack(spacing: 6) {
                Text("Date").frame(width: 74, alignment: .leading)
                Text("Num").frame(width: 44, alignment: .leading)
                Text("Payee / Memo").frame(minWidth: 120, alignment: .leading)
                Text("Category / Transfer").frame(minWidth: 90, alignment: .leading)
                Text("Clr").frame(width: 26, alignment: .center)
                Text("Payment").frame(width: 74, alignment: .trailing)
                Text("Deposit").frame(width: 74, alignment: .trailing)
                Text("Balance").frame(width: 82, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()

            // Transactions Table (Authentic Dual-Line Checkbook Register)
            let txs = store.filteredTransactions
            if txs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No transactions in register. Use the entry row below to add one.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(txs.enumerated()), id: \.element.id) { index, tx in
                            let isSelected = editingTxId == tx.id
                            let isEven = index % 2 == 0
                            let rowBg: Color = {
                                if isSelected {
                                    return Color.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.18)
                                }
                                if isEven {
                                    return colorScheme == .dark
                                        ? Color(red: 0.12, green: 0.17, blue: 0.13)
                                        : Color(red: 0.94, green: 0.97, blue: 0.94)
                                }
                                return Color(NSColor.textBackgroundColor)
                            }()

                            VStack(spacing: 2) {
                                // Line 1: Date | Num | Payee | Clr | Payment | Deposit | Balance
                                HStack(spacing: 6) {
                                    Text(tx.dateString)
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(width: 74, alignment: .leading)

                                    Text(tx.checkNumber)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 44, alignment: .leading)

                                    Text(tx.payee)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                        .frame(minWidth: 120, alignment: .leading)

                                    Text(tx.category)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(minWidth: 90, alignment: .leading)

                                    Button(action: { toggleClearedStatus(for: tx) }) {
                                        Text(tx.clearedStatus.isEmpty ? "·" : tx.clearedStatus)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(tx.isReconciled ? .green : .blue)
                                            .frame(width: 26, alignment: .center)
                                    }
                                    .buttonStyle(.plain)

                                    Text(tx.isPayment ? String(format: "$%.2f", abs(tx.amount)) : "")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : Color(red: 0.85, green: 0.1, blue: 0.1))
                                        .frame(width: 74, alignment: .trailing)

                                    Text(tx.isDeposit ? String(format: "$%.2f", tx.amount) : "")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colorScheme == .dark ? Color(red: 0.45, green: 0.9, blue: 0.45) : Color(red: 0.0, green: 0.55, blue: 0.15))
                                        .frame(width: 74, alignment: .trailing)

                                    Text(String(format: "$%.2f", tx.runningBalance))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(tx.runningBalance < 0 ? (colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : .red) : .primary)
                                        .frame(width: 82, alignment: .trailing)
                                }

                                // Line 2: Memo & Splits info & quick action buttons
                                HStack(spacing: 6) {
                                    Spacer().frame(width: 124)

                                    if !tx.memo.isEmpty {
                                        Text("Memo: \(tx.memo)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    if !tx.splits.isEmpty {
                                        Button(action: {
                                            expandedSplitsTxId = (expandedSplitsTxId == tx.id) ? nil : tx.id
                                        }) {
                                            Text("Splits (\(tx.splits.count))")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.accentColor.opacity(0.2))
                                                .cornerRadius(3)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Spacer()

                                    // Quick Edit & Delete icons
                                    Button(action: { loadForEditing(tx) }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { store.deleteTransaction(id: tx.id) }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Expanded Splits View
                                if expandedSplitsTxId == tx.id && !tx.splits.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(tx.splits) { split in
                                            HStack {
                                                Spacer().frame(width: 150)
                                                Text("↳ \(split.category)")
                                                    .font(.system(size: 10))
                                                if !split.memo.isEmpty {
                                                    Text("(\(split.memo))")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Text(String(format: "$%.2f", split.amount))
                                                    .font(.system(size: 10, design: .monospaced))
                                                Spacer().frame(width: 100)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    .background(colorScheme == .dark ? Color.yellow.opacity(0.14) : Color.yellow.opacity(0.08))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(rowBg)
                            .onTapGesture {
                                loadForEditing(tx)
                            }
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Authentic Quicken Register In-Place Entry Bar (Bottom)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Date").font(.system(size: 9, weight: .bold))
                        TextField("YYYY-MM-DD", text: $entryDateString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 82)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Num").font(.system(size: 9, weight: .bold))
                        TextField("Num", text: $entryNum)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .frame(width: 48)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payee").font(.system(size: 9, weight: .bold))
                        TextField("Payee Name", text: $entryPayee)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payment").font(.system(size: 9, weight: .bold))
                        TextField("0.00", text: $entryPaymentString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 76)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deposit").font(.system(size: 9, weight: .bold))
                        TextField("0.00", text: $entryDepositString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 76)
                    }
                }

                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memo").font(.system(size: 9, weight: .bold))
                        TextField("Memo", text: $entryMemo)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Category").font(.system(size: 9, weight: .bold))
                        TextField("Category / Transfer", text: $entryCategory)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .frame(width: 140)
                    }

                    Button(action: { showSplitSheet = true }) {
                        Text(entrySplits.isEmpty ? "Split" : "Split (\(entrySplits.count))")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.top, 14)

                    // Action Buttons: Record & Restore
                    Button(action: recordTransaction) {
                        Label(editingTxId != nil ? "Save Changes" : "Record", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colorScheme == .dark ? Color(red: 0.15, green: 0.52, blue: 0.28) : Color(red: 0.0, green: 0.35, blue: 0.20))
                    .padding(.top, 14)

                    Button("Restore", action: resetEntryForm)
                        .buttonStyle(.bordered)
                        .padding(.top, 14)

                    if editingTxId != nil {
                        Button("Cancel Edit", action: resetEntryForm)
                            .buttonStyle(.plain)
                            .padding(.top, 14)
                    }
                }
            }
            .padding(10)
            .background(colorScheme == .dark ? Color(red: 0.13, green: 0.17, blue: 0.14) : Color(red: 0.92, green: 0.95, blue: 0.92))
            Divider()

            // Bottom Register Status Bar (Haste style)
            HStack(spacing: 16) {
                if let acct = store.selectedAccount {
                    Text(String(format: "Cleared Balance: $%.2f", acct.clearedBalance))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(String(format: "Ending Balance: $%.2f", acct.balance))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(acct.balance < 0 ? .red : .primary)
                } else {
                    Text(String(format: "Net Total: $%.2f", store.netWorth))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }

                Spacer()

                if !statusFeedback.isEmpty {
                    Text(statusFeedback)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }

                Text("\(txs.count) records")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showSplitSheet) {
            SplitEditorSheet(
                splits: $entrySplits,
                totalTargetAmount: targetSplitAmount,
                onSave: { updated in
                    self.entrySplits = updated
                    self.showSplitSheet = false
                },
                onCancel: {
                    self.showSplitSheet = false
                }
            )
        }
    }

    private func toggleClearedStatus(for tx: Transaction) {
        var updated = tx
        switch tx.clearedStatus.uppercased() {
        case "": updated.clearedStatus = "c"
        case "C": updated.clearedStatus = "*"
        case "*": updated.clearedStatus = "R"
        case "R", "X": updated.clearedStatus = ""
        default: updated.clearedStatus = ""
        }
        store.updateTransaction(updated)
    }

    private func loadForEditing(_ tx: Transaction) {
        editingTxId = tx.id
        entryDate = tx.date
        entryDateString = tx.dateString
        entryNum = tx.checkNumber
        entryPayee = tx.payee
        entryMemo = tx.memo
        entryCategory = tx.category
        entryCleared = tx.clearedStatus
        entrySplits = tx.splits

        if tx.isPayment {
            entryPaymentString = String(format: "%.2f", abs(tx.amount))
            entryDepositString = ""
        } else {
            entryDepositString = String(format: "%.2f", tx.amount)
            entryPaymentString = ""
        }
    }

    private func recordTransaction() {
        let trimmedPayee = entryPayee.trimmingCharacters(in: .whitespaces)
        guard !trimmedPayee.isEmpty else {
            statusFeedback = "Please enter a Payee."
            return
        }

        guard let acct = store.selectedAccount ?? store.accounts.first else {
            statusFeedback = "Please create or select an account first."
            return
        }

        let cleanPay = entryPaymentString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let cleanDep = entryDepositString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let payAmt = Double(cleanPay) ?? 0.0
        let depAmt = Double(cleanDep) ?? 0.0

        let finalAmount: Double = depAmt > 0 ? depAmt : -abs(payAmt)
        let (parsedDate, formattedDateStr) = QIFParser.parseDate(entryDateString)
        let finalDate = parsedDate.timeIntervalSince1970 > 0 ? parsedDate : Date()
        let finalDateString = formattedDateStr.isEmpty ? Transaction.formatDate(finalDate) : formattedDateStr

        if let editId = editingTxId {
            let updatedTx = Transaction(
                id: editId,
                accountName: acct.name,
                date: finalDate,
                dateString: finalDateString,
                checkNumber: entryNum,
                payee: trimmedPayee,
                memo: entryMemo,
                category: entryCategory,
                amount: finalAmount,
                clearedStatus: entryCleared,
                splits: entrySplits
            )
            store.updateTransaction(updatedTx)
            statusFeedback = "Transaction updated!"
        } else {
            let newTx = Transaction(
                accountName: acct.name,
                date: finalDate,
                dateString: finalDateString,
                checkNumber: entryNum,
                payee: trimmedPayee,
                memo: entryMemo,
                category: entryCategory,
                amount: finalAmount,
                clearedStatus: entryCleared,
                splits: entrySplits
            )
            store.addTransaction(to: acct.id, transaction: newTx)
            statusFeedback = "Transaction recorded!"
        }

        resetEntryForm()
    }

    private func resetEntryForm() {
        editingTxId = nil
        entryDate = Date()
        entryDateString = Transaction.formatDate(Date())
        entryNum = ""
        entryPayee = ""
        entryCategory = ""
        entryMemo = ""
        entryPaymentString = ""
        entryDepositString = ""
        entryCleared = ""
        entrySplits = []
    }

    private func exportCSV() {
        let csv = store.exportTransactionsCSV(for: store.selectedAccount)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let name = store.selectedAccount?.name ?? "All_Accounts"
        panel.nameFieldStringValue = "\(name)_Export.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
