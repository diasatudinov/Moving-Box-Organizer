import SwiftUI

/// The same screen for every level: a garage, a rack or a box.
struct LocationView: View {
    @Bindable var viewModel: LocationViewModel
    @FocusState private var isQuickAddFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        ScrollViewReader { proxy in
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
                                Button("Move", systemImage: "folder") {
                                    viewModel.moveSublocationTapped(id: row.id)
                                }
                                .tint(.accentColor)
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
                        .listRowBackground(row.id == viewModel.highlightedItemID ? Color.accentTile : nil)
                        .id(row.id)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                viewModel.deleteItem(id: row.id)
                            }
                            Button("Move", systemImage: "folder") {
                                viewModel.moveItemTapped(id: row.id)
                            }
                            .tint(.accentColor)
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
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: viewModel.highlightedItemID)
            .task {
                guard let itemID = viewModel.highlightedItemID else { return }
                proxy.scrollTo(itemID, anchor: .center)
                await viewModel.highlightShown()
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
            Button("QR Code", systemImage: "qrcode", action: viewModel.qrCodeTapped)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Add", systemImage: "plus") {
                Button("Add Item", systemImage: "text.badge.plus") { isQuickAddFocused = true }
                Button("Add Place Inside", systemImage: "folder.badge.plus", action: viewModel.addSublocationTapped)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("More", systemImage: "ellipsis") {
                Button("Edit", systemImage: "pencil", action: viewModel.editTapped)
                Button("Move", systemImage: "folder", action: viewModel.moveTapped)
                Button("Delete", systemImage: "trash", role: .destructive, action: viewModel.deleteTapped)
            }
        }
    }
}
