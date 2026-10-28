import Foundation

public final class QIFParser {
    public static func parseDate(_ raw: String) -> (Date, String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return (Date(timeIntervalSince1970: 0), "")
        }

        // Handle Quicken era apostrophe syntax: "8/ 1' 1" -> 2001-08-01, "12/28'99" -> 1999-12-28
        var normalized = trimmed.replacingOccurrences(of: "' ", with: "/")
        normalized = normalized.replacingOccurrences(of: "'", with: "/")
        normalized = normalized.replacingOccurrences(of: " ", with: "")

        let parts = normalized.split(separator: "/")
        if parts.count == 3,
           let m = Int(parts[0]),
           let d = Int(parts[1]),
           var y = Int(parts[2]) {
            if y < 70 {
                y += 2000
            } else if y < 100 {
                y += 1900
            }

            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = d
            comps.hour = 12
            if let date = Calendar.current.date(from: comps) {
                let display = String(format: "%04d-%02d-%02d", y, m, d)
                return (date, display)
            }
        }

        return (Date(timeIntervalSince1970: 0), trimmed)
    }

    public static func formatQIFDate(_ date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        let y = (comps.year ?? 2000) % 100
        return "\(m)/\(d)'\(String(format: "%02d", y))"
    }

    public static func parse(content: String, accountName: String) -> Account {
        var accountType: AccountType = .bank
        var transactions: [Transaction] = []

        var curDate: Date = Date(timeIntervalSince1970: 0)
        var curDateString: String = ""
        var curAmount: Double = 0.0
        var curPayee: String = ""
        var curMemo: String = ""
        var curCategory: String = ""
        var curCheckNum: String = ""
        var curCleared: String = ""
        var curSplits: [SplitItem] = []
        var tempSplitCategory: String = ""
        var tempSplitMemo: String = ""

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("!Type:") {
                let typeStr = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                switch typeStr.lowercased() {
                case "bank": accountType = .bank
                case "ccard": accountType = .creditCard
                case "cash": accountType = .cash
                case "invst": accountType = .investment
                default: accountType = .bank
                }
                continue
            }

            let prefix = trimmed.prefix(1)
            let val = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)

            switch prefix {
            case "D":
                let (d, s) = parseDate(val)
                curDate = d
                curDateString = s
            case "T", "U":
                let clean = val.replacingOccurrences(of: ",", with: "")
                if let amt = Double(clean) {
                    curAmount = amt
                }
            case "C":
                curCleared = val
            case "P":
                curPayee = val
            case "M":
                curMemo = val
            case "L":
                curCategory = val
            case "N":
                curCheckNum = val
            case "S":
                tempSplitCategory = val
            case "E":
                tempSplitMemo = val
            case "$":
                let clean = val.replacingOccurrences(of: ",", with: "")
                let splitAmt = Double(clean) ?? 0.0
                curSplits.append(SplitItem(category: tempSplitCategory, memo: tempSplitMemo, amount: splitAmt))
                tempSplitCategory = ""
                tempSplitMemo = ""
            case "^":
                // End of transaction record (only record if date is valid)
                if !curDateString.isEmpty {
                    let tx = Transaction(
                        accountName: accountName,
                        date: curDate,
                        dateString: curDateString,
                        checkNumber: curCheckNum,
                        payee: curPayee,
                        memo: curMemo,
                        category: curCategory,
                        amount: curAmount,
                        clearedStatus: curCleared,
                        splits: curSplits,
                        runningBalance: 0.0
                    )
                    transactions.append(tx)
                }

                // Reset record state
                curDate = Date(timeIntervalSince1970: 0)
                curDateString = ""
                curAmount = 0.0
                curPayee = ""
                curMemo = ""
                curCategory = ""
                curCheckNum = ""
                curCleared = ""
                curSplits = []
                tempSplitCategory = ""
                tempSplitMemo = ""
            default:
                break
            }
        }

        // Sort chronologically ascending to compute running balances correctly
        transactions.sort { $0.date < $1.date }

        var running = 0.0
        for i in 0..<transactions.count {
            running += transactions[i].amount
            transactions[i].runningBalance = running
        }

        return Account(
            name: accountName,
            type: accountType,
            balance: running,
            transactions: transactions
        )
    }

    public static func parseFile(at path: String) throws -> Account {
        let url = URL(fileURLWithPath: path)
        let name = url.deletingPathExtension().lastPathComponent
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)
        var account = parse(content: content, accountName: name)
        account.filePath = path
        return account
    }

    public static func exportQIF(account: Account, startDate: Date? = nil, endDate: Date? = nil) -> String {
        var lines: [String] = []

        let typeTag: String
        switch account.type {
        case .bank: typeTag = "!Type:Bank"
        case .creditCard: typeTag = "!Type:CCard"
        case .cash: typeTag = "!Type:Cash"
        case .investment: typeTag = "!Type:Invst"
        case .asset: typeTag = "!Type:Oth A"
        case .liability: typeTag = "!Type:Oth L"
        }
        lines.append(typeTag)

        let filtered = account.transactions.filter { tx in
            if let s = startDate, tx.date < s { return false }
            if let e = endDate, tx.date > e { return false }
            return true
        }

        for tx in filtered.sorted(by: { $0.date < $1.date }) {
            lines.append("D\(formatQIFDate(tx.date))")
            lines.append(String(format: "T%.2f", tx.amount))
            if !tx.clearedStatus.isEmpty {
                lines.append("C\(tx.clearedStatus)")
            }
            if !tx.checkNumber.isEmpty {
                lines.append("N\(tx.checkNumber)")
            }
            if !tx.payee.isEmpty {
                lines.append("P\(tx.payee)")
            }
            if !tx.memo.isEmpty {
                lines.append("M\(tx.memo)")
            }
            if !tx.category.isEmpty {
                lines.append("L\(tx.category)")
            }
            for split in tx.splits {
                if !split.category.isEmpty {
                    lines.append("S\(split.category)")
                }
                if !split.memo.isEmpty {
                    lines.append("E\(split.memo)")
                }
                lines.append(String(format: "$%.2f", split.amount))
            }
            lines.append("^")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func exportAllAccountsQIF(
        accounts: [Account],
        categories: [BudgetCategory] = [],
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> String {
        var output = ""

        // Export category dictionary (!Type:Cat) if categories are present
        if !categories.isEmpty {
            output += "!Type:Cat\n"
            for cat in categories {
                output += "N\(cat.categoryName)\n"
                output += cat.isIncome ? "I\n" : "E\n"
                output += "^\n"
            }
            output += "\n"
        }

        for acct in accounts {
            output += "!Account\n"
            output += "N\(acct.name)\n"
            output += "T\(acct.type.qifTypeTag)\n"
            output += "^\n"
            output += exportQIF(account: acct, startDate: startDate, endDate: endDate)
            output += "\n"
        }
        return output
    }

    public static func parseMultiAccountQIF(content: String) -> [Account] {
        var accounts: [Account] = []
        var currentAccountName: String = "Imported"
        var currentAccountType: AccountType = .bank
        var currentLines: [String] = []

        enum Section {
            case none
            case categories
            case accountHeader
            case transactions
        }
        var activeSection: Section = .none

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("!") {
                let lower = trimmed.lowercased()
                if lower == "!account" {
                    if activeSection == .transactions && !currentLines.isEmpty {
                        var acct = parse(content: currentLines.joined(separator: "\n"), accountName: currentAccountName)
                        acct.type = currentAccountType
                        if !acct.transactions.isEmpty { accounts.append(acct) }
                        currentLines = []
                    }
                    activeSection = .accountHeader
                    continue
                } else if lower.hasPrefix("!type:cat") || lower.hasPrefix("!type:class") || lower.hasPrefix("!type:memorized") || lower.hasPrefix("!type:budget") || lower.hasPrefix("!type:security") {
                    if activeSection == .transactions && !currentLines.isEmpty {
                        var acct = parse(content: currentLines.joined(separator: "\n"), accountName: currentAccountName)
                        acct.type = currentAccountType
                        if !acct.transactions.isEmpty { accounts.append(acct) }
                        currentLines = []
                    }
                    activeSection = .categories
                    continue
                } else if lower.hasPrefix("!type:") {
                    activeSection = .transactions
                    currentLines.append(trimmed)
                    continue
                }
            }

            switch activeSection {
            case .categories:
                break
            case .accountHeader:
                if trimmed.hasPrefix("N") {
                    currentAccountName = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("T") {
                    let tag = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                    switch tag.lowercased() {
                    case "bank": currentAccountType = .bank
                    case "ccard", "credit card": currentAccountType = .creditCard
                    case "cash": currentAccountType = .cash
                    case "invst", "investment": currentAccountType = .investment
                    case "oth a", "asset": currentAccountType = .asset
                    case "oth l", "liability": currentAccountType = .liability
                    default: currentAccountType = .bank
                    }
                } else if trimmed == "^" {
                    activeSection = .none
                }
            case .transactions, .none:
                currentLines.append(trimmed)
            }
        }

        if !currentLines.isEmpty {
            var acct = parse(content: currentLines.joined(separator: "\n"), accountName: currentAccountName)
            acct.type = currentAccountType
            if !acct.transactions.isEmpty {
                accounts.append(acct)
            }
        }

        return accounts.isEmpty ? [parse(content: content, accountName: "Imported")] : accounts
    }
}
