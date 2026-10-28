import SwiftUI

public struct RenameAccountSheet: View {
    @ObservedObject var store: DataStore
    @Binding var isPresented: Bool
    let accountId: String

    @State private var newName: String = ""
    @FocusState private var isFieldFocused: Bool

    public init(store: DataStore, isPresented: Binding<Bool>, accountId: String) {
        self.store = store
        self._isPresented = isPresented
        self.accountId = accountId
        let currentName = store.accounts.first(where: { $0.id == accountId })?.name ?? ""
        self._newName = State(initialValue: currentName)
    }

    private var currentAccount: Account? {
        store.accounts.first(where: { $0.id == accountId })
    }

    private var isValid: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != currentAccount?.name
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rename Account")
                        .font(.headline)
                    Text("Enter a new name for \(currentAccount?.name ?? "this account").")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account Name")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    TextField("Account Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFieldFocused)
                        .onSubmit {
                            if isValid {
                                performRename()
                            }
                        }
                }
            }
            .padding(20)

            Divider()

            // Footer / Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Rename") {
                    performRename()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400)
        .onAppear {
            isFieldFocused = true
        }
    }

    private func performRename() {
        store.renameAccount(id: accountId, newName: newName)
        isPresented = false
    }
}
