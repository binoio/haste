import Foundation
import SwiftUI
import Combine

public enum QuickenCenter: String, CaseIterable, Identifiable {
    case banking = "Banking"
    case planning = "Planning"
    case investing = "Investing"
    case reports = "Reports & Graphs"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .banking: return "dollarsign.circle.fill"
        case .planning: return "calendar.badge.clock"
        case .investing: return "chart.line.uptrend.xyaxis"
        case .reports: return "chart.bar.xaxis"
        }
    }
}

public struct QuickTabItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let iconName: String
    public var badge: String?

    public init(id: String, title: String, iconName: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.badge = badge
    }
}

public struct HasteDataPayload: Codable {
    public var accounts: [Account]
    public var scheduledBills: [ScheduledBill]
    public var budgetCategories: [BudgetCategory]

    public init(
        accounts: [Account] = [],
        scheduledBills: [ScheduledBill] = [],
        budgetCategories: [BudgetCategory] = []
    ) {
        self.accounts = accounts
        self.scheduledBills = scheduledBills
        self.budgetCategories = budgetCategories
    }
}

public final class DataStore: ObservableObject {
    public static let shared = DataStore()

    public static var standardDataDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let hasteDir = appSupport.appendingPathComponent("Haste", isDirectory: true)
        if !FileManager.default.fileExists(atPath: hasteDir.path) {
            try? FileManager.default.createDirectory(at: hasteDir, withIntermediateDirectories: true)
        }
        return hasteDir
    }

    public static var standardDataFileURL: URL {
        standardDataDirectoryURL.appendingPathComponent("haste_data.json")
    }

    @Published public var accounts: [Account] = []
    @Published public var selectedAccountId: String? = nil
    @Published public var loadedDirectoryPath: String = ""
    @Published public var qdfFiles: [QDFMetadata] = []
    @Published public var qsdFiles: [QSDMetadata] = []
    @Published public var searchQuery: String = ""

    // Navigation state
    @Published public var activeCenter: QuickenCenter = .banking
    @Published public var activeQuickTab: String = "financialCenter"

    public func selectCenter(_ center: QuickenCenter) {
        activeCenter = center
        switch center {
        case .banking: activeQuickTab = "register"
        case .planning: activeQuickTab = "budget"
        case .investing: activeQuickTab = "financialCenter"
        case .reports: activeQuickTab = "reports"
        }
    }

    // Reconcile state
    @Published public var isReconcileSheetPresented: Bool = false
    @Published public var reconcileStatementBalance: Double = 0.0
    @Published public var reconcileStatementDate: Date = Date()
    @Published public var reconcileClearedIds: Set<UUID> = []

    // Scheduled Bills
    @Published public var scheduledBills: [ScheduledBill] = []

    // Budgets
    @Published public var budgetCategories: [BudgetCategory] = []

    // Multi-selection & Merge state
    @Published public var multiSelectedAccountIds: Set<String> = []
    @Published public var pendingMergeSourceIds: [String] = []
    @Published public var pendingMergeTargetId: String? = nil
    @Published public var isMergeSheetPresented: Bool = false

    public let dataDirectoryURL: URL
    public let dataFileURL: URL

    public init(
        dataDirectoryURL: URL = DataStore.standardDataDirectoryURL,
        dataFileURL: URL = DataStore.standardDataFileURL
    ) {
        self.dataDirectoryURL = dataDirectoryURL
        self.dataFileURL = dataFileURL
        self.loadedDirectoryPath = dataDirectoryURL.path
        loadStandardData()
    }

    public func loadStandardData() {
        let fileURL = dataFileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(HasteDataPayload.self, from: data)
                self.accounts = payload.accounts
                self.scheduledBills = payload.scheduledBills
                self.budgetCategories = payload.budgetCategories
                self.selectedAccountId = payload.accounts.first?.id
                if let firstId = self.selectedAccountId {
                    self.multiSelectedAccountIds = [firstId]
                }
                return
            } catch {
                print("Notice: could not decode standard data: \(error.localizedDescription)")
            }
        }

        // If no JSON payload exists, scan standard directory for any .qif files
        let standardPath = dataDirectoryURL.path
        var loadedAccounts: [Account] = []
        if let items = try? FileManager.default.contentsOfDirectory(atPath: standardPath) {
            for item in items where item.lowercased().hasSuffix(".qif") {
                let fullPath = (standardPath as NSString).appendingPathComponent(item)
                if let acct = try? QIFParser.parseFile(at: fullPath) {
                    loadedAccounts.append(acct)
                }
            }
        }

        if !loadedAccounts.isEmpty {
            self.accounts = loadedAccounts.sorted { $0.name < $1.name }
            self.selectedAccountId = self.accounts.first?.id
            if let firstId = self.selectedAccountId {
                self.multiSelectedAccountIds = [firstId]
            }
        } else {
            // Open completely empty if there is no data
            self.accounts = []
            self.scheduledBills = []
            self.budgetCategories = []
            self.selectedAccountId = nil
        }
    }

    public func saveStandardData() {
        // Automatic backup before saving to prevent any data loss
        if FileManager.default.fileExists(atPath: dataFileURL.path) {
            let backupDir = dataDirectoryURL.appendingPathComponent("Backups", isDirectory: true)
            try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let backupFile = backupDir.appendingPathComponent("haste_data_latest.json")
            try? FileManager.default.removeItem(at: backupFile)
            try? FileManager.default.copyItem(at: dataFileURL, to: backupFile)
        }

        let payload = HasteDataPayload(
            accounts: accounts,
            scheduledBills: scheduledBills,
            budgetCategories: budgetCategories
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: dataFileURL, options: .atomic)
        }
    }

    public var selectedAccount: Account? {
        guard let id = selectedAccountId else { return accounts.first }
        return accounts.first { $0.id == id }
    }

    public var allTransactions: [Transaction] {
        accounts.flatMap { $0.transactions }.sorted { $0.date > $1.date }
    }

    public var filteredTransactions: [Transaction] {
        let baseList = selectedAccount?.transactions.sorted { $0.date > $1.date } ?? allTransactions
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return baseList
        }
        let q = searchQuery.lowercased()
        return baseList.filter {
            $0.payee.lowercased().contains(q) ||
            $0.category.lowercased().contains(q) ||
            $0.memo.lowercased().contains(q) ||
            $0.checkNumber.lowercased().contains(q) ||
            String(format: "%.2f", $0.amount).contains(q)
        }
    }

    public var netWorth: Double {
        accounts.reduce(0.0) { $0 + $1.balance }
    }

    public var totalInflow: Double {
        allTransactions.filter { $0.amount > 0 }.reduce(0.0) { $0 + $1.amount }
    }

    public var totalOutflow: Double {
        allTransactions.filter { $0.amount < 0 }.reduce(0.0) { $0 + abs($1.amount) }
    }

    public var categorySpending: [(category: String, amount: Double)] {
        var breakdown: [String: Double] = [:]
        for tx in allTransactions where tx.amount < 0 {
            let cat = tx.category.isEmpty ? "Uncategorized" : tx.category
            breakdown[cat, default: 0.0] += abs(tx.amount)
        }
        return breakdown.map { ($0.key, $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    public func actualSpending(for category: String) -> Double {
        allTransactions
            .filter { $0.category.localizedCaseInsensitiveContains(category) && $0.amount < 0 }
            .reduce(0.0) { $0 + abs($1.amount) }
    }

    public func actualIncome(for category: String) -> Double {
        allTransactions
            .filter { $0.category.localizedCaseInsensitiveContains(category) && $0.amount > 0 }
            .reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Transaction Modification & Balance Recalculation

    public func addTransaction(to accountId: String, transaction: Transaction) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        accounts[idx].transactions.append(transaction)
        recalculateBalances(for: accountId)
    }

    public func updateTransaction(_ tx: Transaction) {
        for aIdx in 0..<accounts.count {
            if let tIdx = accounts[aIdx].transactions.firstIndex(where: { $0.id == tx.id }) {
                accounts[aIdx].transactions[tIdx] = tx
                recalculateBalances(for: accounts[aIdx].id)
                return
            }
        }
    }

    public func deleteTransaction(id: UUID) {
        for aIdx in 0..<accounts.count {
            if let tIdx = accounts[aIdx].transactions.firstIndex(where: { $0.id == id }) {
                let acctId = accounts[aIdx].id
                accounts[aIdx].transactions.remove(at: tIdx)
                recalculateBalances(for: acctId)
                return
            }
        }
    }

    public func recalculateBalances(for accountId: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        accounts[idx].transactions.sort { $0.date < $1.date }
        var running = 0.0
        for i in 0..<accounts[idx].transactions.count {
            running += accounts[idx].transactions[i].amount
            accounts[idx].transactions[i].runningBalance = running
        }
        accounts[idx].balance = running
        saveStandardData()
    }

    // MARK: - Account Management

    public func createAccount(name: String, type: AccountType, openingBalance: Double = 0.0, openingDate: Date = Date()) {
        var txs: [Transaction] = []
        if openingBalance != 0.0 {
            let openTx = Transaction(
                accountName: name,
                date: openingDate,
                dateString: Transaction.formatDate(openingDate),
                payee: "Opening Balance",
                memo: "Account Setup",
                category: "[Opening Balance]",
                amount: openingBalance,
                clearedStatus: "R",
                runningBalance: openingBalance
            )
            txs.append(openTx)
        }
        let newAcct = Account(
            name: name,
            type: type,
            balance: openingBalance,
            transactions: txs
        )
        accounts.append(newAcct)
        selectedAccountId = newAcct.id
        multiSelectedAccountIds = [newAcct.id]
        activeQuickTab = "register"
        saveStandardData()
    }

    public func renameAccount(id: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        let oldName = accounts[idx].name
        guard oldName != trimmed else { return }

        accounts[idx].name = trimmed

        // Update transactions under this account
        for tIdx in 0..<accounts[idx].transactions.count {
            accounts[idx].transactions[tIdx].accountName = trimmed
        }

        // Update any scheduled bills referencing old name
        for bIdx in 0..<scheduledBills.count {
            if scheduledBills[bIdx].accountName == oldName {
                scheduledBills[bIdx].accountName = trimmed
            }
        }

        saveStandardData()
    }

    public func deleteAccount(id: String) {
        accounts.removeAll { $0.id == id }
        multiSelectedAccountIds.remove(id)
        if selectedAccountId == id {
            selectedAccountId = accounts.first?.id
            if let first = selectedAccountId {
                multiSelectedAccountIds = [first]
            }
        }
        saveStandardData()
    }

    // MARK: - Reordering & Merging Accounts

    public func reorderAccount(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0, fromIndex < accounts.count else { return }
        var dest = toIndex
        if dest > fromIndex {
            dest -= 1
        }
        guard dest >= 0, dest < accounts.count, dest != fromIndex else { return }
        let moved = accounts.remove(at: fromIndex)
        accounts.insert(moved, at: dest)
        saveStandardData()
    }

    public func moveAccount(id: String, before targetId: String) {
        guard let sourceIndex = accounts.firstIndex(where: { $0.id == id }),
              let targetIndex = accounts.firstIndex(where: { $0.id == targetId }),
              sourceIndex != targetIndex else { return }
        let item = accounts.remove(at: sourceIndex)
        let newTargetIndex = accounts.firstIndex(where: { $0.id == targetId }) ?? targetIndex
        accounts.insert(item, at: newTargetIndex)
        saveStandardData()
    }

    public func moveAccount(id: String, after targetId: String) {
        guard let sourceIndex = accounts.firstIndex(where: { $0.id == id }),
              let targetIndex = accounts.firstIndex(where: { $0.id == targetId }),
              sourceIndex != targetIndex else { return }
        let item = accounts.remove(at: sourceIndex)
        let newTargetIndex = accounts.firstIndex(where: { $0.id == targetId }) ?? targetIndex
        accounts.insert(item, at: min(newTargetIndex + 1, accounts.count))
        saveStandardData()
    }

    @discardableResult
    public func mergeAccounts(
        sourceAccountIds: [String],
        targetAccountId: String,
        deduplicateTransactions: Bool = true
    ) -> (importedCount: Int, skippedCount: Int) {
        guard let targetIndex = accounts.firstIndex(where: { $0.id == targetAccountId }) else {
            return (0, 0)
        }
        let targetName = accounts[targetIndex].name

        var targetTransactions = accounts[targetIndex].transactions
        var existingSignatureSet = Set<String>()
        for tx in targetTransactions {
            let sig = "\(tx.dateString)|\(String(format: "%.2f", tx.amount))|\(tx.payee.trimmingCharacters(in: .whitespaces).lowercased())"
            existingSignatureSet.insert(sig)
        }

        var importedCount = 0
        var skippedCount = 0
        var removedSourceNames = [String]()

        for sourceId in sourceAccountIds where sourceId != targetAccountId {
            guard let sIdx = accounts.firstIndex(where: { $0.id == sourceId }) else { continue }
            let sourceAccount = accounts[sIdx]
            removedSourceNames.append(sourceAccount.name)

            for var tx in sourceAccount.transactions {
                let sig = "\(tx.dateString)|\(String(format: "%.2f", tx.amount))|\(tx.payee.trimmingCharacters(in: .whitespaces).lowercased())"
                if deduplicateTransactions && existingSignatureSet.contains(sig) {
                    skippedCount += 1
                    continue
                }
                tx.accountName = targetName
                targetTransactions.append(tx)
                existingSignatureSet.insert(sig)
                importedCount += 1
            }
        }

        // Apply updated transactions to target
        accounts[targetIndex].transactions = targetTransactions
        recalculateBalances(for: targetAccountId)

        // Remove source accounts
        accounts.removeAll { acct in
            sourceAccountIds.contains(acct.id) && acct.id != targetAccountId
        }

        // Update any scheduled bills referencing old account names
        for i in 0..<scheduledBills.count {
            if removedSourceNames.contains(scheduledBills[i].accountName) {
                scheduledBills[i].accountName = targetName
            }
        }

        // Reset multi-selection and select target account
        multiSelectedAccountIds.removeAll()
        selectedAccountId = targetAccountId
        activeQuickTab = "register"

        saveStandardData()
        return (importedCount, skippedCount)
    }

    // MARK: - Reconcile Logic

    public func startReconciliation(statementEndingBalance: Double, statementDate: Date) {
        guard let acct = selectedAccount else { return }
        reconcileStatementBalance = statementEndingBalance
        reconcileStatementDate = statementDate
        let initiallyCleared = acct.transactions.filter { $0.isCleared }.map { $0.id }
        reconcileClearedIds = Set(initiallyCleared)
        isReconcileSheetPresented = true
    }

    public func toggleReconcileCleared(txId: UUID) {
        if reconcileClearedIds.contains(txId) {
            reconcileClearedIds.remove(txId)
        } else {
            reconcileClearedIds.insert(txId)
        }
    }

    public func markAllReconcileCleared(_ cleared: Bool) {
        guard let acct = selectedAccount else { return }
        if cleared {
            reconcileClearedIds = Set(acct.transactions.map { $0.id })
        } else {
            reconcileClearedIds.removeAll()
        }
    }

    public func reconcileClearedBalance(for account: Account) -> Double {
        account.transactions
            .filter { reconcileClearedIds.contains($0.id) }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func reconcileDifference(for account: Account) -> Double {
        let cleared = reconcileClearedBalance(for: account)
        return cleared - reconcileStatementBalance
    }

    public func finishReconciliation(autoAdjust: Bool = false) {
        guard let acct = selectedAccount, let aIdx = accounts.firstIndex(where: { $0.id == acct.id }) else {
            isReconcileSheetPresented = false
            return
        }

        let diff = reconcileDifference(for: acct)
        if abs(diff) > 0.001 && autoAdjust {
            let adjTx = Transaction(
                accountName: acct.name,
                date: reconcileStatementDate,
                dateString: Transaction.formatDate(reconcileStatementDate),
                payee: "Balance Adjustment",
                memo: "Reconcile Adjustment",
                category: "Misc",
                amount: -diff,
                clearedStatus: "R"
            )
            accounts[aIdx].transactions.append(adjTx)
            reconcileClearedIds.insert(adjTx.id)
        }

        for i in 0..<accounts[aIdx].transactions.count {
            let tid = accounts[aIdx].transactions[i].id
            if reconcileClearedIds.contains(tid) {
                accounts[aIdx].transactions[i].clearedStatus = "R"
            }
        }

        recalculateBalances(for: acct.id)
        isReconcileSheetPresented = false
    }

    // MARK: - Write Checks & Bills

    public func recordCheck(payee: String, amount: Double, date: Date, memo: String, category: String, checkNumber: String = "Print") {
        guard let acct = selectedAccount ?? accounts.first(where: { $0.type == .bank }) ?? accounts.first else { return }
        let tx = Transaction(
            accountName: acct.name,
            date: date,
            dateString: Transaction.formatDate(date),
            checkNumber: checkNumber,
            payee: payee,
            memo: memo,
            category: category,
            amount: -abs(amount),
            clearedStatus: ""
        )
        addTransaction(to: acct.id, transaction: tx)
    }

    public func recordBillInRegister(bill: ScheduledBill) {
        guard let targetAcct = accounts.first(where: { $0.name == bill.accountName }) ?? selectedAccount ?? accounts.first else { return }
        let tx = Transaction(
            accountName: targetAcct.name,
            date: bill.nextDueDate,
            dateString: Transaction.formatDate(bill.nextDueDate),
            payee: bill.payee,
            memo: bill.memo,
            category: bill.category,
            amount: -abs(bill.amount),
            clearedStatus: ""
        )
        addTransaction(to: targetAcct.id, transaction: tx)

        if let bIdx = scheduledBills.firstIndex(where: { $0.id == bill.id }) {
            scheduledBills[bIdx].isPaid = true
            // advance date if recurring
            let cal = Calendar.current
            switch bill.frequency {
            case .monthly:
                scheduledBills[bIdx].nextDueDate = cal.date(byAdding: .month, value: 1, to: bill.nextDueDate) ?? bill.nextDueDate
                scheduledBills[bIdx].isPaid = false
            case .weekly:
                scheduledBills[bIdx].nextDueDate = cal.date(byAdding: .weekOfYear, value: 1, to: bill.nextDueDate) ?? bill.nextDueDate
                scheduledBills[bIdx].isPaid = false
            case .biweekly:
                scheduledBills[bIdx].nextDueDate = cal.date(byAdding: .day, value: 14, to: bill.nextDueDate) ?? bill.nextDueDate
                scheduledBills[bIdx].isPaid = false
            case .quarterly:
                scheduledBills[bIdx].nextDueDate = cal.date(byAdding: .month, value: 3, to: bill.nextDueDate) ?? bill.nextDueDate
                scheduledBills[bIdx].isPaid = false
            case .annually:
                scheduledBills[bIdx].nextDueDate = cal.date(byAdding: .year, value: 1, to: bill.nextDueDate) ?? bill.nextDueDate
                scheduledBills[bIdx].isPaid = false
            case .once:
                break
            }
            saveStandardData()
        }
    }

    // MARK: - Directory Loading & File IO

    public func loadDefaultQuickenData() {
        loadStandardData()
    }

    public func loadDirectory(path: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return }

        loadedDirectoryPath = path
        var loadedAccounts: [Account] = []
        var loadedQDFs: [QDFMetadata] = []
        var loadedQSDs: [QSDMetadata] = []

        if let enumerator = fileManager.enumerator(atPath: path) {
            while let element = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(element)
                let ext = (element as NSString).pathExtension.lowercased()

                if ext == "qif" {
                    if let acct = try? QIFParser.parseFile(at: fullPath) {
                        loadedAccounts.append(acct)
                    }
                } else if ext == "qdf" {
                    if let qdf = try? QDFInspector.inspectFile(at: fullPath) {
                        loadedQDFs.append(qdf)
                    }
                } else if ext == "qsd" {
                    if let qsd = try? QSDParser.parseFile(at: fullPath) {
                        loadedQSDs.append(qsd)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.accounts = loadedAccounts.sorted { $0.name < $1.name }
            self.qdfFiles = loadedQDFs.sorted { $0.filePath < $1.filePath }
            self.qsdFiles = loadedQSDs.sorted { $0.filePath < $1.filePath }
            if self.selectedAccountId == nil, let first = self.accounts.first {
                self.selectedAccountId = first.id
            }
        }
    }

    public func exportTransactionsCSV(for account: Account?) -> String {
        let txs = account?.transactions ?? allTransactions
        var csv = "Date,CheckNum,Payee,Category,Memo,Amount,Cleared,RunningBalance\n"
        for t in txs {
            let cleanPayee = t.payee.replacingOccurrences(of: "\"", with: "\"\"")
            let cleanCat = t.category.replacingOccurrences(of: "\"", with: "\"\"")
            let cleanMemo = t.memo.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(t.dateString),\"\(t.checkNumber)\",\"\(cleanPayee)\",\"\(cleanCat)\",\"\(cleanMemo)\",\(t.amount),\"\(t.clearedStatus)\",\(t.runningBalance)\n"
        }
        return csv
    }
}
