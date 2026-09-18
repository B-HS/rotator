import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("사용법: swift generate-icon.swift <AppIcon.iconset>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

func renderIcon(points: Int, scale: Int, to url: URL) throws {
    let pixels = points * scale
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "RotatorIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let size = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let backgroundRect = canvas.insetBy(dx: size * 0.055, dy: size * 0.055)
    let background = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: size * 0.215,
        yRadius: size * 0.215
    )
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.08, green: 0.18, blue: 0.25, alpha: 1),
        ending: NSColor(srgbRed: 0.13, green: 0.52, blue: 0.55, alpha: 1)
    )!
    gradient.draw(in: background, angle: -55)

    let pointConfiguration = NSImage.SymbolConfiguration(
        pointSize: size * 0.47,
        weight: .medium
    )
    let colorConfiguration = NSImage.SymbolConfiguration(hierarchicalColor: .white)
    guard let symbol = NSImage(
        systemSymbolName: "rectangle.landscape.rotate",
        accessibilityDescription: "화면 회전"
    )?.withSymbolConfiguration(pointConfiguration.applying(colorConfiguration)) else {
        throw NSError(domain: "RotatorIcon", code: 2)
    }

    let symbolSize = symbol.size
    let symbolRect = NSRect(
        x: (size - symbolSize.width) / 2,
        y: (size - symbolSize.height) / 2,
        width: symbolSize.width,
        height: symbolSize.height
    )
    symbol.draw(in: symbolRect)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RotatorIcon", code: 3)
    }
    try png.write(to: url)
}

for variant in variants {
    let suffix = variant.scale == 2 ? "@2x" : ""
    let filename = "icon_\(variant.points)x\(variant.points)\(suffix).png"
    try renderIcon(
        points: variant.points,
        scale: variant.scale,
        to: outputDirectory.appendingPathComponent(filename)
    )
}
