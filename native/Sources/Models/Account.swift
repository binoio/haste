import Foundation

public enum AccountType: String, Codable, CaseIterable, Identifiable {
    case bank = "Bank"
    case creditCard = "Credit Card"
    case cash = "Cash"
    case investment = "Investment"
    case asset = "Asset"
    case liability = "Liability"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .bank: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .cash: return "banknote.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .asset: return "house.fill"
        case .liability: return "doc.text.fill"
        }
    }

    public var qifTypeTag: String {
        switch self {
        case .bank: return "Bank"
        case .creditCard: return "CCard"
        case .cash: return "Cash"
        case .investment: return "Invst"
        case .asset: return "Oth A"
        case .liability: return "Oth L"
        }
    }
}

public struct Account: Identifiable, Hashable, Codable {
    public let id: String
    public var name: String
    public var type: AccountType
    public var balance: Double
    public var transactions: [Transaction]
    public var filePath: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: AccountType = .bank,
        balance: Double = 0.0,
        transactions: [Transaction] = [],
        filePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.transactions = transactions
        self.filePath = filePath
    }

    public var clearedBalance: Double {
        transactions.filter { $0.isCleared }.reduce(0.0) { $0 + $1.amount }
    }
}
