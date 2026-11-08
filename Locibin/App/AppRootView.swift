import SwiftUI

/// Switches between the main navigation and the store error screen.
struct AppRootView: View {
    @Bindable var viewModel: LaunchViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .ready(let dependencies):
                MainNavigationView(dependencies: dependencies, router: dependencies.router)
            case .storeUnavailable:
                StoreErrorView(onRetry: viewModel.retry, onStartOver: viewModel.startOverTapped)
            }
        }
        .alert($viewModel.alert)
        .onOpenURL(perform: viewModel.handle(url:))
    }
}

/// The app's single navigation stack: routes and sheets come from `AppRouter`.
private struct MainNavigationView: View {
    let dependencies: AppDependencies
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ScreenHost(makeViewModel: dependencies.makeHomeViewModel) { home in
                ScreenHost(makeViewModel: dependencies.makeSearchViewModel) { search in
                    HomeView(viewModel: home, search: search)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .location(let id, let highlightedItemID):
                    ScreenHost(makeViewModel: { dependencies.makeLocationViewModel(id: id, highlightedItemID: highlightedItemID) }) { viewModel in
                        LocationView(viewModel: viewModel)
                    }
                }
            }
        }
        .alert($router.alertOverRoot)
        .fullScreenCover(isPresented: $router.isScannerPresented) {
            ScreenHost(makeViewModel: dependencies.makeScannerViewModel) { viewModel in
                ScannerView(viewModel: viewModel)
            }
        }
        .sheet(item: $router.sheet) { sheet in
            NavigationStack {
                sheetContent(sheet)
            }
            .alert($router.alertOverSheet)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .newLocation(let parentID):
            ScreenHost(makeViewModel: { dependencies.makeLocationFormViewModel(mode: .create(parentID: parentID)) }) { viewModel in
                LocationFormView(viewModel: viewModel)
            }
        case .editLocation(let id):
            ScreenHost(makeViewModel: { dependencies.makeLocationFormViewModel(mode: .edit(id)) }) { viewModel in
                LocationFormView(viewModel: viewModel)
            }
        case .editItem(let id):
            ScreenHost(makeViewModel: { dependencies.makeItemFormViewModel(id: id) }) { viewModel in
                ItemFormView(viewModel: viewModel)
            }
        case .moveItem(let id):
            ScreenHost(makeViewModel: { dependencies.makeMoveItemPicker(itemID: id) }) { viewModel in
                LocationPickerView(viewModel: viewModel)
            }
        case .moveLocation(let id):
            ScreenHost(makeViewModel: { dependencies.makeMoveLocationPicker(locationID: id) }) { viewModel in
                LocationPickerView(viewModel: viewModel)
            }
        case .qrCode(let id):
            ScreenHost(makeViewModel: { dependencies.makeQRCodeViewModel(locationID: id) }) { viewModel in
                QRCodeView(viewModel: viewModel)
            }
        case .codeProblem(let problem):
            CodeProblemView(problem: problem, onClose: router.dismissSheet)
        case .printLabels:
            ScreenHost(makeViewModel: dependencies.makePrintLabelsViewModel) { viewModel in
                PrintLabelsView(viewModel: viewModel)
            }
        }
    }
}
