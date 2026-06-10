#!/usr/bin/swift
import Foundation
import CoreGraphics
import ImageIO
import Darwin

let iconSize = 1024
let w = CGFloat(iconSize)
let h = CGFloat(iconSize)

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

guard let ctx = CGContext(
    data: nil,
    width: iconSize,
    height: iconSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else { print("Failed to create context"); exit(1) }

// Flip so (0,0) is top-left, matching SwiftUI coordinate system
ctx.translateBy(x: 0, y: h)
ctx.scaleBy(x: 1, y: -1)

// Background gradient: top-left to bottom-right
let gradStart = CGColor(colorSpace: colorSpace, components: [0.09, 0.38, 0.24, 1.0])!
let gradEnd   = CGColor(colorSpace: colorSpace, components: [0.04, 0.20, 0.12, 1.0])!
let gradient  = CGGradient(colorsSpace: colorSpace, colors: [gradStart, gradEnd] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])

// Concentric circles
let cx = w / 2, cy = h / 2
func fillCircle(radius: CGFloat, alpha: CGFloat) {
    ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, alpha])!)
    ctx.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
}
fillCircle(radius: 470, alpha: 0.08)
fillCircle(radius: 390, alpha: 0.15)

// W trend line — same proportional coordinates as WelcomeView Canvas
let scale: CGFloat = 12.5  // 66×46 canvas scaled up
let canvasW = 66 * scale
let canvasH = 46 * scale
let originX = cx - canvasW / 2
let originY = cy - canvasH / 2

func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
    CGPoint(x: originX + fx * canvasW, y: originY + fy * canvasH)
}

ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!)
ctx.setLineWidth(4.5 * scale)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

ctx.beginPath()
ctx.move(to:    pt(0.05, 0.24))
ctx.addLine(to: pt(0.26, 0.82))
ctx.addLine(to: pt(0.50, 0.40))
ctx.addLine(to: pt(0.67, 0.78))
ctx.addLine(to: pt(0.97, 0.06))
ctx.strokePath()

// Arrowhead at tip
let tip  = pt(0.97, 0.06)
let prev = pt(0.67, 0.78)
let dx = tip.x - prev.x
let dy = tip.y - prev.y
let len = sqrt(dx * dx + dy * dy)
let nx = dx / len, ny = dy / len
let arrowLen: CGFloat = 11 * scale
let arrowAngle: CGFloat = 0.45

let lx = tip.x - arrowLen * (nx * cos(arrowAngle) - ny * sin(arrowAngle))
let ly = tip.y - arrowLen * (ny * cos(arrowAngle) + nx * sin(arrowAngle))
let rx = tip.x - arrowLen * (nx * cos(-arrowAngle) - ny * sin(-arrowAngle))
let ry = tip.y - arrowLen * (ny * cos(-arrowAngle) + nx * sin(-arrowAngle))

ctx.beginPath()
ctx.move(to: CGPoint(x: lx, y: ly))
ctx.addLine(to: tip)
ctx.addLine(to: CGPoint(x: rx, y: ry))
ctx.strokePath()

// Write PNG
guard let image = ctx.makeImage() else { print("Failed to create image"); exit(1) }

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = cwd
    .appendingPathComponent("WealthPath")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")
    .appendingPathComponent("AppIcon.png")

guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
    print("Failed to create destination at: \(outputURL.path)")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { print("Failed to write PNG"); exit(1) }

print("✅ App icon saved to \(outputURL.path)")
