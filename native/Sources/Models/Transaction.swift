import Foundation

public struct SplitItem: Identifiable, Hashable, Codable {
    public let id: UUID
    public var category: String
    public var memo: String
    public var amount: Double

    public init(id: UUID = UUID(), category: String, memo: String = "", amount: Double = 0.0) {
        self.id = id
        self.category = category
        self.memo = memo
        self.amount = amount
    }
}

public struct Transaction: Identifiable, Hashable, Codable {
    public let id: UUID
    public var accountName: String
    public var date: Date
    public var dateString: String
    public var checkNumber: String
    public var payee: String
    public var memo: String
    public var category: String
    public var amount: Double
    public var clearedStatus: String // "*", "c", "R", "X", or ""
    public var splits: [SplitItem]
    public var runningBalance: Double

    public init(
        id: UUID = UUID(),
        accountName: String,
        date: Date,
        dateString: String = "",
        checkNumber: String = "",
        payee: String,
        memo: String = "",
        category: String = "",
        amount: Double,
        clearedStatus: String = "",
        splits: [SplitItem] = [],
        runningBalance: Double = 0.0
    ) {
        self.id = id
        self.accountName = accountName
        self.date = date
        self.dateString = dateString.isEmpty ? Transaction.formatDate(date) : dateString
        self.checkNumber = checkNumber
        self.payee = payee
        self.memo = memo
        self.category = category
        self.amount = amount
        self.clearedStatus = clearedStatus
        self.splits = splits
        self.runningBalance = runningBalance
    }

    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public var isPayment: Bool { amount < 0 }
    public var isDeposit: Bool { amount > 0 }
    public var paymentAmount: Double? { amount < 0 ? abs(amount) : nil }
    public var depositAmount: Double? { amount > 0 ? amount : nil }

    public var isReconciled: Bool {
        let s = clearedStatus.uppercased()
        return s == "R" || s == "X"
    }

    public var isCleared: Bool {
        let s = clearedStatus.uppercased()
        return s == "C" || s == "*" || isReconciled
    }
}
