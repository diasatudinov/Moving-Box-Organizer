import SwiftUI

struct LocationFormView: View {
    @Bindable var viewModel: LocationFormViewModel
    @FocusState private var isNameFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $viewModel.name)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { if viewModel.canSave { viewModel.save() } }
            } header: {
                SectionHeader("Name")
            } footer: {
                if let parentPath = viewModel.parentPathText {
                    Text(parentPath)
                }
            }

            Section {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(LocationKind.allCases, id: \.self) { kind in
                        KindButton(kind: kind, isSelected: kind == viewModel.kind) {
                            viewModel.kind = kind
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                SectionHeader("Type")
            }
        }
        .navigationTitle(viewModel.title)
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
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .onAppear { isNameFocused = viewModel.name.isEmpty }
        .alert($viewModel.alert)
    }
}

private struct KindButton: View {
    let kind: LocationKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                LocationKindIcon(kind: kind)
                Text(kind.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color(.separator), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
