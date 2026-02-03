#!/usr/bin/env swift

import AppKit
import Foundation

// Generate DMG background image with "drag to Applications" visual

func createDMGBackground() -> NSImage {
    let width: CGFloat = 600
    let height: CGFloat = 400
    
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Background gradient (light gray to white)
    let bgGradient = NSGradient(starting: NSColor(white: 0.95, alpha: 1.0),
                                 ending: NSColor(white: 0.88, alpha: 1.0))!
    bgGradient.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -90)
    
    // Title text "Install CPU Cap"
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .medium),
        .foregroundColor: NSColor(white: 0.25, alpha: 1.0)
    ]
    let title = "Install CPU Cap"
    let titleSize = title.size(withAttributes: titleAttrs)
    title.draw(at: CGPoint(x: (width - titleSize.width) / 2, y: height - 60), withAttributes: titleAttrs)
    
    // Instruction text
    let instrAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(white: 0.45, alpha: 1.0)
    ]
    let instruction = "Drag CPU Cap to Applications to install"
    let instrSize = instruction.size(withAttributes: instrAttrs)
    instruction.draw(at: CGPoint(x: (width - instrSize.width) / 2, y: height - 90), withAttributes: instrAttrs)
    
    // Icon positions
    let iconY: CGFloat = height / 2 - 40
    let appIconX: CGFloat = 150
    let folderIconX: CGFloat = 450
    let iconSize: CGFloat = 100
    
    // Left placeholder area (app icon will be here)
    let appRect = CGRect(x: appIconX - iconSize/2, y: iconY - iconSize/2, width: iconSize, height: iconSize)
    let appPlaceholder = NSBezierPath(roundedRect: appRect, xRadius: 20, yRadius: 20)
    NSColor(white: 0.85, alpha: 0.5).setFill()
    appPlaceholder.fill()
    
    // Right placeholder area (Applications folder will be here)
    let folderRect = CGRect(x: folderIconX - iconSize/2, y: iconY - iconSize/2, width: iconSize, height: iconSize)
    let folderPlaceholder = NSBezierPath(roundedRect: folderRect, xRadius: 20, yRadius: 20)
    NSColor(white: 0.85, alpha: 0.5).setFill()
    folderPlaceholder.fill()
    
    // Draw arrow from app to folder
    let arrowPath = NSBezierPath()
    let arrowStartX = appIconX + iconSize/2 + 20
    let arrowEndX = folderIconX - iconSize/2 - 20
    let arrowY = iconY
    
    arrowPath.lineWidth = 3
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    
    // Arrow line (dashed)
    arrowPath.move(to: CGPoint(x: arrowStartX, y: arrowY))
    arrowPath.line(to: CGPoint(x: arrowEndX - 15, y: arrowY))
    
    // Arrow head
    arrowPath.move(to: CGPoint(x: arrowEndX - 25, y: arrowY + 12))
    arrowPath.line(to: CGPoint(x: arrowEndX, y: arrowY))
    arrowPath.line(to: CGPoint(x: arrowEndX - 25, y: arrowY - 12))
    
    NSColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.8).setStroke()
    let dashPattern: [CGFloat] = [8, 4]
    arrowPath.setLineDash(dashPattern, count: 2, phase: 0)
    arrowPath.stroke()
    
    // Solid arrow head
    let arrowHead = NSBezierPath()
    arrowHead.lineWidth = 3
    arrowHead.move(to: CGPoint(x: arrowEndX - 25, y: arrowY + 12))
    arrowHead.line(to: CGPoint(x: arrowEndX, y: arrowY))
    arrowHead.line(to: CGPoint(x: arrowEndX - 25, y: arrowY - 12))
    arrowHead.setLineDash(nil, count: 0, phase: 0)
    arrowHead.stroke()
    
    // Labels under icons
    let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor(white: 0.35, alpha: 1.0)
    ]
    
    let appLabel = "CPU Cap"
    let appLabelSize = appLabel.size(withAttributes: labelAttrs)
    appLabel.draw(at: CGPoint(x: appIconX - appLabelSize.width/2, y: iconY - iconSize/2 - 25), 
                  withAttributes: labelAttrs)
    
    let folderLabel = "Applications"
    let folderLabelSize = folderLabel.size(withAttributes: labelAttrs)
    folderLabel.draw(at: CGPoint(x: folderIconX - folderLabelSize.width/2, y: iconY - iconSize/2 - 25), 
                     withAttributes: labelAttrs)
    
    image.unlockFocus()
    
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Failed to write: \(error)")
    }
}

// Create dmg resources directory
let dmgPath = "/Users/t/Documents/KLODE/cpucutoff/dmg-resources"
try? FileManager.default.createDirectory(atPath: dmgPath, withIntermediateDirectories: true)

// Generate and save
let background = createDMGBackground()
savePNG(background, to: "\(dmgPath)/background.png")

// Also create a @2x version for Retina
let background2x = NSImage(size: NSSize(width: 1200, height: 800))
background2x.lockFocus()
let bgGradient2x = NSGradient(starting: NSColor(white: 0.95, alpha: 1.0),
                               ending: NSColor(white: 0.88, alpha: 1.0))!
bgGradient2x.draw(in: CGRect(x: 0, y: 0, width: 1200, height: 800), angle: -90)

// Scale up all drawing
let transform = NSAffineTransform()
transform.scale(by: 2.0)
transform.concat()

// Redraw at 2x
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .medium),
    .foregroundColor: NSColor(white: 0.25, alpha: 1.0)
]
let title = "Install CPU Cap"
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(at: CGPoint(x: (600 - titleSize.width) / 2, y: 400 - 60), withAttributes: titleAttrs)

let instrAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor(white: 0.45, alpha: 1.0)
]
let instruction = "Drag CPU Cap to Applications to install"
let instrSize = instruction.size(withAttributes: instrAttrs)
instruction.draw(at: CGPoint(x: (600 - instrSize.width) / 2, y: 400 - 90), withAttributes: instrAttrs)

background2x.unlockFocus()
savePNG(background2x, to: "\(dmgPath)/background@2x.png")

print("\nDMG background generation complete!")
