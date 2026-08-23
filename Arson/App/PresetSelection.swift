import Combine
import Foundation

@MainActor
final class PresetSelection: ObservableObject {
    @Published var selectedID: UUID?

    init(selectedID: UUID? = nil) {
        self.selectedID = selectedID
    }
}
