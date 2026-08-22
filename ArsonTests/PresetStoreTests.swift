import Foundation
import Testing
@testable import Arson

@MainActor
struct PresetStoreTests {
    @Test func seedsAStoreThatDoesNotExist() {
        let url = temporaryFileURL()
        let store = PresetStore(fileURL: url)

        #expect(store.presets.count == 3)
        #expect(store.presets.allSatisfy { $0.shortcut == nil })
    }

    @Test func savesAndLoadsRoundTrip() throws {
        let url = temporaryFileURL()
        let original = Preset(
            name: "Mixed",
            width: .points(820),
            height: .percent(72.5),
            position: .center,
            offsetX: -30,
            offsetY: 45
        )
        let store = PresetStore(fileURL: url, seedPresets: [original])
        store.save()

        let storedPresets = try PresetStore.load(from: url)
        let loaded = try #require(storedPresets)
        #expect(loaded == [original])
    }

    @Test func duplicateGetsNewIdentityAndNoShortcut() throws {
        let shortcut = HotKeyShortcut(keyCode: 2, modifiers: [.command, .option], keyLabel: "D")
        let source = Preset(name: "Source", width: .percent(50), shortcut: shortcut)
        let store = PresetStore(fileURL: temporaryFileURL(), seedPresets: [source])

        let copyID = try #require(store.duplicate(source.id))
        let copy = try #require(store.presets.first(where: { $0.id == copyID }))

        #expect(copy.id != source.id)
        #expect(copy.shortcut == nil)
        #expect(copy.name != source.name)
    }

    @Test func rejectsUnsupportedSchema() throws {
        let url = temporaryFileURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{\"schemaVersion\":99,\"presets\":[]}".utf8).write(to: url)

        #expect(throws: PresetStoreError.self) {
            try PresetStore.load(from: url)
        }
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("presets.json")
    }
}
