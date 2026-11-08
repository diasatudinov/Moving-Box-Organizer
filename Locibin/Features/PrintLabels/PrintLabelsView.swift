import PDFKit
import SwiftUI

struct PrintLabelsView: View {
    @Bindable var viewModel: PrintLabelsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Label Size", selection: $viewModel.labelSize) {
                    Text("Large").tag(LabelSize.large)
                    Text("Small").tag(LabelSize.small)
                }
                .pickerStyle(.segmented)
            } header: {
                SectionHeader("Label Size")
            } footer: {
                Text("Large: 90 × 60 mm, 8 per sheet. Small: 50 × 50 mm, 15 per sheet.")
            }

            Section {
                Picker("Paper", selection: $viewModel.paper) {
                    Text(verbatim: "A4").tag(PaperSize.a4)
                    Text(verbatim: "Letter").tag(PaperSize.letter)
                }
                .pickerStyle(.segmented)
            } header: {
                SectionHeader("Paper")
            }

            Section {
                ForEach(viewModel.rows) { row in
                    Button {
                        viewModel.toggle(row)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.isSelected(row) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(viewModel.isSelected(row) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                .accessibilityHidden(true)
                            LocationKindIcon(kind: row.kind)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).foregroundStyle(.primary)
                                if let subtitle = row.subtitle {
                                    Text(subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.isSelected(row) ? .isSelected : [])
                }
            } header: {
                HStack {
                    SectionHeader("Places")
                    Spacer()
                    Button(viewModel.allSelected ? "Deselect All" : "Select All", action: viewModel.toggleAll)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Text(viewModel.summary)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                Button(action: viewModel.previewTapped) {
                    Text("Preview").frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .disabled(!viewModel.canPreview)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle("Print Labels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: viewModel.cancel)
            }
        }
        .navigationDestination(item: $viewModel.sheet) { sheet in
            LabelPreviewView(sheet: sheet, onPrint: viewModel.printTapped)
        }
        .alert($viewModel.alert)
    }
}

/// PDF preview with Print and Share. Shared with the single-location QR screen.
struct LabelPreviewView: View {
    let sheet: LabelSheet
    let onPrint: () -> Void

    var body: some View {
        PDFKitView(data: sheet.data)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: sheet.fileURL) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Print", systemImage: "printer", action: onPrint)
                }
            }
    }
}

/// PDFKit's viewer. Display only.
struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
