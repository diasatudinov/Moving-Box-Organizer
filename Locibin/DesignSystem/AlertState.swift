import SwiftUI

/// A ViewModel-owned description of an alert. ViewModels set it, views only present it
/// with `.alert($viewModel.alert)` — one pattern for every confirmation and error in the app.
/// ViewModels stay free of SwiftUI types: roles are mapped to `ButtonRole` only when presenting.
struct AlertState: Identifiable {
    enum Role {
        case cancel
        case destructive
    }

    struct Action: Identifiable {
        let id = UUID()
        let title: LocalizedStringResource
        let role: Role?
        let handler: () -> Void

        init(title: LocalizedStringResource, role: Role? = nil, handler: @escaping () -> Void = {}) {
            self.title = title
            self.role = role
            self.handler = handler
        }

        static func cancel() -> Action {
            Action(title: "Cancel", role: .cancel)
        }

        static func ok() -> Action {
            Action(title: "OK", role: .cancel)
        }
    }

    let id = UUID()
    let title: LocalizedStringResource
    let message: LocalizedStringResource?
    let actions: [Action]

    init(title: LocalizedStringResource, message: LocalizedStringResource? = nil, actions: [Action]) {
        self.title = title
        self.message = message
        self.actions = actions
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
        let title = state.wrappedValue.map { Text($0.title) } ?? Text(verbatim: "")
        return alert(title, isPresented: isPresented, presenting: state.wrappedValue) { alert in
            ForEach(alert.actions) { action in
                Button(role: action.role.map(ButtonRole.init), action: action.handler) {
                    Text(action.title)
                }
            }
        } message: { alert in
            if let message = alert.message {
                Text(message)
            }
        }
    }
}
