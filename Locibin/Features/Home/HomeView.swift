import SwiftUI

/// Main screen: places, or search results while searching, with the scanner button.
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var search: SearchViewModel
    @ScaledMetric(relativeTo: .title2) private var scaledScanButtonSize: CGFloat = 60

    /// 60 pt at the default size, growing with Dynamic Type but capped so it doesn't cover the list.
    private var scanButtonSize: CGFloat { min(scaledScanButtonSize, 96) }

    var body: some View {
        Group {
            if search.isActive {
                SearchResultsView(viewModel: search)
            } else if viewModel.isEmpty {
                ScrollableFullScreen {
                    ContentUnavailableView {
                        Label("No Places Yet", systemImage: "shippingbox")
                    } description: {
                        Text("Create your first place — for example, “Garage” or “Pantry” — then add shelves, boxes and things inside.")
                            .emptyStateDescriptionStyle()
                    } actions: {
                        Button("Create Place", action: viewModel.addLocationTapped)
                            .primaryButtonStyle()
                    }
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
                    // The icon grows with Dynamic Type only up to a size that still fits the circle.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundStyle(Color.onAccent)
                    .frame(width: scanButtonSize, height: scanButtonSize)
                    .background(Color.accentColor, in: .circle)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
            }
        }
        .alert($viewModel.alert)
    }
}
