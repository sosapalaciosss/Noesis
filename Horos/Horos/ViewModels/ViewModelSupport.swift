import Foundation

/// Lightweight alert payload shared by the view models.
struct AlertState: Equatable {
    var title: String
    var message: String

    init(title: String = "HOROS", message: String) {
        self.title = title
        self.message = message
    }

    init(error: Error) {
        self.init(message: error.localizedDescription)
    }
}
