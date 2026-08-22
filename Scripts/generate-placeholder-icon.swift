import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift generate-placeholder-icon.swift <output.png>")
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(srgbRed: 0.949, green: 0.333, blue: 0.098, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to render placeholder icon")
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
