import SwiftUI

public struct MergeAccountsSheet: View {
    @ObservedObject var store: DataStore
    @Binding var isPresented: Bool

    @State private var selectedSourceIds: Set<String>
    @State private var selectedTargetId: String
    @State private var deduplicateTransactions: Bool = true
    @State private var showingConfirmation: Bool = false

    public init(store: DataStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented

        // Pre-populate sources and target from DataStore
        var sources = Set(store.pendingMergeSourceIds)
        var target = store.pendingMergeTargetId ?? ""

        if sources.isEmpty && !store.multiSelectedAccountIds.isEmpty {
            sources = store.multiSelectedAccountIds
        }

        // Ensure target is distinct from sources
        if target.isEmpty || sources.contains(target) {
            if let availableTarget = store.accounts.first(where: { !sources.contains($0.id) }) {
                target = availableTarget.id
            } else if let firstSource = sources.first {
                target = firstSource
                sources.remove(firstSource)
            }
        }

        if sources.isEmpty {
            if let first = store.accounts.first(where: { $0.id != target }) {
                sources.insert(first.id)
            }
        }

        self._selectedSourceIds = State(initialValue: sources)
        self._selectedTargetId = State(initialValue: target)
    }

    private var targetAccount: Account? {
        store.accounts.first { $0.id == selectedTargetId }
    }

    private var sourceAccounts: [Account] {
        store.accounts.filter { selectedSourceIds.contains($0.id) && $0.id != selectedTargetId }
    }

    private var availableTargetAccounts: [Account] {
        store.accounts.filter { !selectedSourceIds.contains($0.id) }
    }

    private var availableExtraSources: [Account] {
        store.accounts.filter { $0.id != selectedTargetId && !selectedSourceIds.contains($0.id) }
    }

    private var totalSourceTransactions: Int {
        sourceAccounts.reduce(0) { $0 + $1.transactions.count }
    }

    private var totalSourceBalance: Double {
        sourceAccounts.reduce(0.0) { $0 + $1.balance }
    }

    private var isValid: Bool {
        !sourceAccounts.isEmpty && targetAccount != nil && !selectedSourceIds.contains(selectedTargetId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Merge Accounts")
                        .font(.headline)
                    Text("Combine transactions from one or more accounts into a destination account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Source Accounts Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("SOURCE ACCOUNT(S) TO MERGE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if !availableExtraSources.isEmpty {
                                Menu {
                                    ForEach(availableExtraSources) { extra in
                                        Button(extra.name) {
                                            selectedSourceIds.insert(extra.id)
                                        }
                                    }
                                } label: {
                                    Label("Add Account", systemImage: "plus")
                                        .font(.caption)
                                }
                                .menuStyle(.borderlessButton)
                            }
                        }

                        if sourceAccounts.isEmpty {
                            Text("Please select at least one source account below.")
                                .font(.callout)
                                .foregroundColor(.red)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(sourceAccounts) { src in
                                    HStack {
                                        Image(systemName: src.type.iconName)
                                            .foregroundColor(.secondary)
                                        Text(src.name)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("(\(src.transactions.count) txs, \(String(format: "$%.2f", src.balance)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if sourceAccounts.count > 1 {
                                            Button(action: {
                                                selectedSourceIds.remove(src.id)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }

                    // Destination Account Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESTINATION ACCOUNT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedTargetId) {
                            ForEach(availableTargetAccounts) { dest in
                                Text("\(dest.name) (\(dest.type.rawValue) – \(dest.transactions.count) txs, \(String(format: "$%.2f", dest.balance)))")
                                    .tag(dest.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Options Section
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $deduplicateTransactions) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deduplicate identical transactions")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Skips duplicate transactions with the same date, amount, and payee.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Summary Preview Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(Color.accentColor)
                            Text("Summary of Changes")
                                .font(.system(size: 12, weight: .bold))
                        }

                        if let dest = targetAccount {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Moving **\(totalSourceTransactions)** transactions from **\(sourceAccounts.map { $0.name }.joined(separator: ", "))** into **\(dest.name)**.")
                                    .font(.caption)
                                Text("• Source account(s) will be permanently deleted after the merge.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Destination balance will update automatically based on merged transactions.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 18)
                        }
                    }
                    .padding(10)
                    .background(Color(red: 0.94, green: 0.96, blue: 0.98))
                    .cornerRadius(8)
                }
                .padding()
            }

            Divider()

            // Footer / Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Merge Accounts") {
                    showingConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 520, height: 480)
        .alert(isPresented: $showingConfirmation) {
            Alert(
                title: Text("Confirm Merge"),
                message: Text("Are you sure you want to merge \(sourceAccounts.map { $0.name }.joined(separator: ", ")) into \(targetAccount?.name ?? "the destination")? This action will combine transactions and delete the source account(s)."),
                primaryButton: .destructive(Text("Merge Accounts")) {
                    executeMerge()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func executeMerge() {
        guard isValid, let target = targetAccount else { return }
        let sources = sourceAccounts.map { $0.id }
        store.mergeAccounts(
            sourceAccountIds: sources,
            targetAccountId: target.id,
            deduplicateTransactions: deduplicateTransactions
        )
        isPresented = false
    }
}
