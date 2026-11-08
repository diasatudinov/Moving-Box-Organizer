import SwiftUI

/// Main screen: places, or search results while searching, with the scanner button.
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var search: SearchViewModel

    var body: some View {
        Group {
            if search.isActive {
                SearchResultsView(viewModel: search)
            } else if viewModel.isEmpty {
                ContentUnavailableView {
                    Label("No Places Yet", systemImage: "shippingbox")
                } description: {
                    Text("Create your first place — for example, “Garage” or “Pantry” — then add shelves, boxes and things inside.")
                } actions: {
                    Button("Create Place", action: viewModel.addLocationTapped)
                        .primaryButtonStyle()
                }
            } else {
                List {
                    ForEach(viewModel.rows) { row in
                        NavigationLink(value: Route.location(row.id)) {
                            LocationRow(row: row)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                viewModel.deleteTapped(locationID: row.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Places")
        .searchable(text: $search.query, prompt: Text("Search items and places"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Print Labels", systemImage: "printer", action: viewModel.printLabelsTapped)
                        .disabled(viewModel.isEmpty)
                    Button("Settings", systemImage: "gearshape", action: viewModel.settingsTapped)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Place", systemImage: "plus", action: viewModel.addLocationTapped)
            }
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            if !viewModel.isEmpty && !search.isActive {
                Button("Scan QR Code", systemImage: "qrcode.viewfinder", action: viewModel.scanTapped)
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.onAccent)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor, in: .circle)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
            }
        }
        .alert($viewModel.alert)
    }
}
