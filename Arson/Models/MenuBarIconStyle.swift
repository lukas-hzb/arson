import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    static let preferenceKey = "menuBarIconStyle"
    static let defaultStyle: Self = .flame

    case windows
    case flame
    case appWindow

    var id: Self { self }
}
