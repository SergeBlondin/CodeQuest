import SwiftUI

extension Font {
    static func pixel(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .monospaced) }
}

enum Pal {
    static let ink = Color(red: 0.09, green: 0.08, blue: 0.16)
    static let panel = Color(red: 0.99, green: 0.95, blue: 0.85)
    static let sky1 = Color(red: 0.36, green: 0.62, blue: 0.96)
    static let sky2 = Color(red: 0.62, green: 0.84, blue: 1.0)
    static let grass = Color(red: 0.38, green: 0.78, blue: 0.3)
    static let grassDark = Color(red: 0.22, green: 0.55, blue: 0.2)
    static let dirt = Color(red: 0.6, green: 0.38, blue: 0.2)
    static let dirtDark = Color(red: 0.42, green: 0.25, blue: 0.13)
    static let stone = Color(red: 0.55, green: 0.56, blue: 0.62)
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.15)
    static let red = Color(red: 0.92, green: 0.22, blue: 0.27)
    static let code = Color(red: 0.12, green: 0.12, blue: 0.2)
}

let palette: [Character: Color] = [
    "K": Pal.ink, "S": Color(red: 1.0, green: 0.8, blue: 0.62), "H": Color(red: 0.45, green: 0.25, blue: 0.1),
    "E": Pal.ink, "R": Pal.red, "B": Color(red: 0.55, green: 0.33, blue: 0.15), "U": Color(red: 0.2, green: 0.3, blue: 0.7),
    "Y": Pal.gold, "O": Color(red: 0.85, green: 0.55, blue: 0.05), "W": .white, "G": Pal.grass, "D": Pal.dirt,
    "L": Color(red: 0.6, green: 0.4, blue: 0.9), "N": Color(red: 0.75, green: 0.55, blue: 0.25),
]

enum Sprites {
    static let hero = [
        "..HHHH..",
        ".HHHHHH.",
        ".HSSSSH.",
        "..SESE..",
        "..SSSS..",
        "BBRRRRS.",
        "BBRRRR..",
        "BBUUUU..",
        "..U..U..",
        ".KK..KK.",
    ]
    static let coin = [
        "..YYYY..",
        ".YYWYYO.",
        "YYWYYYYO",
        "YYWYYYYO",
        "YYYYYYYO",
        "YYYYYYOO",
        ".YOOOOO.",
        "..OOOO..",
    ]
    static let heart = [
        ".RR.RR.",
        "RWRRRRR",
        "RRRRRRR",
        ".RRRRR.",
        "..RRR..",
        "...R...",
    ]
    static let chest = [
        ".KKKKKKKK.",
        "KNNNNNNNNK",
        "KBBBBBBBBK",
        "KKKKYYKKKK",
        "KNNNYYNNNK",
        "KBBBBBBBBK",
        "KBBBBBBBBK",
        ".KKKKKKKK.",
    ]
    static let chestOpen = [
        "KKKKKKKKKK",
        "KNNNNNNNNK",
        "KKKKKKKKKK",
        "KYYWYYYYYK",
        "KNNNYYNNNK",
        "KBBBBBBBBK",
        "KBBBBBBBBK",
        ".KKKKKKKK.",
    ]
    static let flag = [
        "KRRRR.",
        "KRRRRR",
        "KRRRR.",
        "K.....",
        "K.....",
        "K.....",
        "K.....",
        "KK....",
    ]
}

func drawSprite(_ ctx: GraphicsContext, _ rows: [String], in rect: CGRect, flip: Bool = false) {
    let h = CGFloat(rows.count), w = CGFloat(rows.map { $0.count }.max() ?? 1)
    let px = min(rect.width / w, rect.height / h)
    let ox = rect.midX - px * w / 2, oy = rect.midY - px * h / 2
    for (y, row) in rows.enumerated() {
        for (x, c) in row.enumerated() {
            guard let col = palette[c] else { continue }
            let xx = flip ? (w - 1 - CGFloat(x)) : CGFloat(x)
            ctx.fill(Path(CGRect(x: (ox + xx * px).rounded(.down), y: (oy + CGFloat(y) * px).rounded(.down), width: px.rounded(.up) + 0.5, height: px.rounded(.up) + 0.5)), with: .color(col))
        }
    }
}

struct SpriteView: View {
    let rows: [String]
    var flip = false
    var body: some View {
        Canvas { ctx, size in drawSprite(ctx, rows, in: CGRect(origin: .zero, size: size), flip: flip) }
    }
}

struct PixelPanel: ViewModifier {
    var fill: Color = Pal.panel
    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().stroke(Pal.ink, lineWidth: 3))
            .background(Rectangle().fill(Pal.ink).offset(x: 4, y: 4))
    }
}
extension View { func pixelPanel(_ fill: Color = Pal.panel) -> some View { modifier(PixelPanel(fill: fill)) } }

struct PixelButton: View {
    let title: String
    var color: Color = Pal.grass
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.pixel(18)).foregroundStyle(.white)
                .shadow(color: Pal.ink, radius: 0, x: 2, y: 2)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .frame(minWidth: 90)
                .pixelPanel(color)
        }.buttonStyle(.plain)
    }
}

struct PixelBar: View {
    let value: Double
    var color: Color = Pal.gold
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Pal.ink.opacity(0.15))
                Rectangle().fill(color).frame(width: g.size.width * max(0, min(1, value)))
                HStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { _ in Rectangle().fill(.clear).frame(maxWidth: .infinity).overlay(alignment: .trailing) { Rectangle().fill(Pal.ink.opacity(0.12)).frame(width: 1) } }
                }
            }.overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
        }.frame(height: 14)
    }
}

/// Floating islands sky scene
struct SkyScene: View {
    var showHero = true
    var body: some View {
        Canvas { ctx, size in
            let px: CGFloat = 4
            func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
                ctx.fill(Path(CGRect(x: x * px, y: y * px, width: w * px, height: h * px)), with: .color(c))
            }
            let cols = size.width / px
            // clouds
            for (cx, cy) in [(8.0, 6.0), (cols - 30, 10.0), (cols / 2 - 6, 3.0)] {
                block(cx, cy, 14, 3, .white); block(cx + 3, cy - 2, 7, 2, .white); block(cx + 1, cy + 3, 12, 1, Color.white.opacity(0.7))
            }
            func island(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
                block(x, y, w, 2, Pal.grass); block(x, y + 2, w, 1, Pal.grassDark)
                block(x + 1, y + 3, w - 2, 3, Pal.dirt); block(x + 3, y + 6, w - 6, 2, Pal.dirtDark); block(x + w / 2 - 2, y + 8, 4, 2, Pal.dirtDark)
            }
            island(4, 30, 22); island(cols - 26, 22, 20); island(cols / 2 - 10, 36, 20)
            // tree
            block(cols - 18, 15, 2, 7, Pal.dirtDark); block(cols - 22, 10, 10, 6, Pal.grassDark); block(cols - 21, 8, 8, 3, Pal.grass)
            drawSprite(ctx, Sprites.coin, in: CGRect(x: 14 * px, y: 22 * px, width: 7 * px, height: 7 * px))
            drawSprite(ctx, Sprites.coin, in: CGRect(x: (cols - 12) * px, y: 14 * px, width: 6 * px, height: 6 * px))
            drawSprite(ctx, Sprites.chest, in: CGRect(x: (cols / 2 + 2) * px, y: 29 * px, width: 8 * px, height: 7 * px))
            if showHero { drawSprite(ctx, Sprites.hero, in: CGRect(x: (cols / 2 - 8) * px, y: 26 * px, width: 9 * px, height: 10 * px)) }
        }
        .background(LinearGradient(colors: [Pal.sky1, Pal.sky2], startPoint: .top, endPoint: .bottom))
    }
}

/// Tile grid for a level
struct GridView: View {
    let state: WorldState
    var body: some View {
        Canvas { ctx, size in
            let t = min(size.width / CGFloat(max(state.w, 1)), size.height / CGFloat(max(state.h, 1))).rounded(.down)
            let ox = (size.width - t * CGFloat(state.w)) / 2, oy = (size.height - t * CGFloat(state.h)) / 2
            for y in 0..<state.h {
                for x in 0..<state.w {
                    let p = Pt(x: x, y: y)
                    let r = CGRect(x: ox + CGFloat(x) * t, y: oy + CGFloat(y) * t, width: t, height: t)
                    if state.pits.contains(p) {
                        ctx.fill(Path(r.insetBy(dx: 0, dy: t * 0.35).offsetBy(dx: 0, dy: t * 0.35)), with: .color(Pal.ink.opacity(0.25)))
                        continue
                    }
                    if state.walls.contains(p) {
                        ctx.fill(Path(r), with: .color(Pal.stone))
                        ctx.fill(Path(CGRect(x: r.minX, y: r.minY, width: t, height: t * 0.12)), with: .color(.white.opacity(0.35)))
                        ctx.fill(Path(CGRect(x: r.minX, y: r.midY, width: t, height: 2)), with: .color(Pal.ink.opacity(0.3)))
                        ctx.fill(Path(CGRect(x: r.midX, y: r.minY, width: 2, height: t / 2)), with: .color(Pal.ink.opacity(0.3)))
                        ctx.stroke(Path(r), with: .color(Pal.ink), lineWidth: 2)
                        continue
                    }
                    ctx.fill(Path(r), with: .color(Pal.dirt))
                    ctx.fill(Path(CGRect(x: r.minX, y: r.minY, width: t, height: t * 0.3)), with: .color(Pal.grass))
                    ctx.fill(Path(CGRect(x: r.minX, y: r.minY + t * 0.3, width: t, height: t * 0.08)), with: .color(Pal.grassDark))
                    ctx.fill(Path(CGRect(x: r.minX + t * 0.2, y: r.minY + t * 0.6, width: t * 0.1, height: t * 0.1)), with: .color(Pal.dirtDark))
                    ctx.fill(Path(CGRect(x: r.minX + t * 0.65, y: r.minY + t * 0.75, width: t * 0.1, height: t * 0.1)), with: .color(Pal.dirtDark))
                    ctx.stroke(Path(r), with: .color(Pal.ink.opacity(0.5)), lineWidth: 1)
                    let inner = r.insetBy(dx: t * 0.18, dy: t * 0.18)
                    if state.goal == p { drawSprite(ctx, Sprites.flag, in: inner) }
                    if state.coins.contains(p) { drawSprite(ctx, Sprites.coin, in: r.insetBy(dx: t * 0.25, dy: t * 0.25)) }
                    if state.chest == p { drawSprite(ctx, state.chestOpen ? Sprites.chestOpen : Sprites.chest, in: inner) }
                }
            }
            // hero
            let hr = CGRect(x: ox + CGFloat(state.hero.x) * t, y: oy + CGFloat(state.hero.y) * t, width: t, height: t)
            if !state.fell {
                drawSprite(ctx, Sprites.hero, in: hr.insetBy(dx: t * 0.12, dy: t * 0.08), flip: state.dir == 2)
            }
            // direction arrow
            let c = CGPoint(x: hr.midX, y: hr.midY)
            let d: [CGPoint] = [CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: -1)]
            let v = d[state.dir]
            let tip = CGPoint(x: c.x + v.x * t * 0.48, y: c.y + v.y * t * 0.48)
            let base = CGPoint(x: c.x + v.x * t * 0.32, y: c.y + v.y * t * 0.32)
            var tri = Path()
            tri.move(to: tip)
            tri.addLine(to: CGPoint(x: base.x - v.y * t * 0.1, y: base.y + v.x * t * 0.1))
            tri.addLine(to: CGPoint(x: base.x + v.y * t * 0.1, y: base.y - v.x * t * 0.1))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(Pal.gold)); ctx.stroke(tri, with: .color(Pal.ink), lineWidth: 1.5)
        }
    }
}
