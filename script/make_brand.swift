#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(
  fileURLWithPath: CommandLine.arguments.dropFirst().first
    ?? FileManager.default.currentDirectoryPath, isDirectory: true)
let brand = root.appendingPathComponent("docs/assets/brand")
let resources = root.appendingPathComponent("Resources/Brand")
let iconset = root.appendingPathComponent("Resources/Vapula.iconset")
for dir in [brand, resources, iconset] {
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}
let svgPath =
  "M20 28V76H80V28 M20 32H36V48H64V32H80 M50 44V22 C30 10 41 3 50 12 C59 3 70 10 50 22 M50 76V88 M40 88H60"
for (name, color) in [("light", "#0B0B0B"), ("dark", "#F5F5F7")] {
  let svg =
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><title>VAPULA — authored geometric seal</title><path d=\"\(svgPath)\" fill=\"none\" stroke=\"\(color)\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>\n"
  try svg.write(
    to: brand.appendingPathComponent("symbol-\(name).svg"), atomically: true, encoding: .utf8)
}
func bitmap(_ width: Int, _ height: Int, _ destination: URL, draw: () -> Void) throws {
  guard
    let image = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: image)
  else { throw NSError(domain: "Brand", code: 1) }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  draw()
  NSGraphicsContext.restoreGraphicsState()
  guard let data = image.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "Brand", code: 2)
  }
  try data.write(to: destination)
}
func seal(_ rect: NSRect, _ color: NSColor, small: Bool = false) {
  NSGraphicsContext.saveGraphicsState()
  let t = NSAffineTransform()
  t.translateX(by: rect.minX, yBy: rect.maxY)
  t.scaleX(by: rect.width / 100, yBy: -rect.height / 100)
  t.concat()
  let p = NSBezierPath()
  p.lineWidth = small ? 5 : 2.2
  p.lineCapStyle = .round
  p.lineJoinStyle = .round
  p.move(to: NSPoint(x: 20, y: 28))
  p.line(to: NSPoint(x: 20, y: 76))
  p.line(to: NSPoint(x: 80, y: 76))
  p.line(to: NSPoint(x: 80, y: 28))
  p.move(to: NSPoint(x: 20, y: 32))
  p.line(to: NSPoint(x: 36, y: 32))
  p.line(to: NSPoint(x: 36, y: 48))
  p.line(to: NSPoint(x: 64, y: 48))
  p.line(to: NSPoint(x: 64, y: 32))
  p.line(to: NSPoint(x: 80, y: 32))
  p.move(to: NSPoint(x: 50, y: 44))
  p.line(to: NSPoint(x: 50, y: 22))
  p.curve(
    to: NSPoint(x: 50, y: 12), controlPoint1: NSPoint(x: 30, y: 10),
    controlPoint2: NSPoint(x: 41, y: 3))
  p.curve(
    to: NSPoint(x: 50, y: 22), controlPoint1: NSPoint(x: 59, y: 3),
    controlPoint2: NSPoint(x: 70, y: 10))
  p.move(to: NSPoint(x: 50, y: 76))
  p.line(to: NSPoint(x: 50, y: 88))
  p.move(to: NSPoint(x: 40, y: 88))
  p.line(to: NSPoint(x: 60, y: 88))
  color.setStroke()
  p.stroke()
  NSGraphicsContext.restoreGraphicsState()
}
for side in [16, 32, 64, 128, 256, 512, 1024] {
  let file = brand.appendingPathComponent("icon-\(side).png")
  try bitmap(side, side, file) {
    let s = CGFloat(side)
    NSColor(white: 0.045, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: s * 0.055, y: s * 0.055, width: s * 0.89, height: s * 0.89),
      xRadius: s * 0.20, yRadius: s * 0.20
    ).fill()
    seal(
      NSRect(x: s * 0.11, y: s * 0.11, width: s * 0.78, height: s * 0.78), .white, small: side <= 32
    )
  }
  if side <= 512 {
    try Data(contentsOf: file).write(to: iconset.appendingPathComponent("icon_\(side)x\(side).png"))
  }
  if side >= 32 {
    try Data(contentsOf: file).write(
      to: iconset.appendingPathComponent("icon_\(side/2)x\(side/2)@2x.png"))
  }
  if side == 1024 {
    try Data(contentsOf: file).write(to: brand.appendingPathComponent("app-icon.png"))
  }
}
for (name, color) in [
  ("light", NSColor(white: 0.045, alpha: 1)), ("dark", NSColor(white: 0.96, alpha: 1)),
] {
  try bitmap(1024, 1024, brand.appendingPathComponent("symbol-\(name).png")) {
    seal(NSRect(x: 0, y: 0, width: 1024, height: 1024), color)
  }
}
func text(
  _ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ weight: NSFont.Weight,
  _ color: NSColor, kern: CGFloat = 0
) {
  (value as NSString).draw(
    at: NSPoint(x: x, y: y),
    withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: kern,
    ])
}
try bitmap(1600, 800, brand.appendingPathComponent("cover.png")) {
  NSColor(white: 0.045, alpha: 1).setFill()
  NSRect(x: 0, y: 0, width: 1600, height: 800).fill()
  seal(NSRect(x: 1020, y: 195, width: 470, height: 470), NSColor(white: 0.93, alpha: 1))
  text("VAPULA", 90, 535, 92, .medium, .white, kern: 11)
  text("Data & Statistical Laboratory", 96, 459, 32, .regular, NSColor(white: 0.76, alpha: 1))
  text("From data to evidence.", 96, 347, 39, .regular, NSColor(white: 0.96, alpha: 1))
  let line = NSBezierPath()
  line.move(to: NSPoint(x: 96, y: 205))
  line.line(to: NSPoint(x: 1504, y: 205))
  line.lineWidth = 1
  NSColor(white: 0.32, alpha: 1).setStroke()
  line.stroke()
  text(
    "macOS · Apple Silicon · Local processing", 96, 131, 22, .regular, NSColor(white: 0.7, alpha: 1)
  )
  text("Creado por Sebastián Pastén F.", 1110, 83, 18, .regular, NSColor(white: 0.7, alpha: 1))
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
  "-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path,
]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(1) }
try FileManager.default.removeItem(at: iconset)
print("Brand regenerated: \(brand.path)")
