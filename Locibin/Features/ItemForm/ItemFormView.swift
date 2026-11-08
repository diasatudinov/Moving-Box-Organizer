import SwiftUI

struct ItemFormView: View {
    @Bindable var viewModel: ItemFormViewModel

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $viewModel.draft.name)
            }

            Section("Quantity") {
                HStack {
                    Text(viewModel.quantityText)
                        .foregroundStyle(viewModel.draft.quantity == nil ? .secondary : .primary)
                    Spacer()
                    Button("Decrease", systemImage: "minus", action: viewModel.decreaseQuantity)
                        .disabled(!viewModel.canDecreaseQuantity)
                    Button("Increase", systemImage: "plus", action: viewModel.increaseQuantity)
                        .disabled(!viewModel.canIncreaseQuantity)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            }

            Section("Note") {
                TextField("Note", text: $viewModel.draft.note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Stored In") {
                Button(action: viewModel.chooseLocationTapped) {
                    HStack {
                        Text(viewModel.locationPathText)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text("Move")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }

            Section {
                Button("Delete Item", role: .destructive, action: viewModel.deleteTapped)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: viewModel.cancelTapped)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: viewModel.save)
                    .disabled(!viewModel.canSave)
            }
        }
        .navigationDestination(isPresented: $viewModel.isPickingLocation) {
            ScreenHost(makeViewModel: viewModel.makeLocationPicker) { picker in
                LocationPickerView(viewModel: picker)
            }
        }
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .alert($viewModel.alert)
    }
}
