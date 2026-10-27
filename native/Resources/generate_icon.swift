import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// 1. macOS Squircle on Green Field (824x824 inside 1024x1024)
let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow for the squircle
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 36, color: NSColor.black.withAlphaComponent(0.40).cgColor)
ctx.addPath(squirclePath)
ctx.setFillColor(NSColor(red: 0.05, green: 0.22, blue: 0.13, alpha: 1.0).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Forest Emerald Gradient Fill on Green Field
let colorSpace = CGColorSpaceCreateDeviceRGB()
let greenColors = [
    NSColor(red: 0.08, green: 0.35, blue: 0.20, alpha: 1.0).cgColor,
    NSColor(red: 0.04, green: 0.22, blue: 0.12, alpha: 1.0).cgColor,
    NSColor(red: 0.02, green: 0.13, blue: 0.07, alpha: 1.0).cgColor
] as CFArray
let greenLocations: [CGFloat] = [0.0, 0.55, 1.0]

if let greenGradient = CGGradient(colorsSpace: colorSpace, colors: greenColors, locations: greenLocations) {
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    ctx.drawLinearGradient(greenGradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])

    // Soft ambient highlight over the green field
    let glowColors = [
        NSColor(red: 0.22, green: 0.68, blue: 0.38, alpha: 0.30).cgColor,
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGrad, startCenter: CGPoint(x: 280, y: 760), startRadius: 20, endCenter: CGPoint(x: 280, y: 760), endRadius: 520, options: [])
    }
    ctx.restoreGState()
}

// Subtle Gold Border on Squircle perimeter
ctx.saveGState()
ctx.addPath(squirclePath)
let borderColors = [
    NSColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 0.60).cgColor,
    NSColor(red: 0.70, green: 0.52, blue: 0.20, alpha: 0.35).cgColor,
    NSColor(red: 0.92, green: 0.78, blue: 0.40, alpha: 0.55).cgColor
] as CFArray
if let borderGrad = CGGradient(colorsSpace: colorSpace, colors: borderColors, locations: [0.0, 0.5, 1.0]) {
    ctx.setLineWidth(8)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(borderGrad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
}
ctx.restoreGState()

// 2. The Gold Coin (Centered at 512, 512)
let centerX: CGFloat = 512
let centerY: CGFloat = 512
let coinRadius: CGFloat = 280

let coinCircleRect = CGRect(x: centerX - coinRadius, y: centerY - coinRadius, width: coinRadius * 2, height: coinRadius * 2)
let coinPath = CGPath(ellipseIn: coinCircleRect, transform: nil)

// Coin Cast Shadow onto the Green Field
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 32, color: NSColor.black.withAlphaComponent(0.65).cgColor)
ctx.addPath(coinPath)
ctx.setFillColor(NSColor(red: 0.55, green: 0.38, blue: 0.10, alpha: 1.0).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Coin Outer Bezel / Rim Gradient
let goldRimColors = [
    NSColor(red: 1.00, green: 0.94, blue: 0.72, alpha: 1.0).cgColor,
    NSColor(red: 0.95, green: 0.82, blue: 0.42, alpha: 1.0).cgColor,
    NSColor(red: 0.82, green: 0.62, blue: 0.22, alpha: 1.0).cgColor,
    NSColor(red: 0.60, green: 0.42, blue: 0.12, alpha: 1.0).cgColor
] as CFArray
let goldLocations: [CGFloat] = [0.0, 0.32, 0.70, 1.0]

if let goldGrad = CGGradient(colorsSpace: colorSpace, colors: goldRimColors, locations: goldLocations) {
    ctx.saveGState()
    ctx.addPath(coinPath)
    ctx.clip()
    ctx.drawLinearGradient(goldGrad, start: CGPoint(x: centerX - coinRadius, y: centerY + coinRadius), end: CGPoint(x: centerX + coinRadius, y: centerY - coinRadius), options: [])
    ctx.restoreGState()
}

// Coin Inner Face
let innerRadius: CGFloat = coinRadius - 26
let innerCoinRect = CGRect(x: centerX - innerRadius, y: centerY - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
let innerCoinPath = CGPath(ellipseIn: innerCoinRect, transform: nil)

let innerGoldColors = [
    NSColor(red: 0.98, green: 0.90, blue: 0.58, alpha: 1.0).cgColor,
    NSColor(red: 0.91, green: 0.76, blue: 0.34, alpha: 1.0).cgColor,
    NSColor(red: 0.78, green: 0.58, blue: 0.20, alpha: 1.0).cgColor,
    NSColor(red: 0.65, green: 0.46, blue: 0.14, alpha: 1.0).cgColor
] as CFArray

if let innerGrad = CGGradient(colorsSpace: colorSpace, colors: innerGoldColors, locations: [0.0, 0.35, 0.75, 1.0]) {
    ctx.saveGState()
    ctx.addPath(innerCoinPath)
    ctx.clip()
    ctx.drawLinearGradient(innerGrad, start: CGPoint(x: centerX - innerRadius * 0.7, y: centerY + innerRadius * 0.9), end: CGPoint(x: centerX + innerRadius * 0.8, y: centerY - innerRadius * 0.9), options: [])

    // Specular radial glow on coin face
    let specColors = [
        NSColor(red: 1.00, green: 0.98, blue: 0.88, alpha: 0.45).cgColor,
        NSColor(red: 0.95, green: 0.80, blue: 0.35, alpha: 0.0).cgColor
    ] as CFArray
    if let specGrad = CGGradient(colorsSpace: colorSpace, colors: specColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(specGrad, startCenter: CGPoint(x: centerX - 60, y: centerY + 90), startRadius: 10, endCenter: CGPoint(x: centerX - 60, y: centerY + 90), endRadius: 240, options: [])
    }
    ctx.restoreGState()
}

// Inner Beaded Ring (classic numismatic coin detail)
ctx.saveGState()
let beadCount = 48
let beadRingRadius: CGFloat = innerRadius - 16
for i in 0..<beadCount {
    let angle = CGFloat(i) * (2.0 * .pi / CGFloat(beadCount))
    let bx = centerX + beadRingRadius * cos(angle)
    let by = centerY + beadRingRadius * sin(angle)
    let beadRect = CGRect(x: bx - 3.5, y: by - 3.5, width: 7.0, height: 7.0)
    ctx.addEllipse(in: beadRect)
}
ctx.setFillColor(NSColor(red: 0.98, green: 0.92, blue: 0.65, alpha: 0.75).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Inner coin groove ring
ctx.saveGState()
let grooveRadius: CGFloat = innerRadius - 28
let grooveRect = CGRect(x: centerX - grooveRadius, y: centerY - grooveRadius, width: grooveRadius * 2, height: grooveRadius * 2)
ctx.addEllipse(in: grooveRect)
ctx.setStrokeColor(NSColor(red: 0.58, green: 0.40, blue: 0.12, alpha: 0.65).cgColor)
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

// 3. The Stamped "H" on the Coin
let hPath = CGMutablePath()
let pillarW: CGFloat = 46
let pillarH: CGFloat = 250
let span: CGFloat = 100
let barH: CGFloat = 44

// Left Pillar with serif caps
hPath.addRoundedRect(in: CGRect(x: centerX - span - pillarW / 2, y: centerY - pillarH / 2, width: pillarW, height: pillarH), cornerWidth: 8, cornerHeight: 8)
// Left serifs
hPath.addRoundedRect(in: CGRect(x: centerX - span - pillarW / 2 - 16, y: centerY + pillarH / 2 - 14, width: pillarW + 32, height: 14), cornerWidth: 4, cornerHeight: 4)
hPath.addRoundedRect(in: CGRect(x: centerX - span - pillarW / 2 - 16, y: centerY - pillarH / 2, width: pillarW + 32, height: 14), cornerWidth: 4, cornerHeight: 4)

// Right Pillar with serif caps
hPath.addRoundedRect(in: CGRect(x: centerX + span - pillarW / 2, y: centerY - pillarH / 2, width: pillarW, height: pillarH), cornerWidth: 8, cornerHeight: 8)
// Right serifs
hPath.addRoundedRect(in: CGRect(x: centerX + span - pillarW / 2 - 16, y: centerY + pillarH / 2 - 14, width: pillarW + 32, height: 14), cornerWidth: 4, cornerHeight: 4)
hPath.addRoundedRect(in: CGRect(x: centerX + span - pillarW / 2 - 16, y: centerY - pillarH / 2, width: pillarW + 32, height: 14), cornerWidth: 4, cornerHeight: 4)

// Crossbar
hPath.addRoundedRect(in: CGRect(x: centerX - span, y: centerY - barH / 2, width: span * 2, height: barH), cornerWidth: 6, cornerHeight: 6)

// Stamped Depth: Shadow under the H
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: NSColor.black.withAlphaComponent(0.55).cgColor)
ctx.addPath(hPath)
ctx.setFillColor(NSColor(red: 0.45, green: 0.30, blue: 0.08, alpha: 1.0).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Stamped Relief: Raised Gold Gradient on the H
let hGoldColors = [
    NSColor(red: 1.00, green: 0.97, blue: 0.86, alpha: 1.0).cgColor,
    NSColor(red: 0.98, green: 0.86, blue: 0.46, alpha: 1.0).cgColor,
    NSColor(red: 0.86, green: 0.68, blue: 0.26, alpha: 1.0).cgColor,
    NSColor(red: 0.68, green: 0.48, blue: 0.16, alpha: 1.0).cgColor
] as CFArray

if let hGrad = CGGradient(colorsSpace: colorSpace, colors: hGoldColors, locations: [0.0, 0.30, 0.70, 1.0]) {
    ctx.saveGState()
    ctx.addPath(hPath)
    ctx.clip()
    ctx.drawLinearGradient(hGrad, start: CGPoint(x: centerX - span, y: centerY + pillarH / 2), end: CGPoint(x: centerX + span, y: centerY - pillarH / 2), options: [])
    ctx.restoreGState()
}

// Inner Highlight Stroke for Chiseled / Struck Coin Finish
ctx.saveGState()
ctx.addPath(hPath)
ctx.setLineWidth(3)
ctx.setStrokeColor(NSColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 0.7).cgColor)
ctx.strokePath()
ctx.restoreGState()

// Stamped Star Accents on Coin Face
let starOffsets: [CGFloat] = [-165, 165]
for ox in starOffsets {
    ctx.saveGState()
    let star = CGMutablePath()
    let sx = centerX + ox
    let sy = centerY
    let starRadius: CGFloat = 11
    let innerR: CGFloat = 4.5
    for i in 0..<10 {
        let r = (i % 2 == 0) ? starRadius : innerR
        let a = CGFloat(i) * (.pi / 5.0) - (.pi / 2.0)
        let pt = CGPoint(x: sx + r * cos(a), y: sy + r * sin(a))
        if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
    }
    star.closeSubpath()
    ctx.addPath(star)
    ctx.setFillColor(NSColor(red: 0.98, green: 0.90, blue: 0.60, alpha: 0.85).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
}

image.unlockFocus()

// 4. Export Multi-Resolution .iconset -> .icns
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

let icnsUrl = scriptDir.appendingPathComponent("AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsUrl.path]
try? p.run()
p.waitUntilExit()

try? fm.removeItem(at: iconsetDir)
print("==> Programmatically generated gold coin on green field AppIcon.icns successfully.")
