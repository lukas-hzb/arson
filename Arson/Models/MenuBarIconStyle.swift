import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    static let preferenceKey = "menuBarIconStyle"

    case windows
    case flame

    var id: Self { self }
}
