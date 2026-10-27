import SwiftUI

public struct ContentView: View {
    @ObservedObject var store: DataStore
    @State private var isSidebarVisible: Bool = true
    @State private var showingNewAccountSheet: Bool = false
    @State private var showingImportExportSheet: Bool = false
    @State private var importExportMode: TransferMode = .importData

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
}
