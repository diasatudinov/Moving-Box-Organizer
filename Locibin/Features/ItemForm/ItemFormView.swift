import SwiftUI

struct ItemFormView: View {
    @Bindable var viewModel: ItemFormViewModel

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $viewModel.draft.name)
            } header: {
                SectionHeader("Name")
            }

            Section {
                HStack {
                    Text(viewModel.quantityText)
                        .foregroundStyle(viewModel.draft.quantity == nil ? Color.secondaryText : Color.primary)
                    Spacer()
                    Button("Decrease", systemImage: "minus", action: viewModel.decreaseQuantity)
                        .disabled(!viewModel.canDecreaseQuantity)
                    Button("Increase", systemImage: "plus", action: viewModel.increaseQuantity)
                        .disabled(!viewModel.canIncreaseQuantity)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            } header: {
                SectionHeader("Quantity")
            }

            Section {
                TextField("Note", text: $viewModel.draft.note, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                SectionHeader("Note")
            }

            Section {
                Button(action: viewModel.chooseLocationTapped) {
                    HStack {
                        Text(viewModel.locationPathText)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text("Move")
                            .foregroundStyle(Color.secondaryText)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            } header: {
                SectionHeader("Stored In")
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
