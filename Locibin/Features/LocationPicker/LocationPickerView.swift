import SwiftUI

struct LocationPickerView: View {
    @Bindable var viewModel: LocationPickerViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.rows) { row in
                    PickerRow(row: row, isSelected: viewModel.selection == row.target) {
                        viewModel.select(row)
                    }
                }
            } header: {
                Text(viewModel.prompt)
                    .foregroundStyle(Color.secondaryText)
                    .textCase(nil)
            }
        }
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Find a place"))
        .safeAreaInset(edge: .bottom) {
            Button(action: viewModel.confirm) {
                Text(viewModel.confirmTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .primaryButtonStyle()
            .disabled(!viewModel.canConfirm)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle("Move")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: viewModel.cancel)
                }
            }
        }
        .alert($viewModel.alert)
    }
}

private struct PickerRow: View {
    let row: LocationPickerViewModel.Row
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var indent: CGFloat = 20

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let kind = row.kind {
                    LocationKindIcon(kind: kind)
                } else {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .foregroundStyle(row.isDisabled ? .secondary : .primary)
                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                if row.isCurrent {
                    Text("Current")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, CGFloat(row.depth) * indent)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(row.isDisabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
