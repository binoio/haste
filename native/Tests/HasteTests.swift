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

        // Test 14: DatasetScanner Multi-Era & Deduplication
        let quickenDataPath = home.appendingPathComponent("Downloads/Quicken Data").path
        if FileManager.default.fileExists(atPath: quickenDataPath) {
            let scan = DatasetScanner.scan(path: quickenDataPath)
            assert(scan.hasAccounts, "DatasetScanner detected accounts across financial eras")
            assert(scan.discoveredAccounts.count >= 6, "DatasetScanner found at least 6 accounts (got \(scan.discoveredAccounts.count))")
            assert(scan.totalTransactions > 100, "DatasetScanner counted > 100 total transactions (got \(scan.totalTransactions))")

            let acctNames = scan.discoveredAccounts.map { $0.name.lowercased() }
            let uniqueCount = Set(acctNames).count
            assert(acctNames.count == uniqueCount, "DatasetScanner discovered accounts are completely deduplicated (got \(acctNames.count) unique accounts, 0 duplicates)")

            let hasPC0102 = scan.discoveredAccounts.contains { $0.era.contains("2001–2002") }
            assert(hasPC0102, "DatasetScanner discovered 2001–2002 PC Era accounts")
            let hasMacOFX = scan.discoveredAccounts.contains { $0.era.contains("2003–2007") }
            assert(hasMacOFX, "DatasetScanner discovered 2003–2007 Mac Era accounts")
        }

        // Test 15: OFXParser
        let sampleOFX = """
        <OFX><CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS>
        <CCACCTFROM><ACCTID>1234567890</CCACCTFROM>
        <BANKTRANLIST>
        <STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20040515120000<TRNAMT>-45.50<FITID>TEST001<NAME>Test Merchant</STMTTRN>
        <STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20040520120000<TRNAMT>150.00<FITID>TEST002<NAME>Payment Received</STMTTRN>
        </BANKTRANLIST>
        </CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>
        """
        let parsedOfx = OFXParser.parse(content: sampleOFX, defaultName: "Test Card")
        assert(parsedOfx.count == 1, "OFX parsed 1 account (got \(parsedOfx.count))")
        assert(parsedOfx.first?.transactions.count == 2, "OFX parsed 2 transactions (got \(parsedOfx.first?.transactions.count ?? 0))")
        assert(abs((parsedOfx.first?.balance ?? 0) - 104.50) < 0.01, "OFX calculated correct balance $104.50 (got \(parsedOfx.first?.balance ?? 0))")

        // Test 16: Account Reordering
        let testStore = DataStore()
        let acctA = Account(id: "id_a", name: "Account Alpha", type: .bank)
        let acctB = Account(id: "id_b", name: "Account Beta", type: .bank)
        let acctC = Account(id: "id_c", name: "Account Gamma", type: .bank)
        testStore.accounts = [acctA, acctB, acctC]

        testStore.moveAccount(id: "id_c", before: "id_a")
        assert(testStore.accounts.map { $0.id } == ["id_c", "id_a", "id_b"], "Moved Gamma before Alpha")

        testStore.moveAccount(id: "id_b", before: "id_a")
        assert(testStore.accounts.map { $0.id } == ["id_c", "id_b", "id_a"], "Moved Beta before Alpha")

        testStore.moveAccount(id: "id_c", after: "id_a")
        assert(testStore.accounts.map { $0.id } == ["id_b", "id_a", "id_c"], "Moved Gamma after Alpha")

        // Test 17: Account Merging with Deduplication
        let date1 = Date(timeIntervalSince1970: 1020000000)
        let date2 = Date(timeIntervalSince1970: 1020086400)
        let date3 = Date(timeIntervalSince1970: 1020172800)

        let txA1 = Transaction(accountName: "Target Checking", date: date1, payee: "Target", amount: -25.00)
        let txA2 = Transaction(accountName: "Target Checking", date: date2, payee: "Grocery Store", amount: -50.00)
        let mergeTarget = Account(id: "target_acct", name: "Target Checking", type: .bank, balance: -75.00, transactions: [txA1, txA2])

        let txB1 = Transaction(accountName: "Old Checking", date: date1, payee: "Target", amount: -25.00) // Duplicate
        let txB2 = Transaction(accountName: "Old Checking", date: date3, payee: "Gas Station", amount: -30.00) // Unique
        let mergeSource = Account(id: "source_acct", name: "Old Checking", type: .bank, balance: -55.00, transactions: [txB1, txB2])

        testStore.accounts = [mergeTarget, mergeSource]
        testStore.scheduledBills = [ScheduledBill(payee: "Electric Co", amount: 65.00, frequency: .monthly, nextDueDate: date3, accountName: "Old Checking")]

        let mergeRes = testStore.mergeAccounts(sourceAccountIds: ["source_acct"], targetAccountId: "target_acct", deduplicateTransactions: true)
        assert(mergeRes.importedCount == 1, "Merge imported 1 unique transaction (got \(mergeRes.importedCount))")
        assert(mergeRes.skippedCount == 1, "Merge skipped 1 duplicate transaction (got \(mergeRes.skippedCount))")
        assert(testStore.accounts.count == 1, "Source account was removed after merge")
        assert(testStore.accounts.first?.id == "target_acct", "Target account preserved")
        assert(testStore.accounts.first?.transactions.count == 3, "Target account has 3 total transactions (got \(testStore.accounts.first?.transactions.count ?? 0))")
        assert(abs((testStore.accounts.first?.balance ?? 0) - (-105.00)) < 0.01, "Target account balance is -$105.00 (got \(testStore.accounts.first?.balance ?? 0))")
        assert(testStore.scheduledBills.first?.accountName == "Target Checking", "Scheduled bill account name was updated to target account name")

        // Test 18: Account Merging with Deduplication Disabled
        let txC1 = Transaction(accountName: "Account C", date: date1, payee: "ATM", amount: -40.00)
        let acctC_obj = Account(id: "acct_c", name: "Account C", type: .bank, balance: -40.00, transactions: [txC1])
        let txD1 = Transaction(accountName: "Account D", date: date1, payee: "ATM", amount: -40.00)
        let acctD_obj = Account(id: "acct_d", name: "Account D", type: .bank, balance: -40.00, transactions: [txD1])

        testStore.accounts = [acctC_obj, acctD_obj]
        let mergeResNoDedup = testStore.mergeAccounts(sourceAccountIds: ["acct_d"], targetAccountId: "acct_c", deduplicateTransactions: false)
        assert(mergeResNoDedup.importedCount == 1, "Non-deduplicated merge imported identical transaction (got \(mergeResNoDedup.importedCount))")
        assert(mergeResNoDedup.skippedCount == 0, "Non-deduplicated merge skipped 0 transactions")
        assert(testStore.accounts.first?.transactions.count == 2, "Account C has 2 transactions when deduplication is false")
        assert(abs((testStore.accounts.first?.balance ?? 0) - (-80.00)) < 0.01, "Account C balance is -$80.00")

        // Test 19: Multi-Account Merge (2 sources into 1 target)
        let txE1 = Transaction(accountName: "Account E", date: date1, payee: "Payroll", amount: 1000.00)
        let acctE = Account(id: "acct_e", name: "Account E", type: .bank, balance: 1000.00, transactions: [txE1])
        let txF1 = Transaction(accountName: "Account F", date: date2, payee: "Dinner", amount: -45.00)
        let acctF = Account(id: "acct_f", name: "Account F", type: .creditCard, balance: -45.00, transactions: [txF1])
        let txG1 = Transaction(accountName: "Account G", date: date3, payee: "Coffee", amount: -5.00)
        let acctG = Account(id: "acct_g", name: "Account G", type: .cash, balance: -5.00, transactions: [txG1])

        testStore.accounts = [acctE, acctF, acctG]
        let multiMergeRes = testStore.mergeAccounts(sourceAccountIds: ["acct_f", "acct_g"], targetAccountId: "acct_e", deduplicateTransactions: true)
        assert(multiMergeRes.importedCount == 2, "Multi-merge imported 2 transactions (got \(multiMergeRes.importedCount))")
        assert(testStore.accounts.count == 1, "Both source accounts removed")
        assert(testStore.accounts.first?.transactions.count == 3, "Account E has 3 total transactions")
        assert(abs((testStore.accounts.first?.balance ?? 0) - 950.00) < 0.01, "Account E balance is $950.00 (got \(testStore.accounts.first?.balance ?? 0))")

        // Test 20: Account Rename and Referential Updates
        let txRen = Transaction(accountName: "Old Checking", date: date1, payee: "Shop", amount: -15.00)
        let acctRen = Account(id: "acct_ren", name: "Old Checking", type: .bank, balance: -15.00, transactions: [txRen])
        testStore.accounts = [acctRen]
        testStore.scheduledBills = [ScheduledBill(payee: "Internet Co", amount: 50.00, frequency: .monthly, nextDueDate: date1, accountName: "Old Checking")]

        testStore.renameAccount(id: "acct_ren", newName: "Primary Checking")
        assert(testStore.accounts.first?.name == "Primary Checking", "Account renamed to Primary Checking")
        assert(testStore.accounts.first?.transactions.first?.accountName == "Primary Checking", "Transaction accountName updated to Primary Checking")
        assert(testStore.scheduledBills.first?.accountName == "Primary Checking", "Scheduled bill accountName updated to Primary Checking")

        // Test 21: Account Delete
        testStore.deleteAccount(id: "acct_ren")
        assert(testStore.accounts.isEmpty, "Account removed on delete")
        assert(!testStore.multiSelectedAccountIds.contains("acct_ren"), "Deleted account removed from multi-selection")

        print("\nSummary: \(passed) passed, \(failed) failed.")
        return failed == 0
    }
}
