#!/usr/bin/env swift

import AppKit
import Foundation

// Generate app icon: CPU chip with a speed limit gauge overlay

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let context = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 512.0
    
    // Background - rounded square with gradient
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05), 
                               xRadius: size * 0.2, yRadius: size * 0.2)
    
    // Gradient background (dark blue to lighter blue)
    let gradient = NSGradient(starting: NSColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1.0),
                              ending: NSColor(red: 0.25, green: 0.40, blue: 0.65, alpha: 1.0))!
    gradient.draw(in: bgPath, angle: -45)
    
    // CPU chip body (center square)
    let chipSize = size * 0.5
    let chipRect = CGRect(x: (size - chipSize) / 2, y: (size - chipSize) / 2, 
                          width: chipSize, height: chipSize)
    let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: size * 0.04, yRadius: size * 0.04)
    
    // Chip gradient (silver/gray metallic look)
    let chipGradient = NSGradient(starting: NSColor(white: 0.85, alpha: 1.0),
                                   ending: NSColor(white: 0.65, alpha: 1.0))!
    chipGradient.draw(in: chipPath, angle: -45)
    
    // Chip border
    NSColor(white: 0.5, alpha: 1.0).setStroke()
    chipPath.lineWidth = size * 0.01
    chipPath.stroke()
    
    // CPU pins (on all 4 sides)
    let pinColor = NSColor(white: 0.7, alpha: 1.0)
    pinColor.setFill()
    
    let pinWidth = size * 0.035
    let pinLength = size * 0.08
    let pinSpacing = size * 0.08
    let numPins = 4
    let startOffset = (chipSize - (CGFloat(numPins) * pinSpacing)) / 2 + pinSpacing / 2
    
    for i in 0..<numPins {
        let offset = startOffset + CGFloat(i) * pinSpacing
        
        // Top pins
        let topPin = NSBezierPath(roundedRect: CGRect(
            x: (size - chipSize) / 2 + offset - pinWidth / 2,
            y: (size + chipSize) / 2,
            width: pinWidth, height: pinLength
        ), xRadius: pinWidth * 0.3, yRadius: pinWidth * 0.3)
        topPin.fill()
        
        // Bottom pins
        let bottomPin = NSBezierPath(roundedRect: CGRect(
            x: (size - chipSize) / 2 + offset - pinWidth / 2,
            y: (size - chipSize) / 2 - pinLength,
            width: pinWidth, height: pinLength
        ), xRadius: pinWidth * 0.3, yRadius: pinWidth * 0.3)
        bottomPin.fill()
        
        // Left pins
        let leftPin = NSBezierPath(roundedRect: CGRect(
            x: (size - chipSize) / 2 - pinLength,
            y: (size - chipSize) / 2 + offset - pinWidth / 2,
            width: pinLength, height: pinWidth
        ), xRadius: pinWidth * 0.3, yRadius: pinWidth * 0.3)
        leftPin.fill()
        
        // Right pins
        let rightPin = NSBezierPath(roundedRect: CGRect(
            x: (size + chipSize) / 2,
            y: (size - chipSize) / 2 + offset - pinWidth / 2,
            width: pinLength, height: pinWidth
        ), xRadius: pinWidth * 0.3, yRadius: pinWidth * 0.3)
        rightPin.fill()
    }
    
    // Inner chip detail (smaller square)
    let innerSize = chipSize * 0.65
    let innerRect = CGRect(x: (size - innerSize) / 2, y: (size - innerSize) / 2,
                           width: innerSize, height: innerSize)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: size * 0.02, yRadius: size * 0.02)
    
    let innerGradient = NSGradient(starting: NSColor(white: 0.35, alpha: 1.0),
                                    ending: NSColor(white: 0.25, alpha: 1.0))!
    innerGradient.draw(in: innerPath, angle: -45)
    
    // Speed gauge arc (limit indicator) - bottom right corner overlay
    let gaugeCenter = CGPoint(x: size * 0.72, y: size * 0.28)
    let gaugeRadius = size * 0.22
    
    // Gauge background circle
    let gaugeBg = NSBezierPath(ovalIn: CGRect(
        x: gaugeCenter.x - gaugeRadius,
        y: gaugeCenter.y - gaugeRadius,
        width: gaugeRadius * 2,
        height: gaugeRadius * 2
    ))
    NSColor(red: 0.95, green: 0.3, blue: 0.2, alpha: 1.0).setFill()
    gaugeBg.fill()
    
    // White inner circle
    let innerGaugeRadius = gaugeRadius * 0.75
    let gaugeInner = NSBezierPath(ovalIn: CGRect(
        x: gaugeCenter.x - innerGaugeRadius,
        y: gaugeCenter.y - innerGaugeRadius,
        width: innerGaugeRadius * 2,
        height: innerGaugeRadius * 2
    ))
    NSColor.white.setFill()
    gaugeInner.fill()
    
    // Speed limit number "30" or just a line
    let limitPath = NSBezierPath()
    limitPath.lineWidth = size * 0.025
    limitPath.move(to: CGPoint(x: gaugeCenter.x - gaugeRadius * 0.4, y: gaugeCenter.y))
    limitPath.line(to: CGPoint(x: gaugeCenter.x + gaugeRadius * 0.4, y: gaugeCenter.y))
    NSColor(red: 0.9, green: 0.2, blue: 0.15, alpha: 1.0).setStroke()
    limitPath.stroke()
    
    // Small text or ticks to indicate limit
    let tickPath = NSBezierPath()
    tickPath.lineWidth = size * 0.015
    tickPath.move(to: CGPoint(x: gaugeCenter.x, y: gaugeCenter.y + gaugeRadius * 0.35))
    tickPath.line(to: CGPoint(x: gaugeCenter.x, y: gaugeCenter.y + gaugeRadius * 0.55))
    tickPath.move(to: CGPoint(x: gaugeCenter.x - gaugeRadius * 0.35, y: gaugeCenter.y + gaugeRadius * 0.15))
    tickPath.line(to: CGPoint(x: gaugeCenter.x - gaugeRadius * 0.5, y: gaugeCenter.y + gaugeRadius * 0.25))
    tickPath.move(to: CGPoint(x: gaugeCenter.x + gaugeRadius * 0.35, y: gaugeCenter.y + gaugeRadius * 0.15))
    tickPath.line(to: CGPoint(x: gaugeCenter.x + gaugeRadius * 0.5, y: gaugeCenter.y + gaugeRadius * 0.25))
    NSColor.black.setStroke()
    tickPath.stroke()
    
    image.unlockFocus()
    
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Create Assets.xcassets structure
let basePath = "/Users/t/Documents/KLODE/cpucutoff/CPUCap/CPUCap/Resources/Assets.xcassets"
let iconPath = "\(basePath)/AppIcon.appiconset"

// Create directories
try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: iconPath, withIntermediateDirectories: true)

// Icon sizes needed for macOS
let sizes: [(CGFloat, String, String)] = [
    (16, "16", "1x"),
    (32, "16", "2x"),
    (32, "32", "1x"),
    (64, "32", "2x"),
    (128, "128", "1x"),
    (256, "128", "2x"),
    (256, "256", "1x"),
    (512, "256", "2x"),
    (512, "512", "1x"),
    (1024, "512", "2x"),
]

var iconContents: [[String: Any]] = []

for (pixelSize, pointSize, scale) in sizes {
    let filename = "icon_\(Int(pixelSize))x\(Int(pixelSize)).png"
    let icon = createIcon(size: pixelSize)
    savePNG(icon, to: "\(iconPath)/\(filename)")
    
    iconContents.append([
        "filename": filename,
        "idiom": "mac",
        "scale": scale,
        "size": "\(pointSize)x\(pointSize)"
    ])
}

// Write Contents.json
let contents: [String: Any] = [
    "images": iconContents,
    "info": ["author": "xcode", "version": 1]
]

let jsonData = try! JSONSerialization.data(withJSONObject: contents, options: .prettyPrinted)
try! jsonData.write(to: URL(fileURLWithPath: "\(iconPath)/Contents.json"))
print("Created: \(iconPath)/Contents.json")

// Also create the Assets.xcassets Contents.json
let assetsContents: [String: Any] = [
    "info": ["author": "xcode", "version": 1]
]
let assetsJsonData = try! JSONSerialization.data(withJSONObject: assetsContents, options: .prettyPrinted)
try! assetsJsonData.write(to: URL(fileURLWithPath: "\(basePath)/Contents.json"))
print("Created: \(basePath)/Contents.json")

print("\nIcon generation complete!")
