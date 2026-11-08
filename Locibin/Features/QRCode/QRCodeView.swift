import SwiftUI

struct QRCodeView: View {
    @Bindable var viewModel: QRCodeViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loaded(let title, let pathText, let image):
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text(title)
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            if let pathText {
                                Text(pathText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        VStack(spacing: 12) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .accessibilityLabel(Text("QR code for “\(title)”"))
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.black)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .background(.white, in: .rect(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20).strokeBorder(Color(.separator))
                        }

                        Text("This code won't change if you rename the place or change what's inside.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        Button(action: viewModel.printTapped) {
                            Label("Print", systemImage: "printer").frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        if let sheet = viewModel.labelSheet {
                            ShareLink(item: sheet.fileURL) {
                                Label("Share PDF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                            }
                            .secondaryButtonStyle()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            case .missing:
                ContentUnavailableView("This place no longer exists.", systemImage: "questionmark.folder")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: viewModel.doneTapped)
            }
        }
        .alert($viewModel.alert)
    }
}
