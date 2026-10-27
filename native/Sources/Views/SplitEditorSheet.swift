import SwiftUI

public struct SplitEditorSheet: View {
    @Binding var splits: [SplitItem]
    let totalTargetAmount: Double
    let onSave: ([SplitItem]) -> Void
    let onCancel: () -> Void

    @State private var workingSplits: [SplitItem] = []

    public init(splits: Binding<[SplitItem]>, totalTargetAmount: Double, onSave: @escaping ([SplitItem]) -> Void, onCancel: @escaping () -> Void) {
        self._splits = splits
        self.totalTargetAmount = totalTargetAmount
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Split Transaction")
                    .font(.headline)
                Spacer()
                Text(String(format: "Target Total: $%.2f", abs(totalTargetAmount)))
                    .font(.caption.monospaced().bold())
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()

            // Splits List
            List {
                ForEach(workingSplits.indices, id: \.self) { idx in
                    HStack(spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.caption.bold())
                            .frame(width: 24)

                        TextField("Category", text: $workingSplits[idx].category)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)

                        TextField("Memo", text: $workingSplits[idx].memo)
                            .textFieldStyle(.roundedBorder)

                        TextField("Amount", value: $workingSplits[idx].amount, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)

                        Button(action: { workingSplits.remove(at: idx) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 180)

            Divider()

            // Footer with Summary and Buttons
            let allocated = workingSplits.reduce(0.0) { $0 + $1.amount }
            let remainder = abs(totalTargetAmount) - allocated

            HStack {
                Button(action: {
                    workingSplits.append(SplitItem(category: "", memo: "", amount: max(0, remainder)))
                }) {
                    Label("Add Split Line", systemImage: "plus")
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "Allocated: $%.2f", allocated))
                        .font(.caption.monospaced())
                    Text(String(format: "Remainder: $%.2f", remainder))
                        .font(.caption.monospaced().bold())
                        .foregroundColor(abs(remainder) < 0.01 ? .green : .orange)
                }

                Button("Cancel", action: onCancel)
                Button("Done") {
                    onSave(workingSplits)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 520, height: 340)
        .onAppear {
            if splits.isEmpty {
                workingSplits = [
                    SplitItem(category: "", memo: "", amount: abs(totalTargetAmount))
                ]
            } else {
                workingSplits = splits
            }
        }
    }
}
