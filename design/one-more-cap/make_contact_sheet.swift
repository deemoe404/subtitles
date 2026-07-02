import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("previews/one-more-cap-contact-sheet.png")
let width: CGFloat = 1180
let height: CGFloat = 1060
let image = NSImage(size: NSSize(width: width, height: height))

image.lockFocus()
NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 18, weight: NSFont.Weight = .semibold) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 1)
    ]
    NSString(string: text).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

func drawImage(path: String, x: CGFloat, y: CGFloat, size: CGFloat, radius: CGFloat = 0) {
    guard let img = NSImage(contentsOfFile: path) else { return }
    let rect = NSRect(x: x, y: y, width: size, height: size)
    if radius > 0 {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
        img.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    } else {
        img.draw(in: rect)
    }
}

func drawCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: 18, yRadius: 18).fill()
}

drawText("One More Cap Icon Composer Drafts", x: 40, y: 1010, size: 26, weight: .bold)
drawText("App seams are generated from projected hemisphere meridians; subtitle bars are short-over-long.", x: 40, y: 980, size: 14, weight: .regular)

let appRows = [
    ("A Balanced", "One More Cap-a-balanced"),
    ("B Long Brim", "One More Cap-b-long-brim"),
    ("C Minimal", "One More Cap-c-minimal")
]
var y: CGFloat = 700
for row in appRows {
    drawCard(x: 40, y: y - 18, w: 760, h: 250)
    drawText(row.0, x: 70, y: y + 195, size: 18, weight: .bold)
    drawText("Default", x: 260, y: y + 195, size: 13, weight: .regular)
    drawText("Dark", x: 500, y: y + 195, size: 13, weight: .regular)
    drawImage(path: root.appendingPathComponent("previews/app-icons/\(row.1)-default.png").path, x: 240, y: y, size: 180, radius: 42)
    drawImage(path: root.appendingPathComponent("previews/app-icons/\(row.1)-dark.png").path, x: 480, y: y, size: 180, radius: 42)
    y -= 270
}

drawCard(x: 840, y: 122, w: 300, h: 828)
drawText("Menu Bar Template SVGs", x: 870, y: 905, size: 18, weight: .bold)
let menuRows = ["cap-bars-balanced", "cap-bars-wide", "cap-bars-compact", "cap-bars-minimal"]
var menuY: CGFloat = 765
for name in menuRows {
    drawText(name.replacingOccurrences(of: "cap-bars-", with: ""), x: 870, y: menuY + 55, size: 14, weight: .semibold)
    drawImage(path: root.appendingPathComponent("previews/menu-bar/\(name)-72.png").path, x: 1000, y: menuY, size: 72, radius: 10)
    drawImage(path: root.appendingPathComponent("previews/menu-bar/\(name)-36.png").path, x: 1088, y: menuY + 18, size: 36, radius: 6)
    menuY -= 160
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode contact sheet")
}

try data.write(to: output)
print(output.path)
