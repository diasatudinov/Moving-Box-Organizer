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
                        Section {
                            ForEach(viewModel.items) { item in
                                Button {
                                    viewModel.select(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .foregroundStyle(.primary)
                                        Text(item.pathText)
                                            .font(.footnote)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                            }
                        } header: {
                            SectionHeader("Items")
                        }
                    }
                    if !viewModel.locations.isEmpty {
                        Section {
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
                        } header: {
                            SectionHeader("Places")
                        }
                    }
                }
            }
        }
        .alert($viewModel.alert)
    }
}
