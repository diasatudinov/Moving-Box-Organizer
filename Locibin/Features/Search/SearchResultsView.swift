import SwiftUI

/// Results shown in place of the places list while the search field has text.
struct SearchResultsView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        Group {
            if viewModel.hasNoResults {
                ContentUnavailableView.search(text: viewModel.query)
            } else {
                List {
                    if !viewModel.items.isEmpty {
                        Section("Items") {
                            ForEach(viewModel.items) { item in
                                Button {
                                    viewModel.select(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .foregroundStyle(.primary)
                                        Text(item.pathText)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    if !viewModel.locations.isEmpty {
                        Section("Places") {
                            ForEach(viewModel.locations) { location in
                                Button {
                                    viewModel.select(location)
                                } label: {
                                    LocationRow(row: LocationRowData(id: location.id, title: location.title, subtitle: location.subtitle, kind: location.kind))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .alert($viewModel.alert)
    }
}
