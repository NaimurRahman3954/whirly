import SwiftUI

/// Draws one frame. Coordinates are world pixels; `s` maps them to points, snapped to device pixels so edges stay crisp.
struct Renderer {
    let game: Game
    let ctx: GraphicsContext
    let s: CGFloat          // points per world pixel
    let k: CGFloat          // device pixels per point

    private func snap(_ v: CGFloat) -> CGFloat { (v * s * k).rounded() / k }

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
        let x0 = snap(x), y0 = snap(y)
        ctx.fill(Path(CGRect(x: x0, y: y0, width: snap(x + w) - x0, height: snap(y + h) - y0)), with: .color(c))
    }

    /// Draws a sprite with its top-left at (x, y). `pw`/`ph` are the size of one sprite pixel, so a sprite can be scaled or squashed.
    func sprite(_ rows: [String], _ x: CGFloat, _ y: CGFloat, flip: Bool = false, flipV: Bool = false,
                opacity: Double = 1, pw: CGFloat = 1, ph: CGFloat = 1, tint: Color? = nil) {
        for (r, row) in rows.enumerated() {
            let chars = Array(row)
            var c = 0
            while c < chars.count {
                let ch = chars[c]
                guard let col = Palette.colors[ch] else { c += 1; continue }
                var e = c + 1
                while e < chars.count && chars[e] == ch { e += 1 }
                let rx = flip ? CGFloat(chars.count - e) : CGFloat(c)
                let ry = flipV ? CGFloat(rows.count - 1 - r) : CGFloat(r)
                rect(x + rx * pw, y + ry * ph, CGFloat(e - c) * pw, ph, (tint ?? col).opacity(opacity))
                c = e
            }
        }
    }

    /// Size 1 is drawn bold (each column doubled), like the chunky score in the original; size 2 is already heavy.
    func text(_ str: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 1, color: Color = Palette.ink) {
        let bold = size == 1
        var cx = x
        for ch in str {
            if let g = Font5x7.glyphs[ch] {
                for (r, row) in g.enumerated() {
                    for (c, p) in row.enumerated() where p == "#" {
                        rect(cx + CGFloat(c) * size, y + CGFloat(r) * size, size * (bold ? 2 : 1), size, color)
                    }
                }
            }
            cx += Font5x7.advance(size)
        }
    }

    /// Text with a 1 px halo in the background colour, so it stays readable over platforms.
    func haloText(_ str: String, _ x: CGFloat, _ y: CGFloat) {
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] as [(CGFloat, CGFloat)] { text(str, x + dx, y + dy, color: Palette.bg) }
        text(str, x, y)
    }

    func centered(_ str: String, _ y: CGFloat, size: CGFloat = 1, color: Color = Palette.ink) {
        text(str, ((World.width - Font5x7.width(str, size: size)) / 2).rounded(), y, size: size, color: color)
    }

    /// A menu card with a soft drop shadow and a 2 px ink border.
    func card(_ y: CGFloat, _ h: CGFloat) {
        rect(11, y + 4, World.width - 16, h, Palette.shadow)
        rect(8, y, World.width - 16, h, Palette.ink)
        rect(10, y + 2, World.width - 20, h - 4, Palette.bg)
        rect(10, y + 2, World.width - 20, 2, .white)
    }

    // MARK: frame

    func draw() {
        let g = game, cam = g.camY
        rect(0, 0, World.width, g.viewH + 2, Palette.bg)
        clouds()

        for p in g.plats { platform(p, p.y - cam) }
        for m in g.monsters {
            let rows = (g.frame / 10) % 2 == 0 ? Sprites.monsterA : Sprites.monsterB
            sprite(rows, m.x, m.y - cam, flipV: m.dead > 0, opacity: m.dead > 0 ? 0.6 : 1)
        }
        for p in g.particles {
            let a = min(1, Double(p.life) / Double(p.total) * 1.5)
            if let c = Palette.colors[p.color] { rect(p.x.rounded(), (p.y - cam).rounded(), p.size, p.size, c.opacity(a)) }
        }
        bird(cam)

        if g.phase != .title { haloText("\(g.score) HI:\(max(g.best, g.score))", 6, g.topInset + 4) }
        if g.phase == .playing {
            rect(World.width - 15, g.topInset + 4, 3, 8, Palette.ink.opacity(0.5))
            rect(World.width - 10, g.topInset + 4, 3, 8, Palette.ink.opacity(0.5))
        }
        overlay()
    }

    /// Soft clouds that drift and scroll at a third of the camera speed, for depth.
    private func clouds() {
        let g = game
        let band: CGFloat = 70
        let off = g.camY * 0.35
        let first = Int(floor((off - 20) / band)), last = Int(ceil((off + g.viewH) / band))
        guard first <= last else { return }
        for i in first...last {
            var h = UInt64(bitPattern: Int64(i)) &* 0x9E3779B97F4A7C15
            h ^= h >> 29
            let r1 = CGFloat(h & 0xFFFF) / 65535, r2 = CGFloat((h >> 16) & 0xFFFF) / 65535
            let c = Sprites.clouds[Int((h >> 32) % 2)]
            let w = CGFloat(c[0].count)
            let span = World.width + w + 20
            var x = (r1 * span + CGFloat(g.frame) * (0.03 + r2 * 0.05)).truncatingRemainder(dividingBy: span) - w - 10
            if x < -w - 10 { x += span }
            sprite(c, x.rounded(), (CGFloat(i) * band + r2 * 30 - off).rounded())
        }
    }

    private func platform(_ p: Platform, _ y: CGFloat) {
        switch p.kind {
        case .normal: sprite(Sprites.plat, p.x, y)
        case .moving: sprite(Sprites.platMoving, p.x.rounded(), y)
        case .vanish: sprite(Sprites.platVanish, p.x, y, opacity: p.gone == 0 ? 1 : max(0, 1 - Double(p.gone) / 12))
        case .breakable:
            if p.gone == 0 {
                sprite(Sprites.platBreak, p.x, y)
            } else {
                let t = CGFloat(p.gone), dy = t * t * 0.08 + t * 0.4
                let fade = max(0, 1 - Double(p.gone) / 40)
                sprite(Sprites.platBreakLeft, (p.x - t * 0.3).rounded(), (y + dy).rounded(), opacity: fade)
                sprite(Sprites.platBreakRight, (p.x + 11 + t * 0.3).rounded(), (y + dy * 1.1).rounded(), opacity: fade)
            }
        }
        let ex = (p.x + p.extraX).rounded()
        switch p.extra {
        case .spring:
            let sp = p.springOut > 0 ? Sprites.springOut : Sprites.spring
            sprite(sp, ex, y - CGFloat(sp.count))
        case .propeller:
            let bob: CGFloat = (game.frame / 20) % 2 == 0 ? 0 : -1
            sprite(Sprites.hatFrames[(game.frame / 5) % 4], ex, y - 6 + bob)
        case .none: break
        }
    }

    private func bird(_ cam: CGFloat) {
        let g = game
        let dead = g.phase == .dying
        // landing squash: wider and shorter for a few frames, anchored at the feet
        let sq = CGFloat(g.squash) / 6
        let pw = 1 + 0.18 * sq, ph = 1 - 0.22 * sq
        let w = Sprites.birdW * pw, h = 12 * ph
        let x = g.px - w / 2, y = g.py - cam - h
        let flip = g.facing < 0

        let wing: ([String], CGPoint)
        if g.flying > 0 { wing = (g.frame / 3) % 2 == 0 ? Sprites.wingUp : Sprites.wingDown }
        else if g.vy < -2.5 { wing = Sprites.wingDown }
        else if g.vy > 1 { wing = Sprites.wingUp }
        else { wing = Sprites.wingMid }

        var offsets: [CGFloat] = [0]
        if x < 0 { offsets.append(World.width) }
        if x + w > World.width { offsets.append(-World.width) }
        for o in offsets {
            let bx = x + o
            sprite(dead ? Sprites.birdDead : Sprites.bird, bx, y, flip: flip, flipV: dead, pw: pw, ph: ph)
            if !dead {
                let wx = flip ? Sprites.birdW - wing.1.x - 5 : wing.1.x
                sprite(wing.0, bx + wx * pw, y + wing.1.y * ph, flip: flip, pw: pw, ph: ph)
            }
            if g.flying > 0 {
                sprite(Sprites.hatFrames[(g.frame / 2) % 4], bx + (flip ? 3 : 0), y - 5)
            }
        }
    }

    private func overlay() {
        let g = game, h = g.viewH
        switch g.phase {
        case .title:
            let y = (h * 0.16).rounded()
            card(y, 116)
            centered("WHIRLY", y + 10, size: 2)
            // the hero: a big bird in a spinning hat
            let bob: CGFloat = (g.frame / 20) % 2 == 0 ? 0 : -1
            let bx = (World.width - 28) / 2
            sprite(Sprites.hatFrames[(g.frame / 4) % 4], bx + 1, y + 32 + bob, pw: 2, ph: 2)
            sprite(Sprites.bird, bx, y + 42 + bob, pw: 2, ph: 2)
            let wing = (g.frame / 8) % 2 == 0 ? Sprites.wingUp : Sprites.wingDown
            sprite(wing.0, bx + wing.1.x * 2, y + 42 + bob + wing.1.y * 2, pw: 2, ph: 2)
            if g.frame / 30 % 2 == 0 { centered("TAP TO PLAY", y + 74) }
            centered("TILT OR TOUCH", y + 88, color: Palette.light)
            if g.best > 0 { centered("BEST \(g.best)", y + 100, color: Palette.light) }
            centered(Sound.shared.on ? "SOUND ON" : "SOUND OFF", h - 24, color: Palette.light)
        case .paused:
            let y = (h * 0.3).rounded()
            card(y, 42)
            centered("PAUSED", y + 10)
            centered("TAP TO GO ON", y + 24, color: Palette.light)
        case .over:
            let y = (h * 0.28).rounded()
            card(y, 74)
            centered("GAME OVER", y + 10, size: 2)
            centered("SCORE \(g.score)", y + 32)
            if g.newBest {
                if g.frame / 15 % 2 == 0 { centered("NEW BEST!", y + 44, color: Palette.colors["r"]!) }
            } else {
                centered("BEST \(g.best)", y + 44, color: Palette.light)
            }
            if g.phaseFrame > 30 { centered("TAP TO PLAY AGAIN", y + 58, color: Palette.light) }
        case .playing, .dying:
            break
        }
    }
}
