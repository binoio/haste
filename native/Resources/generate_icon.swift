import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// 1. Background squircle filling the standard macOS squircle area (824x824 inside 1024x1024)
let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow for the entire squircle
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 35, color: NSColor.black.withAlphaComponent(0.45).cgColor)
ctx.addPath(squirclePath)
ctx.setFillColor(NSColor(red: 0.04, green: 0.20, blue: 0.12, alpha: 1.0).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Forest Emerald Gradient Fill
let colorSpace = CGColorSpaceCreateDeviceRGB()
let greenColors = [
    NSColor(red: 0.08, green: 0.32, blue: 0.18, alpha: 1.0).cgColor,
    NSColor(red: 0.04, green: 0.18, blue: 0.10, alpha: 1.0).cgColor,
    NSColor(red: 0.02, green: 0.11, blue: 0.06, alpha: 1.0).cgColor
] as CFArray
let greenLocations: [CGFloat] = [0.0, 0.65, 1.0]

if let greenGradient = CGGradient(colorsSpace: colorSpace, colors: greenColors, locations: greenLocations) {
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    ctx.drawLinearGradient(greenGradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])

    // Subtle radial highlight at top-left
    let radialColors = [
        NSColor(red: 0.20, green: 0.65, blue: 0.35, alpha: 0.35).cgColor,
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor
    ] as CFArray
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: radialColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(radialGrad, startCenter: CGPoint(x: 300, y: 750), startRadius: 10, endCenter: CGPoint(x: 300, y: 750), endRadius: 450, options: [])
    }

    ctx.restoreGState()
}

// Gold Border on Squircle
ctx.saveGState()
ctx.addPath(squirclePath)
let goldBorderColors = [
    NSColor(red: 0.98, green: 0.88, blue: 0.52, alpha: 0.75).cgColor,
    NSColor(red: 0.75, green: 0.58, blue: 0.22, alpha: 0.50).cgColor,
    NSColor(red: 0.95, green: 0.82, blue: 0.45, alpha: 0.70).cgColor
] as CFArray
if let goldBorderGrad = CGGradient(colorsSpace: colorSpace, colors: goldBorderColors, locations: [0.0, 0.5, 1.0]) {
    ctx.setLineWidth(10)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(goldBorderGrad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
}
ctx.restoreGState()

// 2. Decorative Golden Sunburst / Compass Geometry
ctx.saveGState()
let centerX: CGFloat = 512
let centerY: CGFloat = 540

// Concentric gold rings
let ringPath = CGMutablePath()
ringPath.addEllipse(in: CGRect(x: centerX - 260, y: centerY - 260, width: 520, height: 520))
ringPath.addEllipse(in: CGRect(x: centerX - 248, y: centerY - 248, width: 496, height: 496))

ctx.addPath(ringPath)
ctx.setFillColor(NSColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 0.35).cgColor)
ctx.fillPath()

// Radiating gold diamond nodes
for i in 0..<8 {
    let angle = CGFloat(i) * (.pi / 4.0)
    let radius: CGFloat = 254
    let nx = centerX + radius * cos(angle)
    let ny = centerY + radius * sin(angle)

    let diamond = CGMutablePath()
    let dSize: CGFloat = (i % 2 == 0) ? 14 : 9
    diamond.move(to: CGPoint(x: nx, y: ny + dSize))
    diamond.addLine(to: CGPoint(x: nx + dSize, y: ny))
    diamond.addLine(to: CGPoint(x: nx, y: ny - dSize))
    diamond.addLine(to: CGPoint(x: nx - dSize, y: ny))
    diamond.closeSubpath()

    ctx.addPath(diamond)
    ctx.setFillColor(NSColor(red: 0.98, green: 0.88, blue: 0.55, alpha: 0.85).cgColor)
    ctx.fillPath()
}
ctx.restoreGState()

// 3. Central Gold Emblem: Sculpted Architectural "H" Monogram with Ingot Depth
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: NSColor.black.withAlphaComponent(0.6).cgColor)

let hEmblemPath = CGMutablePath()

// Left Pillar
hEmblemPath.addRoundedRect(in: CGRect(x: centerX - 180, y: centerY - 170, width: 75, height: 340), cornerWidth: 14, cornerHeight: 14)
// Right Pillar
hEmblemPath.addRoundedRect(in: CGRect(x: centerX + 105, y: centerY - 170, width: 75, height: 340), cornerWidth: 14, cornerHeight: 14)
// Crossbar
hEmblemPath.addRoundedRect(in: CGRect(x: centerX - 180, y: centerY - 38, width: 360, height: 76), cornerWidth: 14, cornerHeight: 14)

// Center Facet Diamond in crossbar
let centerDiamond = CGMutablePath()
centerDiamond.move(to: CGPoint(x: centerX, y: centerY + 65))
centerDiamond.addLine(to: CGPoint(x: centerX + 45, y: centerY))
centerDiamond.addLine(to: CGPoint(x: centerX, y: centerY - 65))
centerDiamond.addLine(to: CGPoint(x: centerX - 45, y: centerY))
centerDiamond.closeSubpath()

// Gold Gradient for Emblem
let goldIngotColors = [
    NSColor(red: 1.00, green: 0.96, blue: 0.82, alpha: 1.0).cgColor,
    NSColor(red: 0.96, green: 0.82, blue: 0.42, alpha: 1.0).cgColor,
    NSColor(red: 0.84, green: 0.65, blue: 0.24, alpha: 1.0).cgColor,
    NSColor(red: 0.62, green: 0.44, blue: 0.12, alpha: 1.0).cgColor
] as CFArray
let goldIngotLocations: [CGFloat] = [0.0, 0.35, 0.70, 1.0]

if let goldGrad = CGGradient(colorsSpace: colorSpace, colors: goldIngotColors, locations: goldIngotLocations) {
    ctx.saveGState()
    ctx.addPath(hEmblemPath)
    ctx.clip()
    ctx.drawLinearGradient(goldGrad, start: CGPoint(x: centerX - 180, y: centerY + 180), end: CGPoint(x: centerX + 180, y: centerY - 180), options: [])
    ctx.restoreGState()

    // Draw center diamond accent
    ctx.saveGState()
    ctx.addPath(centerDiamond)
    ctx.clip()
    ctx.drawLinearGradient(goldGrad, start: CGPoint(x: centerX, y: centerY + 65), end: CGPoint(x: centerX, y: centerY - 65), options: [])
    ctx.restoreGState()
}

// Emblem Inner Bevel / Highlight Stroke
ctx.saveGState()
ctx.addPath(hEmblemPath)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
ctx.setLineWidth(4)
ctx.strokePath()
ctx.restoreGState()

// 4. Typography: "H A S T E" in Gold
let title = "H A S T E"
let titleFont = NSFont.systemFont(ofSize: 56, weight: .heavy)
let titleShadow = NSShadow()
titleShadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
titleShadow.shadowOffset = NSSize(width: 0, height: -4)
titleShadow.shadowBlurRadius = 8

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(red: 0.96, green: 0.86, blue: 0.54, alpha: 1.0),
    .shadow: titleShadow,
    .kern: 10.0
]
let titleSize = title.size(withAttributes: titleAttrs)
let titlePoint = CGPoint(x: (size - titleSize.width) / 2, y: 220)
title.draw(at: titlePoint, withAttributes: titleAttrs)

// Subtitle: "FINANCIAL SUITE"
let sub = "FINANCIAL SUITE"
let subFont = NSFont.monospacedSystemFont(ofSize: 22, weight: .bold)
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: NSColor(red: 0.75, green: 0.90, blue: 0.80, alpha: 0.85),
    .kern: 4.0
]
let subSize = sub.size(withAttributes: subAttrs)
let subPoint = CGPoint(x: (size - subSize.width) / 2, y: 175)
sub.draw(at: subPoint, withAttributes: subAttrs)

image.unlockFocus()

// 5. Export PNG and Multi-Resolution .iconset -> .icns
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}

let fm = FileManager.default
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconsetDir = scriptDir.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconsetDir)
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let basePngPath = scriptDir.appendingPathComponent("icon_1024.png")
try? pngData.write(to: basePngPath)

let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in iconSizes {
    let destUrl = iconsetDir.appendingPathComponent(name)
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()

    if let rTiff = resized.tiffRepresentation,
       let rBmp = NSBitmapImageRep(data: rTiff),
       let rPng = rBmp.representation(using: .png, properties: [:]) {
        try? rPng.write(to: destUrl)
    }
}

// Convert iconset to icns
let icnsUrl = scriptDir.appendingPathComponent("AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsUrl.path]
try? p.run()
p.waitUntilExit()

try? fm.removeItem(at: iconsetDir)
print("==> Programmatically generated green & gold AppIcon.icns successfully.")
