import Foundation

public struct TestRunner {
    public static func runAll() -> Bool {
        print("Running Haste Test Suite...")
        var passed = 0
        var failed = 0

        func assert(_ condition: Bool, _ name: String) {
            if condition {
                print("  [PASS] \(name)")
                passed += 1
            } else {
                print("  [FAIL] \(name)")
                failed += 1
            }
        }

        // Test 1: QIF Date Parsing & Formatting
        let (_, s1) = QIFParser.parseDate("8/ 1' 1")
        assert(s1 == "2001-08-01", "Parse QIF date 8/ 1' 1 -> 2001-08-01 (got \(s1))")

        let (d2, s2) = QIFParser.parseDate("12/31'99")
        assert(s2 == "1999-12-31", "Parse QIF date 12/31'99 -> 1999-12-31 (got \(s2))")

        let qifFmt = QIFParser.formatQIFDate(d2)
        assert(qifFmt == "12/31'99", "Format Date to QIF syntax 1999-12-31 -> 12/31'99 (got \(qifFmt))")

        // Test 2: In-Memory QIF Parsing
        let sampleQIF = """
        !Type:Bank
        D8/ 1' 1
        T50.00
        C*
        PPersonal Deposit
        L[Checking]
        ^
        D8/29' 1
        T-2.00
        C*
        PFee
        LBank Charge
        ^
        D9/ 2' 1
        T-20.00
        PStore
        SBooks
        $15.00
        SSnacks
        $5.00
        ^
        """
        var acct = QIFParser.parse(content: sampleQIF, accountName: "TestChecking")
        assert(acct.transactions.count == 3, "Parsed 3 transactions")
        assert(abs(acct.balance - 28.0) < 0.001, "Calculated final balance $28.00 (got \(acct.balance))")
        assert(acct.transactions[2].splits.count == 2, "Parsed 2 split items for transaction 3")
        assert(acct.transactions[0].runningBalance == 50.0, "Transaction 1 running balance == 50.0")
        assert(acct.transactions[1].runningBalance == 48.0, "Transaction 2 running balance == 48.0")
        assert(acct.transactions[2].runningBalance == 28.0, "Transaction 3 running balance == 28.0")

        // Test 3: QIF Export and Round-trip
        let exported = QIFParser.exportQIF(account: acct)
        assert(exported.contains("!Type:Bank"), "Export contains !Type:Bank header")
        assert(exported.contains("PPersonal Deposit"), "Export contains payee Personal Deposit")
        assert(exported.contains("SBooks"), "Export contains split category SBooks")
        let roundtripAcct = QIFParser.parse(content: exported, accountName: "Roundtrip")
        assert(roundtripAcct.transactions.count == 3, "Roundtrip re-parsed 3 transactions")
        assert(abs(roundtripAcct.balance - 28.0) < 0.001, "Roundtrip balance matches $28.00")

        // Test 4: Write Checks NumberToWords
        let words1 = NumberToWords.toCheckWords(amount: 124.50)
        assert(words1 == "One Hundred Twenty-Four and 50/100 Dollars", "Convert $124.50 to check words (got \(words1))")
        let words2 = NumberToWords.toCheckWords(amount: 2500.00)
        assert(words2 == "Two Thousand Five Hundred and 00/100 Dollars", "Convert $2500.00 to check words (got \(words2))")

        // Test 5: Financial Calculators
        let loan = FinancialCalculator.calculateLoan(principal: 250000, annualRatePercent: 6.5, termYears: 30)
        assert(loan.monthlyPayment > 1570 && loan.monthlyPayment < 1590, "Calculated 30-year mortgage monthly payment ~$1580 (got \(loan.monthlyPayment))")
        let savings = FinancialCalculator.calculateSavings(initialDeposit: 10000, monthlyContribution: 500, annualRatePercent: 7.0, years: 10)
        assert(savings.futureValue > 100000, "Calculated 10-year savings future value > $100k (got \(savings.futureValue))")

        // Test 6: Cleared Status and Account Cleared Balance
        acct.transactions[0].clearedStatus = "R"
        acct.transactions[1].clearedStatus = "*"
        acct.transactions[2].clearedStatus = ""
        assert(acct.transactions[0].isReconciled, "Transaction 0 marked reconciled 'R'")
        assert(acct.transactions[1].isCleared, "Transaction 1 marked cleared '*'")
        assert(!acct.transactions[2].isCleared, "Transaction 2 uncleared")
        assert(abs(acct.clearedBalance - 48.0) < 0.001, "Cleared balance equals $48.00 ($50 - $2) (got \(acct.clearedBalance))")

        // Test 7: Scheduled Bills Logic
        let yesterday = Date(timeIntervalSinceNow: -86400)
        let overdueBill = ScheduledBill(payee: "Power Co", amount: 100, frequency: .monthly, nextDueDate: yesterday, accountName: "Checking")
        assert(overdueBill.isOverdue, "Overdue bill correctly identified as overdue")

        // Test 8: CSV Bank Statement Import
        let sampleCSV = """
        Date,CheckNum,Description,Category,Memo,Amount
        2000-05-15,1001,Corner Grocery,Groceries,Weekly food,-85.40
        2000-05-18,,Payroll Direct Deposit,Salary,Biweekly pay,1450.00
        2000-05-20,1002,"Shell Oil, Inc.",Auto:Gas,Fuel,-32.50
        """
        let csvTxs = CSVParser.parse(content: sampleCSV, defaultAccountName: "ImportedChecking")
        assert(csvTxs.count == 3, "Parsed 3 CSV transactions (got \(csvTxs.count))")
        assert(csvTxs[0].checkNumber == "1001", "CSV transaction 0 check # == 1001")
        assert(abs(csvTxs[0].amount - (-85.40)) < 0.001, "CSV transaction 0 amount == -85.40")
        assert(csvTxs[1].amount == 1450.00, "CSV transaction 1 deposit == 1450.00")
        assert(csvTxs[2].payee == "Shell Oil, Inc.", "CSV parsed quoted payee 'Shell Oil, Inc.'")

        // Test 9: Multi-Account QIF Export and Full Data Capture
        let acct2 = Account(name: "Visa Card", type: .creditCard, balance: -150.0, transactions: [
            Transaction(accountName: "Visa Card", date: d2, checkNumber: "7701", payee: "Best Buy", memo: "Electronics", category: "Shopping", amount: -150.0, clearedStatus: "R")
        ])
        let categories = [
            BudgetCategory(categoryName: "Salary", isIncome: true, monthlyBudget: 5000),
            BudgetCategory(categoryName: "Shopping", isIncome: false, monthlyBudget: 300)
        ]
        let multiQif = QIFParser.exportAllAccountsQIF(accounts: [acct, acct2], categories: categories)
        assert(multiQif.contains("!Type:Cat"), "Multi-QIF contains !Type:Cat section")
        assert(multiQif.contains("NSalary\nI"), "Multi-QIF exports Salary as Income category")
        assert(multiQif.contains("!Account\nNTestChecking"), "Multi-QIF contains TestChecking account header")
        assert(multiQif.contains("!Account\nNVisa Card"), "Multi-QIF contains Visa Card account header")
        assert(multiQif.contains("TCCard"), "Multi-QIF maps Credit Card account to standard TCCard tag")

        // Test 9b: Multi-Account QIF Roundtrip Verification
        let parsedMulti = QIFParser.parseMultiAccountQIF(content: multiQif)
        assert(parsedMulti.count == 2, "Re-parsed multi-account QIF has 2 accounts (got \(parsedMulti.count))")
        assert(parsedMulti[0].name == "TestChecking", "Account 0 name is TestChecking")
        assert(parsedMulti[0].transactions.count == 3, "Account 0 has 3 transactions")
        assert(parsedMulti[1].name == "Visa Card", "Account 1 name is Visa Card")
        assert(parsedMulti[1].type == .creditCard, "Account 1 parsed as Credit Card type")
        assert(parsedMulti[1].transactions.count == 1, "Account 1 has 1 transaction")
        assert(parsedMulti[1].transactions[0].payee == "Best Buy", "Account 1 transaction payee is Best Buy")
        assert(parsedMulti[1].transactions[0].checkNumber == "7701", "Account 1 check number captured")
        assert(parsedMulti[1].transactions[0].isReconciled, "Account 1 reconciled flag captured")

        // Test 10: AppSettings Date Formatting
        let settings = AppSettings()
        settings.dateFormatRaw = QuickenDateFormat.standardIso.rawValue
        let isoStr = settings.formatDate(d2)
        assert(isoStr == "1999-12-31", "AppSettings standard ISO format (got \(isoStr))")

        // Test 11: Real QDF File Inspection
        let home = FileManager.default.homeDirectoryForCurrentUser
        let qdfPath = home.appendingPathComponent("Downloads/Quicken Data/MICHAEL'S FINANCES.QDF").path
        if FileManager.default.fileExists(atPath: qdfPath) {
            do {
                let qdf = try QDFInspector.inspectFile(at: qdfPath)
                assert(qdf.isValid, "QDF magic is valid (0x8FBD9EAC)")
                assert(qdf.pageSize == 4088, "QDF page size is 4,088 bytes (0xFF8)")
                assert(qdf.pageCount == 247, "QDF page count is 247 (got \(qdf.pageCount))")
                assert(!qdf.pages.isEmpty && !qdf.pages[0].isEncrypted, "Page 0 has clear header")
                assert(qdf.pages.count > 1 && qdf.pages[1].isEncrypted, "Page 1 is RC5 encrypted")
            } catch {
                assert(false, "Failed to inspect real QDF file: \(error)")
            }
        } else {
            print("  [SKIP] MICHAEL'S FINANCES.QDF not found at path")
        }

        // Test 12: Real QSD File Parsing
        let qsdPath = home.appendingPathComponent("Downloads/Quicken Data/MICHAEL'S FINANCES.QSD").path
        if FileManager.default.fileExists(atPath: qsdPath) {
            do {
                let qsd = try QSDParser.parseFile(at: qsdPath)
                assert(qsd.versionString.contains("QW Ver."), "QSD header signature detected (got \(qsd.versionString))")
                assert(!qsd.extractedStrings.isEmpty, "QSD extracted string tokens count: \(qsd.extractedStrings.count)")
            } catch {
                assert(false, "Failed to parse real QSD file: \(error)")
            }
        } else {
            print("  [SKIP] MICHAEL'S FINANCES.QSD not found at path")
        }

        // Test 13: Real QIF File Parsing
        let qifPath = home.appendingPathComponent("Downloads/Quicken Data/Closed or Inactive Accounts in QIF/fleet-checking.QIF").path
        if FileManager.default.fileExists(atPath: qifPath) {
            do {
                let fleet = try QIFParser.parseFile(at: qifPath)
                assert(fleet.transactions.count == 67, "Parsed Fleet Checking transactions (expected 67, got \(fleet.transactions.count))")
                assert(abs(fleet.balance - 296.98) < 0.01, "Fleet Checking balance is $296.98 (got \(fleet.balance))")
            } catch {
                assert(false, "Failed to parse fleet-checking.QIF: \(error)")
            }
        }

        // Test 14: DatasetScanner
        let quickenDataPath = home.appendingPathComponent("Downloads/Quicken Data").path
        if FileManager.default.fileExists(atPath: quickenDataPath) {
            let scan = DatasetScanner.scan(path: quickenDataPath)
            assert(scan.hasQIFs, "DatasetScanner detected companion QIF accounts")
            assert(scan.discoveredQifs.count >= 6, "DatasetScanner found at least 6 accounts (got \(scan.discoveredQifs.count))")
            assert(scan.totalTransactions > 100, "DatasetScanner counted > 100 total transactions (got \(scan.totalTransactions))")
        }

        print("\nSummary: \(passed) passed, \(failed) failed.")
        return failed == 0
    }
}
