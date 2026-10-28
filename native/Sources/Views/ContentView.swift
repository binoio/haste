import SwiftUI

public struct ContentView: View {
    @ObservedObject var store: DataStore
    @State private var isSidebarVisible: Bool = true
    @State private var showingNewAccountSheet: Bool = false
    @State private var showingImportExportSheet: Bool = false
    @State private var importExportMode: TransferMode = .importData
    @State private var showingRenameSheet: Bool = false
    @State private var accountToRenameId: String = ""
    @State private var showingDeleteAlert: Bool = false

    public init(store: DataStore = DataStore()) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Haste Activity Bar
            HeaderBannerView(store: store)

            // Main Split Navigation Area
            HStack(alignment: .top, spacing: 0) {
                if isSidebarVisible {
                    SidebarView(store: store)
                        .frame(width: 240)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                        .transition(.move(edge: .leading))

                    Divider()
                }

                mainContentView
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleHasteSidebar)) { _ in
            toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewAccountSheet)) { _ in
            showingNewAccountSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImportSheet)) { _ in
            importExportMode = .importData
            showingImportExportSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExportSheet)) { _ in
            importExportMode = .exportData
            showingImportExportSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMergeAccountsSheet)) { _ in
            prepareAndShowMergeSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRenameAccountSheet)) { _ in
            if let singleId = store.multiSelectedAccountIds.first, store.multiSelectedAccountIds.count == 1 {
                accountToRenameId = singleId
                showingRenameSheet = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestDeleteAccount)) { _ in
            if !store.multiSelectedAccountIds.isEmpty {
                showingDeleteAlert = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar (⌘⌃S)")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Payee, Category, Memo, Check #...", text: $store.searchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 260)
                    if !store.searchQuery.isEmpty {
                        Button(action: { store.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button(action: { showingNewAccountSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .help("New Account (⌘N)")

                    Button(action: {
                        importExportMode = .importData
                        showingImportExportSheet = true
                    }) {
                        Label("Import/Export", systemImage: "arrow.up.arrow.down")
                    }

                    Button(action: openFolder) {
                        Label("Open Data...", systemImage: "folder.badge.plus")
                    }
                }
            }
        }
        .frame(minWidth: 960, minHeight: 650)
        .sheet(isPresented: $showingNewAccountSheet) {
            NewAccountSheet(store: store, isPresented: $showingNewAccountSheet)
        }
        .sheet(isPresented: $showingImportExportSheet) {
            ImportExportSheet(
                store: store,
                isPresented: $showingImportExportSheet,
                mode: $importExportMode
            )
        }
        .sheet(isPresented: $store.isMergeSheetPresented) {
            MergeAccountsSheet(store: store, isPresented: $store.isMergeSheetPresented)
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameAccountSheet(store: store, isPresented: $showingRenameSheet, accountId: accountToRenameId)
        }
        .alert(isPresented: $showingDeleteAlert) {
            let ids = Array(store.multiSelectedAccountIds)
            let count = ids.count
            let targetName = store.accounts.first(where: { $0.id == ids.first })?.name ?? "Account"
            let title = count == 1 ? "Delete \"\(targetName)\"?" : "Delete \(count) Accounts?"
            let message = count == 1
                ? "Are you sure you want to delete this account? All associated transactions will be permanently deleted."
                : "Are you sure you want to delete these \(count) accounts? All associated transactions will be permanently deleted."
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: .destructive(Text("Delete")) {
                    for id in ids {
                        store.deleteAccount(id: id)
                    }
                    store.multiSelectedAccountIds.removeAll()
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        switch store.activeQuickTab {
        case "financialCenter":
            DashboardView(store: store)
        case "register":
            RegisterView(store: store)
        case "writeChecks":
            WriteChecksView(store: store)
        case "reconcile":
            ReconcileView(store: store)
        case "reminders":
            BillsRemindersView(store: store)
        case "budget":
            BudgetView(store: store)
        case "reports":
            ReportsView(store: store)
        default:
            DashboardView(store: store)
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSidebarVisible.toggle()
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Haste Folder"
        if panel.runModal() == .OK, let url = panel.url {
            store.loadDirectory(path: url.path)
        }
    }

    private func prepareAndShowMergeSheet() {
        guard store.accounts.count >= 2 else { return }
        if store.multiSelectedAccountIds.count >= 2 {
            let selectedList = store.accounts.filter { store.multiSelectedAccountIds.contains($0.id) }
            if let first = selectedList.first {
                store.pendingMergeTargetId = first.id
                store.pendingMergeSourceIds = selectedList.dropFirst().map { $0.id }
            }
        } else if let selId = store.selectedAccountId {
            store.pendingMergeSourceIds = [selId]
            store.pendingMergeTargetId = store.accounts.first(where: { $0.id != selId })?.id
        } else {
            store.pendingMergeSourceIds = [store.accounts[0].id]
            store.pendingMergeTargetId = store.accounts[1].id
        }
        store.isMergeSheetPresented = true
    }
}
