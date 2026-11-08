import SwiftUI

/// A ViewModel-owned description of an alert. ViewModels set it, views only present it
/// with `.alert($viewModel.alert)` — one pattern for every confirmation and error in the app.
/// Texts are already localized by the ViewModel (they often contain names and counts).
/// ViewModels stay free of SwiftUI types: roles are mapped to `ButtonRole` only when presenting.
struct AlertState: Identifiable {
    enum Role {
        case cancel
        case destructive
    }

    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let role: Role?
        let handler: () -> Void

        init(title: String, role: Role? = nil, handler: @escaping () -> Void = {}) {
            self.title = title
            self.role = role
            self.handler = handler
        }

        static func cancel() -> Action {
            Action(title: String(localized: "Cancel", comment: "Alert button"), role: .cancel)
        }

        static func ok() -> Action {
            Action(title: String(localized: "OK", comment: "Alert button"), role: .cancel)
        }
    }

    let id = UUID()
    let title: String
    let message: String?
    let actions: [Action]

    init(title: String, message: String? = nil, actions: [Action]) {
        self.title = title
        self.message = message
        self.actions = actions
    }

    /// Alert for an error thrown by a service; the error's own message is shown.
    static func error(_ error: Error) -> AlertState {
        AlertState(
            title: String(localized: "Something Went Wrong", comment: "Generic error alert title"),
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
            actions: [.ok()]
        )
    }
}

private extension ButtonRole {
    init(_ role: AlertState.Role) {
        switch role {
        case .cancel: self = .cancel
        case .destructive: self = .destructive
        }
    }
}

extension View {
    /// Presents the alert described by `state` and clears it when dismissed.
    func alert(_ state: Binding<AlertState?>) -> some View {
        let isPresented = Binding(
            get: { state.wrappedValue != nil },
            set: { if !$0 { state.wrappedValue = nil } }
        )
        return alert(state.wrappedValue?.title ?? "", isPresented: isPresented, presenting: state.wrappedValue) { alert in
            ForEach(alert.actions) { action in
                Button(action.title, role: action.role.map(ButtonRole.init), action: action.handler)
            }
        } message: { alert in
            if let message = alert.message {
                Text(message)
            }
        }
    }
}
