import Foundation

public struct BudgetCategory: Identifiable, Hashable, Codable {
    public let id: UUID
    public var categoryName: String
    public var isIncome: Bool
    public var monthlyBudget: Double

    public init(
        id: UUID = UUID(),
        categoryName: String,
        isIncome: Bool = false,
        monthlyBudget: Double = 0.0
    ) {
        self.id = id
        self.categoryName = categoryName
        self.isIncome = isIncome
        self.monthlyBudget = monthlyBudget
    }
}
