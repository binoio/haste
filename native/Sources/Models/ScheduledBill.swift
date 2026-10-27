import Foundation

public enum BillFrequency: String, CaseIterable, Identifiable {
    case once = "Once"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case annually = "Annually"

    public var id: String { rawValue }
}

public struct ScheduledBill: Identifiable, Hashable {
    public let id: UUID
    public var payee: String
    public var amount: Double
    public var frequency: BillFrequency
    public var nextDueDate: Date
    public var accountName: String
    public var category: String
    public var memo: String
    public var isAutoPay: Bool
    public var isPaid: Bool

    public init(
        id: UUID = UUID(),
        payee: String,
        amount: Double,
        frequency: BillFrequency = .monthly,
        nextDueDate: Date,
        accountName: String,
        category: String = "",
        memo: String = "",
        isAutoPay: Bool = false,
        isPaid: Bool = false
    ) {
        self.id = id
        self.payee = payee
        self.amount = amount
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.accountName = accountName
        self.category = category
        self.memo = memo
        self.isAutoPay = isAutoPay
        self.isPaid = isPaid
    }

    public var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: nextDueDate)
    }

    public var isOverdue: Bool {
        !isPaid && nextDueDate < Date()
    }
}
