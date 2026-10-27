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

public final class DataStore: ObservableObject {
    public static let shared = DataStore()

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

    public init() {
        initDefaultBudgetsAndBills()
        loadDefaultQuickenData()
    }

    private func initDefaultBudgetsAndBills() {
        budgetCategories = [
            BudgetCategory(categoryName: "Salary", isIncome: true, monthlyBudget: 4500.0),
            BudgetCategory(categoryName: "Dividend", isIncome: true, monthlyBudget: 150.0),
            BudgetCategory(categoryName: "Mortgage / Rent", isIncome: false, monthlyBudget: 1200.0),
            BudgetCategory(categoryName: "Utilities", isIncome: false, monthlyBudget: 250.0),
            BudgetCategory(categoryName: "Groceries", isIncome: false, monthlyBudget: 500.0),
            BudgetCategory(categoryName: "Auto / Gas", isIncome: false, monthlyBudget: 180.0),
            BudgetCategory(categoryName: "Insurance", isIncome: false, monthlyBudget: 120.0),
            BudgetCategory(categoryName: "Entertainment", isIncome: false, monthlyBudget: 150.0),
            BudgetCategory(categoryName: "Medical", isIncome: false, monthlyBudget: 100.0)
        ]

        let cal = Calendar.current
        let today = Date()
        let nextWeek = cal.date(byAdding: .day, value: 5, to: today) ?? today
        let nextTwoWeeks = cal.date(byAdding: .day, value: 12, to: today) ?? today

        scheduledBills = [
            ScheduledBill(
                payee: "Electric Utility Co.",
                amount: 114.50,
                frequency: .monthly,
                nextDueDate: nextWeek,
                accountName: "Checking",
                category: "Utilities",
                memo: "Monthly power bill"
            ),
            ScheduledBill(
                payee: "Pacific Bell / AT&T",
                amount: 68.20,
                frequency: .monthly,
                nextDueDate: nextTwoWeeks,
                accountName: "Checking",
                category: "Utilities:Telephone",
                memo: "Landline & Internet"
            ),
            ScheduledBill(
                payee: "State Farm Insurance",
                amount: 85.00,
                frequency: .monthly,
                nextDueDate: nextTwoWeeks,
                accountName: "Checking",
                category: "Insurance",
                memo: "Auto policy #2948-1A"
            )
        ]
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
        accounts.sort { $0.name < $1.name }
        selectedAccountId = newAcct.id
        activeQuickTab = "register"
    }

    public func deleteAccount(id: String) {
        accounts.removeAll { $0.id == id }
        if selectedAccountId == id {
            selectedAccountId = accounts.first?.id
        }
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
        }
    }

    // MARK: - Directory Loading & File IO

    public func loadDefaultQuickenData() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetPath = home.appendingPathComponent("Downloads/Quicken Data").path
        loadDirectory(path: targetPath)
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
