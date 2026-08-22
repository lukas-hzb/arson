import Combine
import Foundation
import OSLog

private struct PresetEnvelope: Codable {
    let schemaVersion: Int
    let presets: [Preset]
}

enum PresetStoreError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            return String.localizedStringWithFormat(
                String(localized: "error.store.schema"),
                Int64(version)
            )
        }
    }
}

@MainActor
final class PresetStore: ObservableObject {
    @Published var presets: [Preset] {
        didSet {
            save()
            onChange?(presets)
        }
    }
    @Published private(set) var lastError: String?

    private let fileURL: URL
    private let logger = Logger(subsystem: "de.lukasharzbecker.arson", category: "PresetStore")
    private var isLoading = false
    var onChange: (([Preset]) -> Void)?

    init(fileURL: URL? = nil, seedPresets: @autoclosure () -> [Preset] = Preset.seedPresets()) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.presets = []
        isLoading = true
        do {
            presets = try Self.load(from: self.fileURL) ?? seedPresets()
        } catch {
            presets = seedPresets()
            lastError = error.localizedDescription
            logger.error("Unable to load preset data: \(error.localizedDescription, privacy: .private)")
        }
        isLoading = false
    }

    func addPreset() -> UUID {
        let preset = Preset(
            name: uniqueName(base: String(localized: "preset.new")),
            width: .percent(80),
            height: .percent(80),
            position: .center
        )
        presets.append(preset)
        return preset.id
    }

    func duplicate(_ id: UUID) -> UUID? {
        guard let source = presets.first(where: { $0.id == id }) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.name = uniqueName(
            base: String.localizedStringWithFormat(String(localized: "preset.copy"), source.name)
        )
        copy.shortcut = nil
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return nil }
        presets.insert(copy, at: presets.index(after: index))
        return copy.id
    }

    func delete(_ id: UUID, undoManager: UndoManager? = nil) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let removed = presets.remove(at: index)
        undoManager?.registerUndo(withTarget: self) { store in
            store.restore(removed, at: index, undoManager: undoManager)
        }
        undoManager?.setActionName(String(localized: "action.deletePreset"))
    }

    func move(from offsets: IndexSet, to destination: Int) {
        presets.move(fromOffsets: offsets, toOffset: destination)
    }

    func bindingIndex(for id: UUID) -> Int? {
        presets.firstIndex(where: { $0.id == id })
    }

    func save() {
        guard !isLoading else { return }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let envelope = PresetEnvelope(schemaVersion: 1, presets: presets)
            let data = try JSONEncoder.pretty.encode(envelope)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            logger.error("Unable to save preset data: \(error.localizedDescription, privacy: .private)")
        }
    }

    static func load(from url: URL) throws -> [Preset]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(PresetEnvelope.self, from: data)
        guard envelope.schemaVersion == 1 else {
            throw PresetStoreError.unsupportedSchema(envelope.schemaVersion)
        }
        return envelope.presets
    }

    private func restore(_ preset: Preset, at index: Int, undoManager: UndoManager?) {
        presets.insert(preset, at: min(index, presets.count))
        undoManager?.registerUndo(withTarget: self) { store in
            store.delete(preset.id, undoManager: undoManager)
        }
    }

    private func uniqueName(base: String) -> String {
        let existing = Set(presets.map { $0.name.localizedLowercase })
        guard existing.contains(base.localizedLowercase) else { return base }
        var index = 2
        while existing.contains("\(base) \(index)".localizedLowercase) { index += 1 }
        return "\(base) \(index)"
    }

    private static func defaultFileURL() -> URL {
        if let testDirectory = ProcessInfo.processInfo.environment["ARSON_TEST_STORAGE_DIRECTORY"] {
            return URL(fileURLWithPath: testDirectory, isDirectory: true)
                .appendingPathComponent("presets.json", isDirectory: false)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Arson", isDirectory: true)
            .appendingPathComponent("presets.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
