import Foundation
import AppKit
import CoreGraphics

func colorFromHex(_ hex: String) -> NSColor {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var rgb: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&rgb)
    let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
    let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
    let b = CGFloat(rgb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
}

func makeSquirclePath(rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let x = rect.origin.x
    let y = rect.origin.y
    let w = rect.size.width
    let h = rect.size.height
    let r = min(radius, min(w, h) / 2)
    let k: CGFloat = 0.62
    let c = r * (1.0 - k)

    path.move(to: CGPoint(x: x + r, y: y))
    path.addLine(to: CGPoint(x: x + w - r, y: y))
    path.addCurve(to: CGPoint(x: x + w, y: y + r),
                  control1: CGPoint(x: x + w - c, y: y),
                  control2: CGPoint(x: x + w, y: y + c))
    path.addLine(to: CGPoint(x: x + w, y: y + h - r))
    path.addCurve(to: CGPoint(x: x + w - r, y: y + h),
                  control1: CGPoint(x: x + w, y: y + h - c),
                  control2: CGPoint(x: x + w - c, y: y + h))
    path.addLine(to: CGPoint(x: x + r, y: y + h))
    path.addCurve(to: CGPoint(x: x, y: y + h - r),
                  control1: CGPoint(x: x + c, y: y + h),
                  control2: CGPoint(x: x, y: y + h - c))
    path.addLine(to: CGPoint(x: x, y: y + r))
    path.addCurve(to: CGPoint(x: x + r, y: y),
                  control1: CGPoint(x: x, y: y + c),
                  control2: CGPoint(x: x + c, y: y))
    path.closeSubpath()
    return path
}

func makeTopRoundedRect(rect: CGRect, topRadius: CGFloat, bottomRadius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let minX = rect.minX, maxX = rect.maxX
    let minY = rect.minY, maxY = rect.maxY
    path.move(to: CGPoint(x: minX + topRadius, y: minY))
    path.addLine(to: CGPoint(x: maxX - topRadius, y: minY))
    path.addArc(tangent1End: CGPoint(x: maxX, y: minY), tangent2End: CGPoint(x: maxX, y: minY + topRadius), radius: topRadius)
    path.addLine(to: CGPoint(x: maxX, y: maxY - bottomRadius))
    path.addArc(tangent1End: CGPoint(x: maxX, y: maxY), tangent2End: CGPoint(x: maxX - bottomRadius, y: maxY), radius: bottomRadius)
    path.addLine(to: CGPoint(x: minX + bottomRadius, y: maxY))
    path.addArc(tangent1End: CGPoint(x: minX, y: maxY), tangent2End: CGPoint(x: minX, y: maxY - bottomRadius), radius: bottomRadius)
    path.addLine(to: CGPoint(x: minX, y: minY + topRadius))
    path.addArc(tangent1End: CGPoint(x: minX, y: minY), tangent2End: CGPoint(x: minX + topRadius, y: minY), radius: topRadius)
    path.closeSubpath()
    return path
}

// Option 5 · Palette E (蜜桃苏打 Peach Soda)
func renderAppIcon(pixelSize: Int, to path: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let baseCtx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    baseCtx.translateBy(x: 0, y: CGFloat(pixelSize))
    baseCtx.scaleBy(x: 1, y: -1)
    let nsCtx = NSGraphicsContext(cgContext: baseCtx, flipped: true)
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    let scale = CGFloat(pixelSize) / 1024.0
    ctx.scaleBy(x: scale, y: scale)

    // macOS HIG icon safe area: 824x824 centered inside 1024x1024 transparent canvas
    let box = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = makeSquirclePath(rect: box, radius: 192)

    // Soft native macOS icon drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 24 * scale, color: NSColor(white: 0.0, alpha: 0.16).cgColor)
    ctx.setFillColor(colorFromHex("#FFFFFF").cgColor)
    ctx.addPath(squircle)
    ctx.fillPath()
    ctx.restoreGState()

    // Crisp subtle border for light wallpaper definition
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setStrokeColor(NSColor(white: 0.0, alpha: 0.06).cgColor)
    ctx.setLineWidth(3.0)
    ctx.strokePath()
    ctx.restoreGState()

    // Inner geometry: width = 564 (x: 230..794)
    let contentLeft: CGFloat = 230
    let contentWidth: CGFloat = 564

    // Coral-pink header bar (#FF647C)
    let headerRect = CGRect(x: contentLeft, y: 234, width: contentWidth, height: 120)
    let headerPath = makeTopRoundedRect(rect: headerRect, topRadius: 28, bottomRadius: 6)
    ctx.setFillColor(colorFromHex("#FF647C").cgColor)
    ctx.addPath(headerPath)
    ctx.fillPath()

    // Two charcoal binding pill tabs (#232730) with white cutout halos
    let tabCentersX: [CGFloat] = [368, 656]
    let tabW: CGFloat = 44
    let tabH: CGFloat = 116
    let tabTop: CGFloat = 176
    let cutoutPad: CGFloat = 14

    for cx in tabCentersX {
        let haloRect = CGRect(x: cx - tabW/2 - cutoutPad,
                              y: tabTop - cutoutPad,
                              width: tabW + cutoutPad * 2,
                              height: tabH + cutoutPad * 2)
        let haloPath = CGPath(roundedRect: haloRect, cornerWidth: haloRect.width / 2, cornerHeight: haloRect.width / 2, transform: nil)
        ctx.setFillColor(colorFromHex("#FFFFFF").cgColor)
        ctx.addPath(haloPath)
        ctx.fillPath()

        let pillRect = CGRect(x: cx - tabW/2, y: tabTop, width: tabW, height: tabH)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: tabW / 2, cornerHeight: tabW / 2, transform: nil)
        ctx.setFillColor(colorFromHex("#232730").cgColor)
        ctx.addPath(pillPath)
        ctx.fillPath()
    }

    // 4 x 3 Dot Grid (#FFE0E6 soft pink dots + #00B4FF sky-blue today dot)
    let dotD: CGFloat = 108
    let gapX: CGFloat = 44
    let gapY: CGFloat = 42
    let gridTop: CGFloat = 408

    for row in 0..<3 {
        for col in 0..<4 {
            let x = contentLeft + CGFloat(col) * (dotD + gapX)
            let y = gridTop + CGFloat(row) * (dotD + gapY)
            let dotRect = CGRect(x: x, y: y, width: dotD, height: dotD)
            let isToday = (row == 1 && col == 1)
            ctx.setFillColor(colorFromHex(isToday ? "#00B4FF" : "#FFE0E6").cgColor)
            ctx.fillEllipse(in: dotRect)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// Crisp Monochrome Menu Bar Template Icon (20pt = 20px @1x, 40px @2x, slightly trimmer calendar proportions)
func renderMenuBarIcon(pixelSize: Int, to path: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let baseCtx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    baseCtx.translateBy(x: 0, y: CGFloat(pixelSize))
    baseCtx.scaleBy(x: 1, y: -1)
    let nsCtx = NSGraphicsContext(cgContext: baseCtx, flipped: true)
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    // Coordinate space 0..40 (2x = 20pt)
    let scale = CGFloat(pixelSize) / 40.0
    ctx.scaleBy(x: scale, y: scale)

    let black = NSColor.black.cgColor
    ctx.setStrokeColor(black)
    ctx.setFillColor(black)

    // Rounded calendar body outline (balanced width: 32px = 16pt inner, ~17.5pt outer width)
    let bodyRect = CGRect(x: 4.0, y: 7.0, width: 32.0, height: 29.5)
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil)
    ctx.setLineWidth(3.0)
    ctx.addPath(bodyPath)
    ctx.strokePath()

    // Horizontal top divider line
    ctx.setLineWidth(2.6)
    ctx.move(to: CGPoint(x: 4.5, y: 15.5))
    ctx.addLine(to: CGPoint(x: 35.5, y: 15.5))
    ctx.strokePath()

    // Two top binding tabs
    for cx in [13.3, 26.7] as [CGFloat] {
        let tabRect = CGRect(x: cx - 1.8, y: 2.8, width: 3.6, height: 7.6)
        let tabPath = CGPath(roundedRect: tabRect, cornerWidth: 1.8, cornerHeight: 1.8, transform: nil)
        ctx.addPath(tabPath)
        ctx.fillPath()
    }

    // Minimalist 3 x 2 dot grid inside (Option 5 signature!)
    let xs: [CGFloat] = [12.5, 20.0, 27.5]
    let ys: [CGFloat] = [22.2, 29.8]
    for (rIdx, cy) in ys.enumerated() {
        for (cIdx, cx) in xs.enumerated() {
            let isToday = (rIdx == 0 && cIdx == 1)
            let radius: CGFloat = isToday ? 2.75 : 1.82
            ctx.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let projectRoot = "/Users/iwtem/Projects/personal/Daydrop"
let fm = FileManager.default

let assetsDir = "\(projectRoot)/Daydrop/Assets.xcassets"
let appIconDir = "\(assetsDir)/AppIcon.appiconset"
let menuBarDir = "\(assetsDir)/MenuBarIcon.imageset"

try! fm.createDirectory(atPath: appIconDir, withIntermediateDirectories: true)
try! fm.createDirectory(atPath: menuBarDir, withIntermediateDirectories: true)

// Assets root Contents.json
let rootContents = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try! rootContents.write(toFile: "\(assetsDir)/Contents.json", atomically: true, encoding: .utf8)

// Generate all macOS AppIcon sizes
let sizes: [(pt: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

var iconEntries: [[String: String]] = []
for s in sizes {
    let px = s.pt * s.scale
    let filename = "icon_\(s.pt)x\(s.pt)@\(s.scale)x.png"
    renderAppIcon(pixelSize: px, to: "\(appIconDir)/\(filename)")
    iconEntries.append([
        "filename": filename,
        "idiom": "mac",
        "scale": "\(s.scale)x",
        "size": "\(s.pt)x\(s.pt)"
    ])
}

let appIconJSON: [String: Any] = [
    "images": iconEntries,
    "info": ["author": "xcode", "version": 1]
]
let appIconData = try! JSONSerialization.data(withJSONObject: appIconJSON, options: [.prettyPrinted, .sortedKeys])
try! appIconData.write(to: URL(fileURLWithPath: "\(appIconDir)/Contents.json"))

// Generate MenuBarIcon template images (20pt: 20px @1x, 40px @2x)
renderMenuBarIcon(pixelSize: 20, to: "\(menuBarDir)/menubar_18@1x.png")
renderMenuBarIcon(pixelSize: 40, to: "\(menuBarDir)/menubar_18@2x.png")

let menuBarJSON: [String: Any] = [
    "images": [
        ["filename": "menubar_18@1x.png", "idiom": "mac", "scale": "1x"],
        ["filename": "menubar_18@2x.png", "idiom": "mac", "scale": "2x"]
    ],
    "info": ["author": "xcode", "version": 1],
    "properties": ["template-rendering-intent": "template"]
]
let menuBarData = try! JSONSerialization.data(withJSONObject: menuBarJSON, options: [.prettyPrinted, .sortedKeys])
try! menuBarData.write(to: URL(fileURLWithPath: "\(menuBarDir)/Contents.json"))

print("Generated AppIcon.appiconset and MenuBarIcon.imageset successfully!")
