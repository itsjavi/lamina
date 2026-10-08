// Paints an oil-style seascape at sunset as a Lamina project: a toned ground, four passes of bristle brush strokes
// (block-in, body, detail, accents) each on its own layer, then canvas weave and impasto relief in Overlay, a varnish
// sheen and the sun's glow in Screen, and a warm Curves grade. Strokes follow the light of a procedural reference scene
// (after Hertzmann's painterly rendering): each pass samples a blurred copy of it and lays curved strokes along its
// contours. The website's oil-painting.webp is taken from it (brand/README.md). Compile it: unoptimized, it's slow.
//   swiftc -O scripts/oil-painting-project.swift -o /private/tmp/oil-painting && /private/tmp/oil-painting "<out.lam>"
import AppKit
import simd
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 2 else { print("usage: oil-painting <out.lam>"); exit(64) }
let package = URL(fileURLWithPath: arguments[1])
let images = package.appendingPathComponent("images")
try? FileManager.default.removeItem(at: package)
try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

let W = 2400, H = 1600
let Wf = Float(W), Hf = Float(H)
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

typealias RGB = SIMD3<Float>
typealias P = SIMD2<Float>

// MARK: - Random, noise and color helpers

struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
var rng = SplitMix(state: 20261008)
func rand(_ a: Float, _ b: Float) -> Float { Float.random(in: a..<b, using: &rng) }

@inline(__always) func hash(_ x: Int32, _ y: Int32, _ seed: Int32) -> Float {
    var h = UInt32(bitPattern: x &* 374761393 &+ y &* 668265263 &+ seed &* 1442695041)
    h = (h ^ (h >> 13)) &* 1274126177
    h ^= h >> 16
    return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
}
@inline(__always) func noise(_ x: Float, _ y: Float, _ seed: Int32) -> Float {
    let xi = x.rounded(.down), yi = y.rounded(.down)
    let fx = x - xi, fy = y - yi
    let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
    let ix = Int32(xi), iy = Int32(yi)
    let a = hash(ix, iy, seed), b = hash(ix &+ 1, iy, seed), c = hash(ix, iy &+ 1, seed), d = hash(ix &+ 1, iy &+ 1, seed)
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
}
func fbm(_ x: Float, _ y: Float, _ seed: Int32, _ octaves: Int = 5) -> Float {
    var sum: Float = 0, amp: Float = 0.5, f: Float = 1, norm: Float = 0
    for o in 0..<octaves {
        sum += amp * noise(x * f + Float(o) * 13.7, y * f, seed &+ Int32(o) &* 17)
        norm += amp; amp *= 0.5; f *= 2.03
    }
    return sum / norm
}
func rgb(_ hex: UInt32) -> RGB { RGB(Float(hex >> 16 & 255), Float(hex >> 8 & 255), Float(hex & 255)) / 255 }
func mix(_ a: RGB, _ b: RGB, _ t: Float) -> RGB { a + (b - a) * t }
func clamp01(_ x: Float) -> Float { min(max(x, 0), 1) }
func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float { let t = clamp01((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t) }
func stops(_ list: [(Float, UInt32)], _ t: Float) -> RGB {
    for i in 1..<list.count where t <= list[i].0 {
        let (t0, c0) = list[i - 1], (t1, c1) = list[i]
        return mix(rgb(c0), rgb(c1), smoothstep(t0, t1, t))
    }
    return rgb(list[list.count - 1].1)
}
func parallelRows(_ body: (Int) -> Void) { DispatchQueue.concurrentPerform(iterations: H, execute: body) }

// MARK: - The reference scene

let horizon: Float = 0.585 * Hf
let sun = P(0.64 * Wf, 0.505 * Hf), sunRadius: Float = 46
let headlandEnd: Float = 0.45 * Wf, headlandBase = horizon + 30
enum Region: UInt8 { case sky, sea, headland, rock }

func ridgeY(_ x: Float) -> Float {
    let t = x / headlandEnd
    guard t < 1 else { return .infinity }
    let height = Hf * 0.27 * (1 - smoothstep(0.3, 1.0, t)) * (0.85 + 0.15 * (1 - t))
    let jag = (fbm(x / 90, 3.7, 11) - 0.5) * 60 + (fbm(x / 22, 9.1, 12) - 0.5) * 16
    return horizon - height + jag * smoothstep(0, 40, height)
}
let rocks: [(P, P)] = [(P(1920, 1530), P(300, 110)), (P(2290, 1410), P(170, 95)), (P(1630, 1600), P(150, 60)),
                       (P(180, 1590), P(280, 75))]
func rockField(_ x: Float, _ y: Float) -> Float {
    var best: Float = -10
    for (c, r) in rocks {
        let d = (P(x, y) - c) / r
        best = max(best, 1 - (d * d).sum())
    }
    return best + (fbm(x / 70, y / 70, 21) - 0.5) * 0.7
}
func skyColor(_ x: Float, _ y: Float) -> RGB {
    let t = y / horizon
    var c = stops([(0, 0x1F2A52), (0.30, 0x3E3A6E), (0.55, 0x8A5478), (0.75, 0xD8746A), (0.90, 0xF3A25E), (1.0, 0xF9CF86)], t)
    let d = simd_distance(P(x, y), sun)
    c = mix(c, rgb(0xFFE2A8), min(1, 0.75 * expf(-(d / 150) * (d / 150)) + 0.35 * expf(-(d / 420) * (d / 420))))
    c = mix(c, rgb(0xFFF6DC), smoothstep(sunRadius + 3, sunRadius - 3, d))
    // Clouds: warped, horizontally stretched noise, lit on their undersides and more so near the sun.
    let density: (Float, Float) -> Float = { px, py in
        fbm(px / 560 + 0.6 * fbm(px / 300, py / 300, 5, 3), py / 95, 3, 6)
    }
    let band = smoothstep(0.08, 0.25, t) * (1 - smoothstep(0.80, 0.97, t))
    let n = density(x, y)
    let cover = smoothstep(0.50, 0.66, n) * band * (1 - 0.85 * expf(-(d / 130) * (d / 130)))
    if cover > 0 {
        let lit = clamp01((n - density(x, y + 16)) * 9 + 0.3)
        let sunLit = expf(-(d / 700) * (d / 700))
        let shadow = mix(rgb(0x4B3A63), rgb(0x7A5574), t)
        let bright = mix(rgb(0xE9876B), rgb(0xFFC98A), sunLit)
        c = mix(c, mix(shadow, bright, clamp01(lit * 0.8 + sunLit * 0.35)), cover * 0.92)
    }
    let streak = smoothstep(0.6, 0.75, fbm(x / 700, y / 18, 7)) * smoothstep(0.7, 0.85, t) * (1 - smoothstep(0.97, 1.0, t))
    if streak > 0 {
        c = mix(c, mix(rgb(0xB5607A), rgb(0xFFD49A), expf(-(d / 600) * (d / 600))), streak * 0.7)
    }
    return c
}
func seaColor(_ x: Float, _ y: Float) -> RGB {
    let s = (y - horizon) / (Hf - horizon)
    var c = stops([(0, 0x8A6A8E), (0.3, 0x3E4A6E), (1, 0x0F1D33)], powf(s, 0.8))
    let wave = fbm(x / (80 + 500 * s), y / (5 + 45 * s), 41)
    c *= 0.7 + 0.6 * wave
    c = mix(c, rgb(0xA483A6), smoothstep(0.6, 0.74, wave) * (1 - 0.6 * s) * 0.55)
    let dx = x - sun.x, w = 30 + 380 * s
    let path = expf(-(dx / w) * (dx / w))
    let glint = smoothstep(0.46, 0.64, fbm(x / (40 + 260 * s), y / (4 + 30 * s), 43))
    c = mix(c, mix(rgb(0xFFD27E), rgb(0xFFF2C8), 1 - s), clamp01(path * (0.12 + 1.0 * glint) * (1 - 0.3 * s)))
    c = mix(c, rgb(0xF2B277), smoothstep(22, 0, y - horizon) * 0.6)
    // The headland's reflection, broken up by the ripples.
    if x < headlandEnd, y > headlandBase {
        let length = max(0, headlandBase - ridgeY(x)) * 0.55
        let r = smoothstep(length, length * 0.4, y - headlandBase) * (0.6 + 0.4 * wave)
        c = mix(c, rgb(0x1C1A26), r * 0.6)
    }
    return c
}
func headlandColor(_ x: Float, _ y: Float, ridge: Float) -> RGB {
    let depth = y - ridge
    var c = mix(rgb(0x3D3B2A), rgb(0x2E2328), smoothstep(8, 40, depth))
    c *= 0.88 + 0.24 * fbm(x / 40, y / 160, 13)
    let slope = ridgeY(x + 6) - ridgeY(x - 6)
    c = mix(c, rgb(0xF2A05A), smoothstep(14, 0, depth) * clamp01(slope * 0.12 + 0.35))
    c = mix(c, rgb(0xD9907A), 0.18 + 0.3 * smoothstep(0.4, 1, x / headlandEnd))
    // Foam where the headland meets the sea.
    let foam = smoothstep(5, 0, abs(y - headlandBase + 2)) * smoothstep(0.4, 0.6, fbm(x / 30, y / 8, 17))
    return mix(c, rgb(0xE8D2C0), foam)
}
func rockColor(_ x: Float, _ y: Float, field f: Float) -> RGB {
    var c = rgb(0x1E1B22) * (0.85 + 0.3 * fbm(x / 25, y / 25, 23))
    let g = P(rockField(x + 3, y) - rockField(x - 3, y), rockField(x, y + 3) - rockField(x, y - 3))
    let outward = -g / max(simd_length(g), 1e-5)
    let toSun = simd_normalize(sun - P(x, y))
    let rim = smoothstep(0.16, 0.02, f) * clamp01(simd_dot(outward, toSun))
    c = mix(c, rgb(0xD98A55), rim * 0.85)
    return c
}

var reference = [Float](repeating: 0, count: W * H * 3)
var regions = [UInt8](repeating: 0, count: W * H)
reference.withUnsafeMutableBufferPointer { ref in
    regions.withUnsafeMutableBufferPointer { reg in
        parallelRows { row in
            let y = Float(row) + 0.5
            for col in 0..<W {
                let x = Float(col) + 0.5
                var c: RGB, region: Region
                let ridge = ridgeY(x)
                if y < horizon && y < ridge { c = skyColor(x, y); region = .sky }
                else if y >= ridge && y < headlandBase + 3 { c = headlandColor(x, y, ridge: ridge); region = .headland }
                else if y < horizon { c = skyColor(x, y); region = .sky }
                else { c = seaColor(x, y); region = .sea }
                if y > horizon + 200 {
                    let f = rockField(x, y)
                    if f > 0 { c = rockColor(x, y, field: f); region = .rock }
                    else if f > -0.2 {
                        let foam = smoothstep(-0.2, -0.03, f) * smoothstep(0.35, 0.6, fbm(x / 24, y / 12, 29))
                        c = mix(c, mix(rgb(0xD9C6C8), rgb(0xF6E6D6), clamp01((y - 1300) / 300)), foam * 0.9)
                    }
                }
                let i = (row * W + col) * 3
                ref[i] = c.x; ref[i + 1] = c.y; ref[i + 2] = c.z
                reg[row * W + col] = region.rawValue
            }
        }
    }
}
print("reference painted")

// MARK: - Blurs and sampling

/// Three box blurs (close to a Gaussian of sigma ≈ radius), each horizontal then vertical.
func blurred(_ source: [Float], channels: Int, radius: Int) -> [Float] {
    guard radius > 0 else { return source }
    var a = source, b = source
    for _ in 0..<3 {
        a.withUnsafeBufferPointer { src in b.withUnsafeMutableBufferPointer { dst in
            parallelRows { y in
                for ch in 0..<channels {
                    var sum: Float = 0
                    for k in -radius...radius { sum += src[(y * W + min(max(k, 0), W - 1)) * channels + ch] }
                    for x in 0..<W {
                        dst[(y * W + x) * channels + ch] = sum / Float(2 * radius + 1)
                        sum += src[(y * W + min(x + radius + 1, W - 1)) * channels + ch]
                        sum -= src[(y * W + max(x - radius, 0)) * channels + ch]
                    }
                }
            }
        } }
        b.withUnsafeBufferPointer { src in a.withUnsafeMutableBufferPointer { dst in
            DispatchQueue.concurrentPerform(iterations: W) { x in
                for ch in 0..<channels {
                    var sum: Float = 0
                    for k in -radius...radius { sum += src[(min(max(k, 0), H - 1) * W + x) * channels + ch] }
                    for y in 0..<H {
                        dst[(y * W + x) * channels + ch] = sum / Float(2 * radius + 1)
                        sum += src[(min(y + radius + 1, H - 1) * W + x) * channels + ch]
                        sum -= src[(max(y - radius, 0) * W + x) * channels + ch]
                    }
                }
            }
        } }
    }
    return a
}
struct Field {
    let pixels: [Float]
    func color(_ p: P) -> RGB {
        let x = min(max(Int(p.x), 0), W - 1), y = min(max(Int(p.y), 0), H - 1), i = (y * W + x) * 3
        return RGB(pixels[i], pixels[i + 1], pixels[i + 2])
    }
    func luminance(_ x: Int, _ y: Int) -> Float {
        let i = (min(max(y, 0), H - 1) * W + min(max(x, 0), W - 1)) * 3
        return 0.3 * pixels[i] + 0.59 * pixels[i + 1] + 0.11 * pixels[i + 2]
    }
    func gradient(_ p: P) -> P {
        let x = Int(p.x), y = Int(p.y)
        let gx = luminance(x + 1, y - 1) + 2 * luminance(x + 1, y) + luminance(x + 1, y + 1)
            - luminance(x - 1, y - 1) - 2 * luminance(x - 1, y) - luminance(x - 1, y + 1)
        let gy = luminance(x - 1, y + 1) + 2 * luminance(x, y + 1) + luminance(x + 1, y + 1)
            - luminance(x - 1, y - 1) - 2 * luminance(x, y - 1) - luminance(x + 1, y - 1)
        return P(gx, gy) / 8
    }
}
func region(_ p: P) -> Region {
    Region(rawValue: regions[min(max(Int(p.y), 0), H - 1) * W + min(max(Int(p.x), 0), W - 1)])!
}
/// Stroke direction: along the contours of the light where they're strong, otherwise a gentle per-region flow
/// (swirling sky, flat water, diagonal hatching on land).
func direction(_ p: P, _ field: Field) -> P {
    let r = region(p)
    let base: Float
    let weight: (Float) -> Float
    switch r {
    case .sky: base = (fbm(p.x / 500, p.y / 300, 31, 3) - 0.5) * 1.4; weight = { smoothstep(0.02, 0.10, $0) * 0.85 }
    case .sea: base = (fbm(p.x / 400, p.y / 100, 33, 3) - 0.5) * 0.3; weight = { smoothstep(0.03, 0.15, $0) * 0.25 }
    case .headland: base = 1.1 + (fbm(p.x / 200, p.y / 200, 35, 3) - 0.5) * 0.8; weight = { smoothstep(0.01, 0.06, $0) }
    case .rock: base = 0.6 + (fbm(p.x / 150, p.y / 150, 37, 3) - 0.5) * 1.2; weight = { smoothstep(0.01, 0.06, $0) }
    }
    var flow = P(cosf(base), sinf(base))
    let g = field.gradient(p), m = simd_length(g)
    if m > 1e-4 {
        var along = P(-g.y, g.x) / m
        if simd_dot(along, flow) < 0 { along = -along }
        flow = simd_normalize(flow * (1 - weight(m)) + along * weight(m))
    }
    return flow
}

// MARK: - Contexts

func rgbaContext() -> CGContext {
    let c = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: Hf.cg); c.scaleBy(x: 1, y: -1)
    c.setLineCap(.round); c.setLineJoin(.round)
    return c
}
extension Float { var cg: CGFloat { CGFloat(self) } }
let heightContext: CGContext = {
    let c = CGContext(data: nil, width: W, height: H, bitsPerComponent: 32, bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue | CGBitmapInfo.floatComponents.rawValue
                          | CGBitmapInfo.byteOrder32Little.rawValue)!
    c.setFillColor(gray: 0.4, alpha: 1); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
    c.translateBy(x: 0, y: Hf.cg); c.scaleBy(x: 1, y: -1)
    c.setLineCap(.round); c.setLineJoin(.round)
    return c
}()
func write(_ image: CGImage, _ name: String) throws {
    let url = images.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
/// An image from per-pixel RGBA floats (straight alpha).
func image(_ pixel: (Int, Int) -> SIMD4<Float>) -> CGImage {
    var bytes = [UInt8](repeating: 0, count: W * H * 4)
    bytes.withUnsafeMutableBufferPointer { out in
        parallelRows { y in
            for x in 0..<W {
                let p = pixel(x, y), a = clamp01(p.w), i = (y * W + x) * 4
                out[i] = UInt8(clamp01(p.x) * a * 255 + 0.5); out[i + 1] = UInt8(clamp01(p.y) * a * 255 + 0.5)
                out[i + 2] = UInt8(clamp01(p.z) * a * 255 + 0.5); out[i + 3] = UInt8(a * 255 + 0.5)
            }
        }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4, space: srgb,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                   decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

// MARK: - Brush strokes

func path(_ points: [P]) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].x.cg, y: points[0].y.cg))
    if points.count == 2 { path.addLine(to: CGPoint(x: points[1].x.cg, y: points[1].y.cg)); return path }
    for i in 1..<points.count - 1 {
        let mid = (points[i] + points[i + 1]) / 2
        path.addQuadCurve(to: CGPoint(x: mid.x.cg, y: mid.y.cg), control: CGPoint(x: points[i].x.cg, y: points[i].y.cg))
    }
    path.addLine(to: CGPoint(x: points[points.count - 1].x.cg, y: points[points.count - 1].y.cg))
    return path
}
func stroke(_ context: CGContext, _ points: [P], width: Float, color: RGB, alpha: Float) {
    context.setStrokeColor(red: clamp01(color.x).cg, green: clamp01(color.y).cg, blue: clamp01(color.z).cg, alpha: alpha.cg)
    context.setLineWidth(width.cg)
    context.addPath(path(points)); context.strokePath()
}
func heightStroke(_ points: [P], width: Float, level: Float, alpha: Float = 1) {
    heightContext.setStrokeColor(gray: level.cg, alpha: alpha.cg)
    heightContext.setLineWidth(width.cg)
    heightContext.addPath(path(points)); heightContext.strokePath()
}
func heightDab(_ p: P, radius: Float, level: Float, alpha: Float) {
    heightContext.setFillColor(gray: level.cg, alpha: alpha.cg)
    heightContext.fillEllipse(in: CGRect(x: (p.x - radius).cg, y: (p.y - radius).cg, width: (2 * radius).cg, height: (2 * radius).cg))
}
/// A loaded brush: a body of paint, bristle streaks of slightly varied color across it, raised edges and a ridge of
/// paint where the brush lifts off.
func brush(_ context: CGContext, _ points: [P], radius R: Float, color c: RGB) {
    var points = points
    if points.count == 1 { points.append(points[0] + P(R * 0.3, 0)) }
    stroke(context, points, width: 2 * R * 0.9, color: c, alpha: 0.92)
    heightStroke(points, width: 2 * R * 0.95, level: 0.54)
    heightStroke(points, width: 2 * R * 0.8, level: 0.47)
    let count = max(3, min(16, Int(R * 0.9)))
    let width = 2 * R / Float(count) * 1.25
    let normals = points.indices.map { k -> P in
        let t = points[min(k + 1, points.count - 1)] - points[max(k - 1, 0)]
        let l = max(simd_length(t), 1e-5)
        return P(-t.y, t.x) / l
    }
    for i in 0..<count {
        let offset = ((Float(i) + 0.5) / Float(count) - 0.5) * 2 * R * 0.85
        var line = points.indices.map { points[$0] + normals[$0] * offset }
        line[0] += (line[1] - line[0]) * rand(0, 0.6)
        let last = line.count - 1
        line[last] += (line[last - 1] - line[last]) * rand(0, 0.6)
        let shade = 1 + rand(-0.09, 0.09)
        stroke(context, line, width: width, color: c * shade + RGB(rand(-0.015, 0.015), rand(-0.015, 0.015), rand(-0.015, 0.015)),
               alpha: 0.55)
        heightStroke(line, width: width * 0.7, level: 0.45 + rand(-0.18, 0.25))
    }
    heightDab(points[points.count - 1], radius: R * 0.45, level: 0.66, alpha: 0.4)
}

struct Pass { let name: String; let radius: Float; let spacing: Float; let length: ClosedRange<Float>; let tolerance: Float
              let blur: Int; let keep: (P, Field, Field) -> Bool }
let passes: [Pass] = [
    Pass(name: "Block-in", radius: 30, spacing: 22, length: 2...5, tolerance: 0.22, blur: 16, keep: { _, _, _ in true }),
    Pass(name: "Body strokes", radius: 15, spacing: 11, length: 2...6, tolerance: 0.14, blur: 8, keep: { p, field, coarse in
        simd_reduce_add(simd_abs(field.color(p) - coarse.color(p))) > 0.05 || rand(0, 1) < 0.4 }),
    Pass(name: "Detail strokes", radius: 7, spacing: 5.5, length: 1.5...5, tolerance: 0.10, blur: 4, keep: { p, field, coarse in
        simd_reduce_add(simd_abs(field.color(p) - coarse.color(p))) > 0.06 || rand(0, 1) < 0.06 }),
    Pass(name: "Accents", radius: 3.2, spacing: 3, length: 1...4, tolerance: 0.08, blur: 2, keep: { p, field, coarse in
        let c = field.color(p)
        return simd_reduce_add(simd_abs(c - coarse.color(p))) > 0.07 || (simd_reduce_add(c) > 2.45 && rand(0, 1) < 0.35) }),
]

func trace(from start: P, _ field: Field, radius R: Float, length: Float, tolerance: Float, color: RGB, sign: Float) -> [P] {
    var points: [P] = [], p = start, travelled: Float = 0
    var heading = direction(start, field) * sign
    let step = max(1.5, R * 0.5)
    while travelled < length {
        var next = direction(p, field)
        if simd_dot(next, heading) < 0 { next = -next }
        heading = simd_normalize(heading * 0.6 + next * 0.4)
        let q = p + heading * step
        if q.x < -R || q.y < -R || q.x > Wf + R || q.y > Hf + R { break }
        if travelled > R, simd_length(field.color(q) - color) > tolerance { break }
        points.append(q); p = q; travelled += step
    }
    return points
}

var strokeLayers: [(name: String, id: UUID)] = []
var coarse = Field(pixels: blurred(reference, channels: 3, radius: 24))
for pass in passes {
    let field = Field(pixels: blurred(reference, channels: 3, radius: pass.blur))
    var starts: [P] = []
    var y = pass.spacing / 2
    while y < Hf {
        var x = pass.spacing / 2
        while x < Wf {
            let p = P(x + rand(-0.5, 0.5) * pass.spacing, y + rand(-0.5, 0.5) * pass.spacing)
            if pass.keep(p, field, coarse) { starts.append(p) }
            x += pass.spacing
        }
        y += pass.spacing
    }
    starts.shuffle(using: &rng)
    let context = rgbaContext()
    for start in starts {
        var color = field.color(start)
        color *= 1 + rand(-0.05, 0.05)
        color += RGB(1, 0, -1) * rand(-0.02, 0.02)
        // Broken color: a few strokes drift off the local hue, less so in the darks and the small strokes.
        let spread = 0.06 * (0.3 + simd_reduce_add(color) / 3)
        if pass.radius >= 7, rand(0, 1) < 0.12 { color += RGB(rand(-spread, spread), rand(-spread, spread), rand(-spread, spread)) }
        let length = pass.radius * rand(pass.length.lowerBound, pass.length.upperBound)
        let back = trace(from: start, field, radius: pass.radius, length: length / 2, tolerance: pass.tolerance, color: color, sign: -1)
        let forward = trace(from: start, field, radius: pass.radius, length: length / 2, tolerance: pass.tolerance, color: color, sign: 1)
        brush(context, back.reversed() + [start] + forward, radius: pass.radius * rand(0.85, 1.1), color: color)
    }
    if pass.name == "Accents" {
        // A few gulls over the water.
        for (center, size) in [(P(760, 380), Float(16)), (P(840, 350), 12), (P(930, 410), 14), (P(1020, 330), 10), (P(1105, 372), 9)] {
            let wing = size * rand(0.9, 1.1)
            let left = [center + P(-wing, -wing * 0.35), center + P(-wing * 0.45, -wing * 0.55), center]
            let right = [center, center + P(wing * 0.45, -wing * 0.6), center + P(wing, -wing * 0.25)]
            for line in [left, right] {
                stroke(context, line, width: 2.6, color: rgb(0x2A2233), alpha: 0.9)
                heightStroke(line, width: 2.2, level: 0.75)
            }
        }
    }
    let id = UUID()
    try write(context.makeImage()!, id.uuidString + ".png")
    strokeLayers.append((pass.name, id))
    coarse = field
    print("\(pass.name): \(starts.count) strokes")
}

// MARK: - Ground, canvas and relief

let ground = UUID(), weave = UUID(), relief = UUID(), sheen = UUID(), glow = UUID()
// The glow of the sun and its path on the water: the reference's highlights, spread wide.
let highlights = reference.indices.map { i -> Float in
    let p = i - i % 3
    return reference[i] * smoothstep(0.62, 0.95, 0.3 * reference[p] + 0.59 * reference[p + 1] + 0.11 * reference[p + 2])
}
let bloom = Field(pixels: blurred(highlights, channels: 3, radius: 30))
try write(image { x, y in
    let c = bloom.color(P(Float(x), Float(y)))
    let a = clamp01(max(c.x, max(c.y, c.z)))
    return a > 0 ? SIMD4(c.x / a, c.y / a, c.z / a, a) : .zero
}, glow.uuidString + ".png")
try write(image { x, y in
    let n = fbm(Float(x) / 180, Float(y) / 180, 51)
    let c = mix(rgb(0x9C5A31), rgb(0xC07A43), n) * (0.92 + 0.16 * noise(Float(x) / 9, Float(y) / 9, 52))
    return SIMD4(c.x, c.y, c.z, 1)
}, ground.uuidString + ".png")

try write(image { x, y in
    let period: Float = 7
    let fx = Float(x), fy = Float(y)
    let over = sinf(.pi * fx / period) * sinf(.pi * fy / period) > 0
    let thread = over ? sinf(2 * .pi * fy / period) : sinf(2 * .pi * fx / period)
    let v = 0.5 + 0.1 * thread + 0.06 * (noise(fx / 3, fy / 3, 61) - 0.5) + 0.05 * (fbm(fx / 120, fy / 120, 62, 3) - 0.5)
    return SIMD4(v, v, v, 1)
}, weave.uuidString + ".png")

let heights: [Float] = {
    let data = heightContext.data!.assumingMemoryBound(to: Float.self)
    return blurred(Array(UnsafeBufferPointer(start: data, count: W * H)), channels: 1, radius: 1)
}()
let light = simd_normalize(SIMD3<Float>(-0.45, -0.55, 0.70))   // from the upper left
let halfway = simd_normalize(light + SIMD3<Float>(0, 0, 1))
func normal(_ x: Int, _ y: Int) -> SIMD3<Float> {
    let h: (Int, Int) -> Float = { heights[min(max($1, 0), H - 1) * W + min(max($0, 0), W - 1)] }
    let depth: Float = 5
    return simd_normalize(SIMD3(-(h(x + 1, y) - h(x - 1, y)) * depth, -(h(x, y + 1) - h(x, y - 1)) * depth, 1))
}
// Paint lies thick in the lights and thin in the darks, so the relief follows the reference's brightness.
let thickness = Field(pixels: blurred(reference, channels: 3, radius: 12))
try write(image { x, y in
    let lum = thickness.luminance(x, y)
    let v = 0.5 + (simd_dot(normal(x, y), light) - light.z) * 1.1 * (0.25 + 0.75 * lum)
    return SIMD4(v, v, v, 1)
}, relief.uuidString + ".png")
try write(image { x, y in
    let s = powf(max(0, simd_dot(normal(x, y), halfway)), 60)
    return SIMD4(1, 0.97, 0.9, s * smoothstep(0.25, 0.8, thickness.luminance(x, y)))
}, sheen.uuidString + ".png")

// MARK: - Manifest

func transform() -> [String: Any] {
    ["origin": [0, 0], "size": [W, H], "rotation": 0, "flipX": false, "flipY": false, "sampling": "High quality"]
}
func layer(_ id: UUID, _ name: String, image: Bool = true, _ extra: [String: Any] = [:]) -> [String: Any] {
    var record: [String: Any] = ["id": id.uuidString, "name": name, "isVisible": true, "isGroup": false, "opacity": 1,
                                 "blendMode": "Normal", "transform": transform()]
    if image { record["imageFile"] = id.uuidString + ".png" }
    return record.merging(extra) { $1 }
}
let paint = UUID(), surface = UUID(), varnish = UUID()
let identity = ["black": 0, "gamma": 1, "white": 255, "outputBlack": 0, "outputWhite": 255]
let curves: [String: Any] = [
    "kind": "Curves", "hue": 0, "saturation": 0, "lightness": 0, "colorize": false,
    "levels": ["channel": "RGB", "ranges": Array(repeating: identity, count: 4)],
    "curves": ["channel": "RGB", "channels": [
        [["x": 0, "y": 6], ["x": 64, "y": 58], ["x": 192, "y": 200], ["x": 255, "y": 250]],
        [["x": 0, "y": 0], ["x": 128, "y": 136], ["x": 255, "y": 255]],
        [["x": 0, "y": 0], ["x": 128, "y": 130], ["x": 255, "y": 255]],
        [["x": 0, "y": 8], ["x": 128, "y": 118], ["x": 255, "y": 238]]]],
]
var layers: [[String: Any]] = [layer(ground, "Toned ground"), layer(paint, "Paint", image: false, ["isGroup": true])]
layers += strokeLayers.map { layer($0.id, $0.name, ["parentID": paint.uuidString]) }
layers += [
    layer(surface, "Surface", image: false, ["isGroup": true]),
    layer(weave, "Canvas weave", ["parentID": surface.uuidString, "blendMode": "Overlay", "opacity": 0.22]),
    layer(relief, "Impasto relief", ["parentID": surface.uuidString, "blendMode": "Overlay", "opacity": 0.55]),
    layer(sheen, "Varnish sheen", ["parentID": surface.uuidString, "blendMode": "Screen", "opacity": 0.35]),
    layer(glow, "Sun glow", ["blendMode": "Screen", "opacity": 0.55]),
    layer(varnish, "Warm varnish", image: false, ["adjustment": curves, "opacity": 0.85]),
]
let manifest: [String: Any] = [
    "format": "com.itsjavi.lamina.project", "version": 11, "colorSpace": "sRGB", "resolution": 150,
    "documentID": UUID().uuidString, "width": W, "height": H, "activeLayerID": varnish.uuidString,
    "layers": layers,
]
let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: package.appendingPathComponent("manifest.json"))
print(package.path)
