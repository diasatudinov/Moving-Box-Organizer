import SwiftUI

/// Main screen. Search and the scanner button are added in steps 5.4 and 5.6.
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        Group {
            if viewModel.isEmpty {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Place", systemImage: "plus", action: viewModel.addLocationTapped)
            }
        }
        .alert($viewModel.alert)
    }
}
