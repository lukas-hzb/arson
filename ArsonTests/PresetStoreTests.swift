import Foundation
import Testing
@testable import Arson

@MainActor
struct PresetStoreTests {
    @Test func seedsAStoreThatDoesNotExist() {
        let url = temporaryFileURL()
        let store = PresetStore(fileURL: url)

        #expect(store.presets.count == 4)
        #expect(store.presets.map(\.name) == [
            String(localized: "preset.seed.fixed"),
            String(localized: "preset.seed.leftHalf"),
            String(localized: "preset.seed.rightHalf"),
            String(localized: "preset.seed.offset")
        ])
        #expect(store.presets.map(\.width) == [
            .percent(80), .percent(50), .percent(50), .unchanged
        ])
        #expect(store.presets.map(\.height) == [
            .percent(80), .percent(100), .percent(100), .unchanged
        ])
        #expect(store.presets.map(\.position) == [
            .center, .leftEdge, .rightEdge, .keep
        ])
        #expect(store.presets.map(\.offsetX) == [0, 1, 0, 20])
        #expect(store.presets.map(\.offsetY) == [0, 1, 0, 20])
        #expect(store.presets.compactMap(\.shortcut).map(\.displayValue) == [
            "⌃⌘↩", "⌃⌘←", "⌃⌘→", "⌃⌘⌫"
        ])
        #expect(
            store.presets.compactMap(\.shortcut).allSatisfy {
                GlobalHotKeyManager.validate($0) == nil
            }
        )
        #expect(Set(store.presets.compactMap(\.shortcut)).count == 4)
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

    @Test func savesAndLoadsEdgePositions() throws {
        let originals = [
            Preset(name: "Left", position: .leftEdge),
            Preset(name: "Right", position: .rightEdge)
        ]
        let url = temporaryFileURL()
        let store = PresetStore(fileURL: url, seedPresets: originals)
        store.save()

        let storedPresets = try PresetStore.load(from: url)
        let loaded = try #require(storedPresets)
        #expect(loaded == originals)
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

    @Test func migratesOnlyLegacySeedNames() throws {
        let url = temporaryFileURL()
        let shortcut = HotKeyShortcut(
            keyCode: 19,
            modifiers: [.command, .option],
            keyLabel: "2"
        )
        let fixedID = UUID()
        let legacyPresets = [
            Preset(
                id: fixedID,
                name: "400 × 600 – Centered",
                width: .percent(78),
                height: .percent(77),
                position: .center,
                shortcut: shortcut
            ),
            Preset(
                name: "90 % × 70 % – Zentriert",
                width: .percent(90),
                height: .percent(70),
                position: .center
            ),
            Preset(
                name: "60 right and down",
                offsetX: 60,
                offsetY: 60
            ),
            Preset(
                name: "Reading",
                width: .points(400),
                height: .points(600),
                position: .center
            )
        ]

        let legacyStore = PresetStore(fileURL: url, seedPresets: legacyPresets)
        legacyStore.save()
        let migratedStore = PresetStore(fileURL: url)

        #expect(migratedStore.presets[0].id == fixedID)
        #expect(migratedStore.presets[0].shortcut == shortcut)
        #expect(migratedStore.presets[0].name == String(localized: "preset.seed.fixed"))
        #expect(migratedStore.presets[1].name == String(localized: "preset.seed.percent"))
        #expect(migratedStore.presets[2].name == String(localized: "preset.seed.offset"))
        #expect(migratedStore.presets[3].name == "Reading")

        let loadedPresets = try PresetStore.load(from: url)
        let persistedPresets = try #require(loadedPresets)
        #expect(persistedPresets == migratedStore.presets)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("presets.json")
    }
}
