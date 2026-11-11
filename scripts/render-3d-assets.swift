// Renders the Skeval Timer 3D prototype assets with SceneKit, headless, to transparent PNGs.
// Apple frameworks only. Usage:
//   swift scripts/render-3d-assets.swift [output-dir] [accent-hex] [suffix]
//     Prototype set: every object at 512 px. Defaults: Prototype/3d, Citrus accent E0B24C, no suffix.
//   swift scripts/render-3d-assets.swift --app <Art3D folder> <slug=accent-hex>...
//     App set: the objects the app shows, at 192 px (@2x), as asset-catalog image sets
//     named "art-<object>-<slug>". Run through scripts/render-app-art.sh.

import AppKit
import SceneKit
import Metal
import CoreImage

let arguments = CommandLine.arguments
let appMode = arguments.count > 1 && arguments[1] == "--app"
let outputDirectory = URL(fileURLWithPath: appMode ? arguments[2] : (arguments.count > 1 ? arguments[1] : "Prototype/3d"))
let accentHex = !appMode && arguments.count > 2 ? arguments[2] : "E0B24C"
let suffix = !appMode && arguments.count > 3 ? arguments[3] : ""
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func color(_ hex: String) -> NSColor {
    let value = Int(hex, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

// Clay palette: the theme accent plus fixed status hues, matching DESIGN.md roles.
var accent = color(accentHex)  // reassigned per palette in --app mode
let cream = color("FFF4D6")
let paper = color("FFFDF5")
let ink = color("4A3F26")
let green = color("3FA36F")
let red = color("D6594F")
let sand = color("F2C46B")
let glass = NSColor(srgbRed: 0.85, green: 0.93, blue: 0.97, alpha: 0.45)

// MARK: - Clay textures, generated once with Core Image (no files, no third-party tools)

let context = CIContext(options: [.workingColorSpace: NSNull()])

/// Gray noise blurred to `blur`, with contrast stretched so fine grain still reads.
func noiseImage(blur: Double, size: Int = 512, seed: CGFloat) -> CGImage {
    let extent = CGRect(x: 0, y: 0, width: size, height: size)
    let random = CIFilter(name: "CIRandomGenerator")!.outputImage!
        .transformed(by: CGAffineTransform(translationX: seed * 97, y: seed * 53))
    let gray = random.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
    let blurred = gray.clampedToExtent().applyingGaussianBlur(sigma: blur).cropped(to: extent)
    let stretched = blurred.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.0 + blur * 0.9])
    return context.createCGImage(stretched, from: extent)!
}

/// A tangent-space normal map from a height map, so the grain catches the light.
func normalMap(from height: CGImage, strength: Double) -> CGImage {
    let width = height.width, rows = height.height
    var heights = [UInt8](repeating: 0, count: width * rows)
    let gray = CGContext(data: &heights, width: width, height: rows, bitsPerComponent: 8, bytesPerRow: width,
                         space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    gray.draw(height, in: CGRect(x: 0, y: 0, width: width, height: rows))
    var pixels = [UInt8](repeating: 255, count: width * rows * 4)
    func h(_ x: Int, _ y: Int) -> Double { Double(heights[((y + rows) % rows) * width + (x + width) % width]) / 255 }
    for y in 0..<rows {
        for x in 0..<width {
            let dx = (h(x + 1, y) - h(x - 1, y)) * strength
            let dy = (h(x, y + 1) - h(x, y - 1)) * strength
            let length = (dx * dx + dy * dy + 1).squareRoot()
            let index = (y * width + x) * 4
            pixels[index] = UInt8(max(0, min(255, (-dx / length * 0.5 + 0.5) * 255)))
            pixels[index + 1] = UInt8(max(0, min(255, (-dy / length * 0.5 + 0.5) * 255)))
            pixels[index + 2] = UInt8(max(0, min(255, (1 / length * 0.5 + 0.5) * 255)))
        }
    }
    let output = CGContext(data: &pixels, width: width, height: rows, bitsPerComponent: 8, bytesPerRow: width * 4,
                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return output.makeImage()!
}

/// Maps a gray image into a narrow brightness band, for soft colour mottling.
func band(_ image: CGImage, low: CGFloat, high: CGFloat) -> CGImage {
    let input = CIImage(cgImage: image)
    let mapped = input.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: high - low, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: high - low, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: high - low, w: 0),
        "inputBiasVector": CIVector(x: low, y: low, z: low, w: 0)])
    return context.createCGImage(mapped, from: input.extent)!
}

let fineGrain = noiseImage(blur: 1.1, seed: 1)      // the clay's tooth
let pits = noiseImage(blur: 2.6, seed: 2)           // thumb-pressed dimples
let mottle = noiseImage(blur: 18, seed: 3)          // uneven colour from hand mixing
let grainNormal = normalMap(from: fineGrain, strength: 2.2)
let pitNormal = normalMap(from: pits, strength: 3.5)
let mottleMultiply = band(mottle, low: 0.86, high: 1.0)
let roughnessVariation = band(fineGrain, low: 0.5, high: 0.82)

/// A warm, soft-edged oval used as the contact shadow.
let blobShadow: CGImage = {
    let size = 256
    let gradient = CIFilter(name: "CIGaussianGradient", parameters: [
        "inputCenter": CIVector(x: CGFloat(size) / 2, y: CGFloat(size) / 2),
        "inputRadius": CGFloat(size) * 0.42,
        "inputColor0": CIColor(red: 0.25, green: 0.17, blue: 0.04, alpha: 0.38),
        "inputColor1": CIColor(red: 0.25, green: 0.17, blue: 0.04, alpha: 0)])!.outputImage!
    return context.createCGImage(gradient, from: CGRect(x: 0, y: 0, width: size, height: size))!
}()

enum Finish { case clay, glazed, metal, glass }

func clay(_ base: NSColor, roughness: CGFloat = 0.62, finish: Finish = .clay) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = base
    material.metalness.contents = 0.0
    for property in [material.normal, material.multiply, material.roughness] {
        property.wrapS = .repeat
        property.wrapT = .repeat
        property.contentsTransform = SCNMatrix4MakeScale(2.5, 2.5, 1)
    }
    switch finish {
    case .clay:
        material.normal.contents = grainNormal
        material.normal.intensity = 0.85
        material.multiply.contents = mottleMultiply
        material.roughness.contents = roughnessVariation
    case .glazed:
        material.normal.contents = pitNormal
        material.normal.intensity = 0.25
        material.multiply.contents = mottleMultiply
        material.multiply.intensity = 0.5
        material.roughness.contents = roughness
        material.clearCoat.contents = 0.6
        material.clearCoatRoughness.contents = 0.25
    case .metal:
        material.normal.contents = pitNormal
        material.normal.intensity = 0.4
        material.roughness.contents = roughness
        material.metalness.contents = 0.55
    case .glass:
        material.roughness.contents = 0.08
        material.transparency = 0.5
    }
    return material
}

func node(_ geometry: SCNGeometry, _ material: SCNMaterial, at position: SCNVector3 = SCNVector3Zero,
          euler: SCNVector3 = SCNVector3Zero) -> SCNNode {
    geometry.materials = [material]
    let node = SCNNode(geometry: geometry)
    node.position = position
    node.eulerAngles = euler
    return node
}

let half = CGFloat.pi / 2

/// A cylinder with softly rounded rims. Plain SCNCylinder edges are razor sharp and read as plastic.
func disc(_ radius: CGFloat, _ height: CGFloat, _ material: SCNMaterial, at position: SCNVector3 = SCNVector3Zero,
          euler: SCNVector3 = SCNVector3Zero) -> SCNNode {
    let path = NSBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    path.flatness = 0.004
    let shape = SCNShape(path: path, extrusionDepth: height)
    shape.chamferRadius = min(height * 0.45, radius * 0.3, 0.08)
    shape.chamferMode = .both
    shape.materials = [material]
    let body = SCNNode(geometry: shape)
    body.eulerAngles.x = half   // extrusion runs along z; stand it on y like SCNCylinder
    let holder = SCNNode()
    holder.addChildNode(body)
    holder.position = position
    holder.eulerAngles = euler
    return holder
}

// MARK: - Objects

func stopwatch() -> SCNNode {
    let root = SCNNode()
    root.addChildNode(disc(1.0, 0.42, clay(accent), euler: SCNVector3(half, 0, 0)))
    root.addChildNode(node(SCNTorus(ringRadius: 0.98, pipeRadius: 0.09), clay(cream), at: SCNVector3(0, 0, 0.2),
                           euler: SCNVector3(half, 0, 0)))
    root.addChildNode(disc(0.86, 0.05, clay(paper, roughness: 0.35, finish: .glazed),
                           at: SCNVector3(0, 0, 0.2), euler: SCNVector3(half, 0, 0)))
    for index in 0..<12 {
        let angle = CGFloat(index) / 12 * 2 * .pi
        let tick = node(SCNBox(width: 0.05, height: index % 3 == 0 ? 0.16 : 0.09, length: 0.03, chamferRadius: 0.02),
                        clay(ink), at: SCNVector3(sin(angle) * 0.7, cos(angle) * 0.7, 0.24))
        tick.eulerAngles.z = -angle
        root.addChildNode(tick)
    }
    let minute = node(SCNBox(width: 0.07, height: 0.6, length: 0.04, chamferRadius: 0.035), clay(ink),
                      at: SCNVector3(0.15, 0.24, 0.27))
    minute.eulerAngles.z = -0.55
    root.addChildNode(minute)
    let second = node(SCNBox(width: 0.035, height: 0.68, length: 0.03, chamferRadius: 0.017), clay(red),
                      at: SCNVector3(-0.25, -0.17, 0.28))
    second.eulerAngles.z = -4.1
    root.addChildNode(second)
    root.addChildNode(node(SCNSphere(radius: 0.08), clay(ink), at: SCNVector3(0, 0, 0.28)))
    root.addChildNode(disc(0.13, 0.28, clay(cream), at: SCNVector3(0, 1.12, 0)))
    root.addChildNode(disc(0.22, 0.12, clay(accent), at: SCNVector3(0, 1.3, 0)))
    root.addChildNode(node(SCNCapsule(capRadius: 0.08, height: 0.3), clay(cream), at: SCNVector3(0.72, 0.8, 0),
                           euler: SCNVector3(0, 0, -0.78)))
    return root
}

func sun() -> SCNNode {
    let root = SCNNode()
    root.addChildNode(node(SCNSphere(radius: 0.72), clay(accent, roughness: 0.55)))
    for index in 0..<10 {
        let angle = CGFloat(index) / 10 * 2 * .pi
        let ray = node(SCNCapsule(capRadius: 0.12, height: 0.5), clay(sand),
                       at: SCNVector3(sin(angle) * 1.12, cos(angle) * 1.12, 0))
        ray.eulerAngles.z = -angle
        root.addChildNode(ray)
    }
    return root
}

func calendarStack() -> SCNNode {
    let root = SCNNode()
    for (index, offset) in [CGFloat(-0.16), -0.08, 0].enumerated() {
        let page = node(SCNBox(width: 1.7, height: 1.6, length: 0.12, chamferRadius: 0.12),
                        clay(index == 2 ? paper : cream), at: SCNVector3(offset * 0.5, offset * -0.4, offset))
        page.eulerAngles.z = offset * 0.6
        root.addChildNode(page)
    }
    root.addChildNode(node(SCNBox(width: 1.7, height: 0.42, length: 0.16, chamferRadius: 0.12), clay(accent),
                           at: SCNVector3(0, 0.6, 0.03)))
    for x in [CGFloat(-0.45), 0.45] {
        root.addChildNode(node(SCNTorus(ringRadius: 0.13, pipeRadius: 0.045), clay(ink), at: SCNVector3(x, 0.84, 0.05)))
    }
    for row in 0..<3 {
        for column in 0..<4 {
            let met = (row * 4 + column) % 5 != 3
            let isToday = row == 1 && column == 2
            let cell = node(SCNBox(width: 0.28, height: 0.22, length: 0.06, chamferRadius: 0.05),
                            clay(isToday ? accent : (met ? green.withAlphaComponent(0.85) : cream)),
                            at: SCNVector3(-0.54 + CGFloat(column) * 0.36, 0.2 - CGFloat(row) * 0.3, 0.09))
            root.addChildNode(cell)
        }
    }
    return root
}

func hourglass() -> SCNNode {
    let root = SCNNode()
    root.addChildNode(disc(0.75, 0.16, clay(accent), at: SCNVector3(0, 1.05, 0)))
    root.addChildNode(disc(0.75, 0.16, clay(accent), at: SCNVector3(0, -1.05, 0)))
    for x in [CGFloat(-0.58), 0.58] {
        root.addChildNode(disc(0.06, 2.0, clay(cream), at: SCNVector3(x, 0, 0.3)))
    }
    let glassMaterial = clay(glass, finish: .glass)
    root.addChildNode(node(SCNCone(topRadius: 0.5, bottomRadius: 0.05, height: 0.95), glassMaterial, at: SCNVector3(0, 0.5, 0)))
    root.addChildNode(node(SCNCone(topRadius: 0.05, bottomRadius: 0.5, height: 0.95), glassMaterial, at: SCNVector3(0, -0.5, 0)))
    root.addChildNode(node(SCNCone(topRadius: 0.28, bottomRadius: 0.05, height: 0.4), clay(sand), at: SCNVector3(0, 0.25, 0)))
    root.addChildNode(node(SCNCone(topRadius: 0.05, bottomRadius: 0.44, height: 0.42), clay(sand), at: SCNVector3(0, -0.76, 0)))
    return root
}

func trophy() -> SCNNode {
    let root = SCNNode()
    let gold = clay(accent, roughness: 0.32, finish: .metal)
    root.addChildNode(node(SCNCone(topRadius: 0.78, bottomRadius: 0.3, height: 0.95), gold, at: SCNVector3(0, 0.45, 0)))
    root.addChildNode(node(SCNTorus(ringRadius: 0.76, pipeRadius: 0.06), gold, at: SCNVector3(0, 0.92, 0)))
    root.addChildNode(disc(0.72, 0.04, clay(sand), at: SCNVector3(0, 0.9, 0)))
    for x in [CGFloat(-0.78), 0.78] {
        root.addChildNode(node(SCNTorus(ringRadius: 0.24, pipeRadius: 0.07), gold, at: SCNVector3(x, 0.5, 0),
                               euler: SCNVector3(half, 0, 0)))
    }
    root.addChildNode(disc(0.1, 0.4, gold, at: SCNVector3(0, -0.2, 0)))
    root.addChildNode(node(SCNBox(width: 1.0, height: 0.32, length: 0.7, chamferRadius: 0.08), clay(ink), at: SCNVector3(0, -0.52, 0)))
    root.addChildNode(node(SCNBox(width: 0.55, height: 0.12, length: 0.04, chamferRadius: 0.03), clay(sand),
                           at: SCNVector3(0, -0.52, 0.36)))
    root.addChildNode(node(SCNTorus(ringRadius: 0.57, pipeRadius: 0.035), clay(sand), at: SCNVector3(0, 0.6, 0)))
    return root
}

func flag() -> SCNNode {
    let root = SCNNode()
    root.addChildNode(disc(0.06, 2.2, clay(ink), at: SCNVector3(-0.6, 0, 0)))
    root.addChildNode(node(SCNSphere(radius: 0.12), clay(accent), at: SCNVector3(-0.6, 1.14, 0)))
    let cloth = node(SCNBox(width: 1.2, height: 0.75, length: 0.08, chamferRadius: 0.08), clay(green),
                     at: SCNVector3(0.02, 0.66, 0))
    cloth.eulerAngles.y = -0.18
    root.addChildNode(cloth)
    let check = node(SCNBox(width: 0.12, height: 0.3, length: 0.1, chamferRadius: 0.05), clay(paper),
                     at: SCNVector3(-0.08, 0.6, 0.06))
    check.eulerAngles.z = 0.7
    root.addChildNode(check)
    let check2 = node(SCNBox(width: 0.12, height: 0.52, length: 0.1, chamferRadius: 0.05), clay(paper),
                      at: SCNVector3(0.14, 0.7, 0.06))
    check2.eulerAngles.z = -0.65
    root.addChildNode(check2)
    root.addChildNode(disc(0.55, 0.14, clay(cream), at: SCNVector3(-0.6, -1.1, 0)))
    return root
}

func barsObject() -> SCNNode {
    let root = SCNNode()
    let heights: [CGFloat] = [0.7, 1.15, 0.9, 1.6]
    for (index, height) in heights.enumerated() {
        let met = height >= 1.15
        root.addChildNode(node(SCNBox(width: 0.38, height: height, length: 0.38, chamferRadius: 0.1),
                               clay(met ? green : accent),
                               at: SCNVector3(-0.75 + CGFloat(index) * 0.5, -0.8 + height / 2, 0)))
    }
    root.addChildNode(node(SCNBox(width: 2.4, height: 0.1, length: 0.8, chamferRadius: 0.05), clay(cream), at: SCNVector3(0, -0.85, 0)))
    let goal = node(SCNCapsule(capRadius: 0.03, height: 2.3), clay(ink), at: SCNVector3(0, 0.35, 0.26),
                    euler: SCNVector3(0, 0, half))
    root.addChildNode(goal)
    return root
}

func mug() -> SCNNode {
    let root = SCNNode()
    root.addChildNode(node(SCNTube(innerRadius: 0.55, outerRadius: 0.65, height: 1.0), clay(paper, roughness: 0.3, finish: .glazed)))
    root.addChildNode(disc(0.65, 0.08, clay(paper), at: SCNVector3(0, -0.48, 0)))
    root.addChildNode(disc(0.56, 0.06, clay(color("8A5A3B"), roughness: 0.2, finish: .glazed), at: SCNVector3(0, 0.36, 0)))
    root.addChildNode(node(SCNTorus(ringRadius: 0.27, pipeRadius: 0.08), clay(paper), at: SCNVector3(0.72, 0.02, 0),
                           euler: SCNVector3(half, 0, 0)))
    root.addChildNode(node(SCNTube(innerRadius: 0.6, outerRadius: 0.67, height: 0.2), clay(accent), at: SCNVector3(0, 0.02, 0)))
    for (index, x) in [CGFloat(-0.2), 0.15].enumerated() {
        let steam = node(SCNCapsule(capRadius: 0.07, height: 0.45), clay(cream), at: SCNVector3(x, 0.85 + CGFloat(index) * 0.1, 0))
        steam.eulerAngles.z = index == 0 ? 0.25 : -0.2
        root.addChildNode(steam)
    }
    root.addChildNode(disc(0.95, 0.08, clay(cream), at: SCNVector3(0, -0.56, 0)))
    return root
}

// MARK: - Rendering

func render(_ object: SCNNode, name: String, size: CGFloat = 512, tilt: SCNVector3 = SCNVector3(0.32, -0.5, 0),
            to destination: URL? = nil) {
    let scene = SCNScene()
    scene.background.contents = NSColor.clear
    object.eulerAngles = SCNVector3(object.eulerAngles.x + tilt.x, object.eulerAngles.y + tilt.y, tilt.z)
    scene.rootNode.addChildNode(object)

    let camera = SCNCamera()
    camera.fieldOfView = 32
    camera.wantsHDR = true
    camera.wantsExposureAdaptation = false
    camera.exposureOffset = -0.1
    camera.bloomIntensity = 0
    // Ambient occlusion darkens creases and contacts, which is most of what makes clay read as solid.
    camera.screenSpaceAmbientOcclusionIntensity = 1.4
    camera.screenSpaceAmbientOcclusionRadius = 0.35
    camera.screenSpaceAmbientOcclusionBias = 0.03
    camera.screenSpaceAmbientOcclusionDepthThreshold = 0.2
    camera.screenSpaceAmbientOcclusionNormalThreshold = 0.3
    let cameraNode = SCNNode()
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, -0.05, 6.8)
    scene.rootNode.addChildNode(cameraNode)

    // A soft blob shadow under the object grounds it on any background, even a transparent one.
    let (low, high) = object.boundingBox
    var minY = CGFloat.greatestFiniteMagnitude, minX = minY, maxX = -minY, minZ = minY, maxZ = -minY
    for x in [low.x, high.x] { for y in [low.y, high.y] { for z in [low.z, high.z] {
        let world = object.convertPosition(SCNVector3(x, y, z), to: scene.rootNode)
        minY = min(minY, world.y); minX = min(minX, world.x); maxX = max(maxX, world.x)
        minZ = min(minZ, world.z); maxZ = max(maxZ, world.z)
    } } }
    let blobWidth = (maxX - minX) * 1.25
    let blob = SCNPlane(width: blobWidth, height: max(blobWidth * 0.7, (maxZ - minZ) * 1.3))
    let shade = SCNMaterial()
    shade.lightingModel = .constant
    shade.diffuse.contents = blobShadow
    shade.writesToDepthBuffer = false
    shade.isDoubleSided = true
    blob.materials = [shade]
    let blobNode = SCNNode(geometry: blob)
    blobNode.eulerAngles.x = -half
    blobNode.position = SCNVector3((minX + maxX) / 2, minY - 0.02, (minZ + maxZ) / 2)
    blobNode.renderingOrder = -1
    scene.rootNode.addChildNode(blobNode)

    // Soft key from above-left, warm fill, a cool rim from behind, and a low ambient.
    let key = SCNLight()
    key.type = .directional
    key.intensity = 1500
    key.castsShadow = true
    key.shadowRadius = 14
    key.shadowSampleCount = 32
    key.shadowMapSize = CGSize(width: 2048, height: 2048)
    key.orthographicScale = 4
    key.shadowColor = NSColor(srgbRed: 0.22, green: 0.16, blue: 0.05, alpha: 0.32)
    let keyNode = SCNNode()
    keyNode.light = key
    keyNode.eulerAngles = SCNVector3(-1.05, -0.55, 0)
    scene.rootNode.addChildNode(keyNode)
    let fill = SCNLight()
    fill.type = .omni
    fill.intensity = 380
    fill.color = NSColor(srgbRed: 1, green: 0.93, blue: 0.82, alpha: 1)
    let fillNode = SCNNode()
    fillNode.light = fill
    fillNode.position = SCNVector3(-4, 0.5, 5)
    scene.rootNode.addChildNode(fillNode)
    let rim = SCNLight()
    rim.type = .directional
    rim.intensity = 900
    rim.color = NSColor(srgbRed: 0.86, green: 0.92, blue: 1, alpha: 1)
    let rimNode = SCNNode()
    rimNode.light = rim
    rimNode.eulerAngles = SCNVector3(-0.35, 2.6, 0)
    scene.rootNode.addChildNode(rimNode)
    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.intensity = 240
    ambient.color = NSColor(srgbRed: 1, green: 0.97, blue: 0.9, alpha: 1)
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    renderer.scene = scene
    renderer.pointOfView = cameraNode
    renderer.autoenablesDefaultLighting = false
    let image = renderer.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .multisampling4X)
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Could not encode \(name)\n".data(using: .utf8)!)
        return
    }
    let url = destination ?? outputDirectory.appendingPathComponent("\(name)\(suffix).png")
    try? png.write(to: url)
    print("Wrote \(url.path)")
}

let objects: [(name: String, make: () -> SCNNode, tilt: SCNVector3)] = [
    ("stopwatch", stopwatch, SCNVector3(0.32, -0.5, 0)),
    ("sun", sun, SCNVector3(0.1, -0.35, 0)),
    ("calendar", calendarStack, SCNVector3(0.2, -0.45, 0)),
    ("hourglass", hourglass, SCNVector3(0.25, -0.4, 0)),
    ("trophy", trophy, SCNVector3(0.3, -0.4, 0)),
    ("flag", flag, SCNVector3(0.15, -0.35, 0)),
    ("bars", barsObject, SCNVector3(0.35, -0.55, 0)),
    ("mug", mug, SCNVector3(0.4, -0.4, 0)),
]

if appMode {
    // Only what the app shows: page headers (sun, flag, calendar, bars) and moments (stopwatch, trophy, mug).
    let shown: Set<String> = ["sun", "flag", "calendar", "bars", "stopwatch", "trophy", "mug"]
    for spec in arguments.dropFirst(3) {
        let parts = spec.split(separator: "=").map(String.init)
        guard parts.count == 2 else { continue }
        accent = color(parts[1])
        for object in objects where shown.contains(object.name) {
            let set = outputDirectory.appendingPathComponent("art-\(object.name)-\(parts[0]).imageset")
            try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
            let file = "art-\(object.name)-\(parts[0]).png"
            render(object.make(), name: object.name, size: 192, tilt: object.tilt, to: set.appendingPathComponent(file))
            let contents = """
            {"images":[{"idiom":"universal","scale":"1x"},{"filename":"\(file)","idiom":"universal","scale":"2x"},\
            {"idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}
            """
            try? contents.write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        }
    }
} else {
    for object in objects { render(object.make(), name: object.name, tilt: object.tilt) }
}
