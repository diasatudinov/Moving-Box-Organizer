import SwiftUI

/// The same screen for every level: a garage, a rack or a box. QR and moving are added in 5.4–5.5.
struct LocationView: View {
    @Bindable var viewModel: LocationViewModel
    @FocusState private var isQuickAddFocused: Bool

    var body: some View {
        Group {
            switch viewModel.state {
            case .loaded(let content):
                list(content)
                    .navigationTitle(content.title)
                    .toolbar { toolbar }
            case .missing:
                ContentUnavailableView("This place no longer exists.", systemImage: "questionmark.folder")
            }
        }
        .alert($viewModel.alert)
    }

    private func list(_ content: LocationViewModel.Content) -> some View {
        List {
            Section {
                Label {
                    Text(content.header)
                } icon: {
                    Image(systemName: content.kind.symbolName)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
            }

            if !content.sublocations.isEmpty {
                Section("Places Inside") {
                    ForEach(content.sublocations) { row in
                        NavigationLink(value: Route.location(row.id)) {
                            LocationRow(row: row)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                viewModel.deleteSublocationTapped(id: row.id)
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(content.items) { row in
                    Button {
                        viewModel.itemTapped(id: row.id)
                    } label: {
                        ItemRow(row: row)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.deleteItem(id: row.id)
                        }
                    }
                }
                quickAddField
            } header: {
                Text("Items")
            } footer: {
                if content.isEmpty {
                    Text("Type things one by one and press Return. You can add places inside too.")
                }
            }
        }
    }

    private var quickAddField: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField("Add item", text: $viewModel.quickAddText)
                .focused($isQuickAddFocused)
                .submitLabel(.next)
                .onSubmit {
                    viewModel.submitQuickAdd()
                    isQuickAddFocused = true
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Add", systemImage: "plus") {
                Button("Add Item", systemImage: "text.badge.plus") { isQuickAddFocused = true }
                Button("Add Place Inside", systemImage: "folder.badge.plus", action: viewModel.addSublocationTapped)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("More", systemImage: "ellipsis") {
                Button("Edit", systemImage: "pencil", action: viewModel.editTapped)
                Button("Delete", systemImage: "trash", role: .destructive, action: viewModel.deleteTapped)
            }
        }
    }
}
