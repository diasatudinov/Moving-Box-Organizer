import SwiftUI

/// Main screen: places, or search results while searching. The scanner button is added in step 5.6.
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
            ToolbarItem(placement: .primaryAction) {
                Button("New Place", systemImage: "plus", action: viewModel.addLocationTapped)
            }
        }
        .alert($viewModel.alert)
    }
}
