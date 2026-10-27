import SwiftUI
import UniformTypeIdentifiers

public enum TransferMode: String, CaseIterable, Identifiable {
    case importData = "Import Data"
    case exportData = "Export Data"

    public var id: String { rawValue }
}

public struct ImportExportSheet: View {
    @ObservedObject var store: DataStore
    @Binding var isPresented: Bool
    @Binding var mode: TransferMode
    @Environment(\.openWindow) private var openWindow

    // Import state
    @State private var importFilePath: String = ""
    @State private var selectedTargetAccountId: String = ""
    @State private var importPreviewTxs: [Transaction] = []
    @State private var importStatus: String = ""
    @State private var datasetScan: DatasetScanResult? = nil
    @State private var showingImportWarningDialog: Bool = false
    @State private var warningAccountName: String = ""
    @State private var warningExistingTxCount: Int = 0

    // Export state
    @State private var exportFormat: String = "qif" // "qif" or "csv"
    @State private var exportAllAccounts: Bool = false
    @State private var exportDateRangeAll: Bool = true
    @State private var exportStartDate: Date = Calendar.current.date(from: DateComponents(year: 1999, month: 1, day: 1)) ?? Date()
    @State private var exportEndDate: Date = Date()
    @State private var exportStatus: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: mode == .importData ? "square.and.arrow.down.fill" : "square.and.arrow.up.fill")
                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haste Data Transfer: Import & Export")
                        .font(.headline)
                    Text("Transfer accounts and transactions via Quicken Interchange Format (.QIF) or standard CSV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Picker("", selection: $mode) {
                    ForEach(TransferMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()

            if mode == .importData {
                importView
            } else {
                exportView
            }

            Divider()

            // Footer
            HStack {
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if mode == .importData {
                    Button(action: handleImportButton) {
                        Label("Import \(importPreviewTxs.count) Transactions", systemImage: "arrow.down.doc.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
                    .disabled(importPreviewTxs.isEmpty)
                } else {
                    Button(action: executeExport) {
                        Label("Save Export File...", systemImage: "arrow.up.doc.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 580, height: 460)
        .confirmationDialog(
            "Existing Data Warning",
            isPresented: $showingImportWarningDialog,
            titleVisibility: .visible
        ) {
            Button("Proceed & Merge with Existing Data") {
                executeImport()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The destination account '\(warningAccountName)' already contains \(warningExistingTxCount) transactions.\n\nImporting will merge \(importPreviewTxs.count) transactions into this account register. This action cannot be automatically undone. Do you wish to proceed?")
        }
        .onAppear {
            if let first = store.selectedAccount?.id ?? store.accounts.first?.id {
                selectedTargetAccountId = first
            }
        }
    }

    // MARK: - Import Tab View
    private var importView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Choose a .QIF or .CSV file to import...", text: $importFilePath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse...") {
                    browseImportFile()
                }
            }

            if let scan = datasetScan {
                datasetScanView(scan: scan)
            } else {
                HStack {
                    Text("Target Account:")
                        .font(.caption.bold())
                        .frame(width: 110, alignment: .leading)

                    Picker("", selection: $selectedTargetAccountId) {
                        Text("Create New Account from File").tag("NEW")
                        ForEach(store.accounts) { a in
                            Text(a.name).tag(a.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if !importPreviewTxs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Preview (\(importPreviewTxs.count) Transactions):")
                                .font(.caption.bold())
                            Spacer()
                            let total = importPreviewTxs.reduce(0.0) { $0 + $1.amount }
                            Text(String(format: "Net Flow: $%.2f", total))
                                .font(.caption.monospaced().bold())
                                .foregroundColor(total >= 0 ? .green : .red)
                        }

                        List(importPreviewTxs.prefix(5)) { tx in
                            HStack {
                                Text(tx.dateString).font(.caption2.monospaced()).frame(width: 80, alignment: .leading)
                                Text(tx.payee).font(.caption).lineLimit(1)
                                Spacer()
                                Text(String(format: "$%.2f", tx.amount))
                                    .font(.caption.monospaced().bold())
                                    .foregroundColor(tx.amount < 0 ? .red : .green)
                            }
                        }
                        .frame(height: 120)
                    }
                }
            }

            if !importStatus.isEmpty {
                Text(importStatus)
                    .font(.caption.bold())
                    .foregroundColor(importStatus.contains("Error") ? .red : .green)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Export Tab View
    private var exportView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                Section {
                    Picker("Export Format:", selection: $exportFormat) {
                        Text("Quicken Interchange Format (.QIF)").tag("qif")
                        Text("Comma-Separated Values (.CSV)").tag("csv")
                    }

                    Picker("Export Scope:", selection: $exportAllAccounts) {
                        Text("Current Account (\(store.selectedAccount?.name ?? "Selected"))").tag(false)
                        Text("All Accounts (\(store.accounts.count) Accounts)").tag(true)
                    }

                    Toggle("Export All Dates (Entire History)", isOn: $exportDateRangeAll)

                    if !exportDateRangeAll {
                        DatePicker("From Date:", selection: $exportStartDate, displayedComponents: [.date])
                        DatePicker("To Date:", selection: $exportEndDate, displayedComponents: [.date])
                    }
                } header: {
                    Text("Export Parameters")
                        .font(.headline)
                }
            }

            if !exportStatus.isEmpty {
                Text(exportStatus)
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Dataset Scan Subview
    @ViewBuilder
    private func datasetScanView(scan: DatasetScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: scan.hasQIFs ? "folder.badge.gearshape" : "lock.doc.fill")
                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                Text("Quicken Dataset: \(scan.datasetName)")
                    .font(.subheadline.bold())
                Spacer()
                if scan.hasQIFs {
                    Text("\(scan.discoveredQifs.count) Accounts • \(scan.totalTransactions) Txs")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }

            if scan.hasQIFs {
                Text("Discovered companion QIF exports in dataset. Import all accounts:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(scan.discoveredQifs) { item in
                            HStack {
                                Image(systemName: item.account.type.iconName)
                                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                                    .frame(width: 16)
                                Text(item.name)
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(item.account.transactions.count) txs")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "$%.2f", item.account.balance))
                                    .font(.caption.monospaced().bold())
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 120)

                Button(action: importAllDiscoveredAccounts) {
                    Label("Import All \(scan.discoveredQifs.count) Accounts (\(scan.totalTransactions) Transactions)", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Proprietary Quicken .QDF database with RC5-encrypted pages. Direct raw conversion to QIF:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !scan.extractedAccountNames.isEmpty {
                        Text("Discovered Accounts in .QSD: \(scan.extractedAccountNames.prefix(5).joined(separator: ", "))")
                            .font(.caption.bold())

                        Button("Create Discovered Accounts (\(scan.extractedAccountNames.count))") {
                            createDiscoveredSkeletonAccounts()
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("To Export QIF from QDF:")
                            .font(.caption.bold())
                        Text("1. Open '\(scan.datasetName).QDF' in Quicken (or Quicken 2013 via Wine).\n2. Select File > File Export > QIF File (All Accounts & Dates).\n3. Import the resulting .QIF file directly into Haste.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                    Button("Inspect Binary Structure in Data Format Inspector (⌥⌘D)") {
                        openWindow(id: "data-inspector")
                    }
                    .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(6)
    }

    // MARK: - Import Operations
    private func browseImportFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select File or Folder"
        if panel.runModal() == .OK, let url = panel.url {
            importFilePath = url.path
            loadImportPreview(url: url)
        }
    }

    private func loadImportPreview(url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }

        let ext = url.pathExtension.lowercased()
        if isDir.boolValue || ["qdf", "qsd", "qel"].contains(ext) {
            let scan = DatasetScanner.scan(path: url.path)
            self.datasetScan = scan
            self.importPreviewTxs = []
            if scan.hasQIFs {
                self.importStatus = "Found Quicken dataset '\(scan.datasetName)' with \(scan.discoveredQifs.count) accounts (\(scan.totalTransactions) transactions)."
            } else {
                self.importStatus = "Detected Quicken dataset '\(scan.datasetName)'. See extraction options below."
            }
            return
        }

        self.datasetScan = nil
        do {
            let data = try Data(contentsOf: url)
            let content = String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)

            if ext == "qif" {
                if content.contains("!Account") {
                    let parsedAccts = QIFParser.parseMultiAccountQIF(content: content)
                    importPreviewTxs = parsedAccts.flatMap { $0.transactions }
                    importStatus = "Found \(parsedAccts.count) account(s) with \(importPreviewTxs.count) transactions in multi-account QIF."
                } else {
                    let parsedAcct = QIFParser.parse(content: content, accountName: url.deletingPathExtension().lastPathComponent)
                    importPreviewTxs = parsedAcct.transactions
                    importStatus = "Found \(importPreviewTxs.count) transactions in QIF file."
                }
            } else if ext == "csv" {
                importPreviewTxs = CSVParser.parse(content: content, defaultAccountName: store.selectedAccount?.name ?? "Imported")
                importStatus = "Found \(importPreviewTxs.count) transactions in CSV file."
            }
        } catch {
            importStatus = "Error reading file: \(error.localizedDescription)"
        }
    }

    private func importAllDiscoveredAccounts() {
        guard let scan = datasetScan, scan.hasQIFs else { return }

        var totalImported = 0
        for item in scan.discoveredQifs {
            let acctName = item.account.name.isEmpty ? item.name : item.account.name
            let targetAcctId: String
            if let existing = store.accounts.first(where: { $0.name.caseInsensitiveCompare(acctName) == .orderedSame }) {
                targetAcctId = existing.id
            } else {
                store.createAccount(name: acctName, type: item.account.type)
                targetAcctId = store.selectedAccountId ?? ""
            }

            for tx in item.account.transactions {
                store.addTransaction(to: targetAcctId, transaction: tx)
                totalImported += 1
            }
        }

        importStatus = "Successfully imported all \(scan.discoveredQifs.count) accounts (\(totalImported) transactions)!"
        datasetScan = nil
        importFilePath = ""
    }

    private func createDiscoveredSkeletonAccounts() {
        guard let scan = datasetScan else { return }
        var count = 0
        for name in scan.extractedAccountNames {
            if !store.accounts.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                store.createAccount(name: name, type: .bank)
                count += 1
            }
        }
        importStatus = "Created \(count) account registers from \(scan.datasetName)."
    }

    private func handleImportButton() {
        guard !importPreviewTxs.isEmpty else { return }

        if selectedTargetAccountId == "NEW" {
            let name = URL(fileURLWithPath: importFilePath).deletingPathExtension().lastPathComponent
            if let existing = store.accounts.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }), !existing.transactions.isEmpty {
                warningAccountName = existing.name
                warningExistingTxCount = existing.transactions.count
                showingImportWarningDialog = true
                return
            }
        } else if let existing = store.accounts.first(where: { $0.id == selectedTargetAccountId }), !existing.transactions.isEmpty {
            warningAccountName = existing.name
            warningExistingTxCount = existing.transactions.count
            showingImportWarningDialog = true
            return
        }

        executeImport()
    }

    private func executeImport() {
        guard !importPreviewTxs.isEmpty else { return }

        let targetAcctId: String
        if selectedTargetAccountId == "NEW" {
            let name = URL(fileURLWithPath: importFilePath).deletingPathExtension().lastPathComponent
            store.createAccount(name: name, type: .bank)
            targetAcctId = store.selectedAccountId ?? ""
        } else {
            targetAcctId = selectedTargetAccountId
        }

        for tx in importPreviewTxs {
            store.addTransaction(to: targetAcctId, transaction: tx)
        }

        importStatus = "Successfully imported \(importPreviewTxs.count) transactions!"
        importPreviewTxs = []
        importFilePath = ""
    }

    // MARK: - Export Operations
    private func executeExport() {
        let panel = NSSavePanel()
        let start = exportDateRangeAll ? nil : exportStartDate
        let end = exportDateRangeAll ? nil : exportEndDate

        if exportFormat == "qif" {
            panel.allowedContentTypes = [UTType(filenameExtension: "qif") ?? .plainText]
            panel.nameFieldStringValue = exportAllAccounts ? "Haste_AllAccounts.qif" : "\(store.selectedAccount?.name ?? "Account").qif"
            if panel.runModal() == .OK, let url = panel.url {
                let text: String
                if exportAllAccounts {
                    text = QIFParser.exportAllAccountsQIF(accounts: store.accounts, categories: store.budgetCategories, startDate: start, endDate: end)
                } else if let acct = store.selectedAccount {
                    text = QIFParser.exportQIF(account: acct, startDate: start, endDate: end)
                } else {
                    text = ""
                }
                try? text.write(to: url, atomically: true, encoding: .isoLatin1)
                exportStatus = "QIF file saved to \(url.lastPathComponent)!"
            }
        } else {
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = exportAllAccounts ? "Haste_AllAccounts.csv" : "\(store.selectedAccount?.name ?? "Account").csv"
            if panel.runModal() == .OK, let url = panel.url {
                let csv = store.exportTransactionsCSV(for: exportAllAccounts ? nil : store.selectedAccount)
                try? csv.write(to: url, atomically: true, encoding: .utf8)
                exportStatus = "CSV file saved to \(url.lastPathComponent)!"
            }
        }
    }
}
