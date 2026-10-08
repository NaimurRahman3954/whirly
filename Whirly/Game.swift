import Foundation
import CoreGraphics

/// World units are logical pixels. The world is 144 px wide; y grows downward, so climbing means y goes negative.
enum World {
    static let width: CGFloat = 144
    static let gravity: CGFloat = 0.24
    static let jumpV: CGFloat = -6.0        // apex ≈ 75 px
    static let springV: CGFloat = -10.6     // apex ≈ 234 px
    static let flyV: CGFloat = -5.4
    static let flyFrames = 210              // 3.5 s of propeller
    static let maxFall: CGFloat = 7
    static let platW: CGFloat = 22
    static let maxGap: CGFloat = 60         // never wider than a plain jump can clear
}

enum PlatKind { case normal, moving, breakable, vanish }
enum Extra { case none, spring, propeller }

struct Platform {
    var x: CGFloat, y: CGFloat              // top-left; y is the surface you land on
    var kind: PlatKind
    var extra: Extra = .none
    var vx: CGFloat = 0
    var gone = 0                            // frames since it crumbled or vanished; 0 = solid
    var springOut = 0                       // frames the spring stays stretched after a launch
    var extraX: CGFloat = 0                 // where the spring or hat sits along the platform
}

struct Monster {
    var x: CGFloat, y: CGFloat              // top-left of a 16 × 12 sprite
    var baseX: CGFloat
    var t: Double = 0
    var dead = 0
}

/// A short-lived pixel for dust, debris and sparkles.
struct Particle {
    var x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat
    var life: Int, total: Int
    var color: Character
    var size: CGFloat = 1
    var gravity: CGFloat = 0
}

enum Phase: Equatable { case title, playing, paused, dying, over }
enum Event { case jump, spring, propeller, crack, stomp, die, fall, newBest }

final class Game: ObservableObject {
    @Published private(set) var frame = 0
    var phase: Phase = .title { didSet { phaseFrame = 0 } }
    private(set) var phaseFrame = 0

    /// Set by the view: the visible height in world pixels and the top safe-area inset.
    private(set) var viewH: CGFloat = 300
    private(set) var topInset: CGFloat = 16

    var px: CGFloat = 72, py: CGFloat = 0     // centre-x and feet of the bird
    var vx: CGFloat = 0, vy: CGFloat = 0
    var facing: CGFloat = 1
    var flying = 0
    var plats: [Platform] = []
    var monsters: [Monster] = []
    var particles: [Particle] = []
    private(set) var squash = 0               // frames of landing squash left
    var camY: CGFloat = 0                     // world y at the top of the screen
    private(set) var score = 0
    private(set) var best = UserDefaults.standard.integer(forKey: "best")
    private(set) var newBest = false

    var hold: CGFloat = 0                     // -1 / 0 / 1 from holding a side of the screen
    var tilt: CGFloat = 0                     // gravity.x from the motion sensor
    var onEvent: (Event) -> Void = { _ in }

    private var climbed: CGFloat = 0
    private var topY: CGFloat = 0             // the highest platform on the guaranteed path

    init() { reset() }

    func layout(viewH: CGFloat, topInset: CGFloat) {
        guard abs(viewH - self.viewH) > 0.5 || abs(topInset - self.topInset) > 0.5 else { return }
        self.viewH = viewH; self.topInset = topInset
        if phase == .title { reset() }
    }

    func reset() {
        plats = [Platform(x: (World.width - World.platW) / 2, y: 0, kind: .normal)]
        monsters = []; particles = []
        topY = 0
        px = World.width / 2; py = 0; vx = 0; vy = World.jumpV; flying = 0; facing = 1
        camY = -viewH * 0.86
        climbed = 0; score = 0; newBest = false
        fill()
    }

    // MARK: input

    func tap(x: CGFloat, y: CGFloat) {
        switch phase {
        case .title:
            if y > viewH - 36 { Sound.shared.on.toggle() } else { phase = .playing }
        case .playing:
            if x > World.width - 28 && y < topInset + 22 { phase = .paused }
        case .paused:
            phase = .playing
        case .over:
            if phaseFrame > 30 { reset(); phase = .playing }
        case .dying:
            break
        }
        objectWillChange.send()
    }

    /// The sound toggle and pause button sit under these taps, so they shouldn't also steer.
    func steers(x: CGFloat, y: CGFloat) -> Bool { !(x > World.width - 28 && y < topInset + 22) }

    // MARK: loop

    func step() {
        frame += 1; phaseFrame += 1
        if phase != .paused { tickParticles() }
        switch phase {
        case .title:
            physics(control: false)
        case .playing:
            physics(control: true)
            follow(); fill(); cull()
            if py - camY > viewH + 16 { onEvent(.fall); finish() }
        case .dying:
            vy = min(vy + World.gravity, World.maxFall); py += vy
            if py - camY > viewH + 30 { finish() }
        case .paused, .over:
            break
        }
    }

    private func physics(control: Bool) {
        for i in plats.indices {
            if plats[i].kind == .moving && plats[i].gone == 0 {
                plats[i].x += plats[i].vx
                let maxX = World.width - World.platW
                if plats[i].x < 0 || plats[i].x > maxX { plats[i].vx *= -1; plats[i].x = min(max(plats[i].x, 0), maxX) }
            }
            if plats[i].gone > 0 { plats[i].gone += 1 }
            if plats[i].springOut > 0 { plats[i].springOut -= 1 }
        }
        for i in monsters.indices {
            monsters[i].t += 1
            if monsters[i].dead > 0 { monsters[i].dead += 1; monsters[i].y += CGFloat(monsters[i].dead) * 0.3 }
            else { monsters[i].x = monsters[i].baseX + CGFloat(sin(monsters[i].t * 0.03)) * 14 }
        }

        // steering: holding a side wins over tilt
        var target: CGFloat = 0
        #if DEBUG
        if control && autopilot { hold = autoSteer() }
        #endif
        if control {
            if hold != 0 { target = hold * 2.7 }
            else if abs(tilt) > 0.03 { target = max(-3.2, min(3.2, tilt * 8)) }
        }
        vx += (target - vx) * 0.22
        if abs(vx) > 0.3 { facing = vx > 0 ? 1 : -1 }
        px += vx
        if px < 0 { px += World.width } else if px >= World.width { px -= World.width }

        let prev = py
        if flying > 0 {
            flying -= 1
            vy = flying > 30 ? World.flyV : World.flyV * CGFloat(flying) / 30
        } else {
            vy = min(vy + World.gravity, World.maxFall)
        }
        py += vy

        if vy > 0 && flying == 0 { land(from: prev) }
        pickups()
        if control { touchMonsters() }
    }

    private func land(from prev: CGFloat) {
        for i in plats.indices where plats[i].gone == 0 {
            let p = plats[i]
            guard abs(px - (p.x + World.platW / 2)) < World.platW / 2 + 4 else { continue }
            if p.extra == .spring {
                let top = p.y - 4
                if abs(px - (p.x + p.extraX + 4)) < 7, prev <= top, py >= top {
                    py = top; vy = World.springV; plats[i].springOut = 14; onEvent(.spring)
                    burst(px, top, n: 8, colors: ["s", "w", "S"], speed: 1.4, up: true)
                    return
                }
            }
            guard prev <= p.y, py >= p.y else { continue }
            if p.kind == .breakable {
                plats[i].gone = 1; onEvent(.crack)
                burst(p.x + World.platW / 2, p.y + 2, n: 8, colors: ["n", "D", "N"], speed: 1, gravity: 0.15, spread: 9)
                continue
            }
            py = p.y; vy = World.jumpV; squash = 6
            dust(px, p.y)
            if p.kind == .vanish { plats[i].gone = 1 }
            onEvent(.jump)
            return
        }
    }

    private func pickups() {
        guard flying == 0 else { return }
        for i in plats.indices where plats[i].extra == .propeller && plats[i].gone == 0 {
            let hx = plats[i].x + plats[i].extraX + 5, hy = plats[i].y - 4
            if abs(px - hx) < 9 && abs((py - 6) - hy) < 10 {
                plats[i].extra = .none; flying = World.flyFrames; onEvent(.propeller)
                burst(hx, hy, n: 12, colors: ["r", "y", "g", "b"], speed: 1.6)
                return
            }
        }
    }

    private func touchMonsters() {
        for i in monsters.indices where monsters[i].dead == 0 {
            let m = monsters[i]
            guard abs(px - (m.x + 8)) < 12, abs((py - 6) - (m.y + 6)) < 11 else { continue }
            if flying > 0 {
                monsters[i].dead = 1; onEvent(.stomp)
                burst(m.x + 8, m.y + 6, n: 8, colors: ["y", "w"], speed: 1.5)
            } else if vy > 0 && py < m.y + 7 {
                monsters[i].dead = 1; vy = World.jumpV * 1.1; onEvent(.stomp)
                burst(m.x + 8, m.y + 2, n: 8, colors: ["y", "w"], speed: 1.5)
            } else {
                phase = .dying; vy = -3; onEvent(.die); return
            }
        }
    }

    // MARK: particles

    private func tickParticles() {
        if squash > 0 { squash -= 1 }
        if flying > 0 && frame % 3 == 0 {
            particles.append(Particle(x: px + .random(in: -4...4), y: py, vx: .random(in: -0.3...0.3), vy: 1.2, life: 16, total: 16, color: "+"))
        }
        for i in particles.indices {
            particles[i].x += particles[i].vx; particles[i].y += particles[i].vy
            particles[i].vy += particles[i].gravity
            particles[i].vx *= 0.94
            particles[i].life -= 1
        }
        particles.removeAll { $0.life <= 0 }
    }

    private func dust(_ x: CGFloat, _ y: CGFloat) {
        for d: CGFloat in [-1, 1] {
            for k in 0..<2 {
                particles.append(Particle(x: x + d * CGFloat(3 + k * 2), y: y - 1, vx: d * CGFloat.random(in: 0.5...1.0), vy: -0.25,
                                          life: 14, total: 14, color: "+", size: k == 0 ? 2 : 1))
            }
        }
    }

    private func burst(_ x: CGFloat, _ y: CGFloat, n: Int, colors: [Character], speed: CGFloat,
                       gravity: CGFloat = 0.04, spread: CGFloat = 2, up: Bool = false) {
        for _ in 0..<n {
            let a = CGFloat.random(in: up ? (CGFloat.pi * 1.1)...(CGFloat.pi * 1.9) : 0...(2 * .pi))
            let v = speed * .random(in: 0.5...1.2)
            particles.append(Particle(x: x + .random(in: -spread...spread), y: y, vx: cos(a) * v, vy: sin(a) * v,
                                      life: .random(in: 18...30), total: 30, color: colors.randomElement()!,
                                      size: .random(in: 0...1) < 0.3 ? 2 : 1, gravity: gravity))
        }
    }

    private func follow() {
        let line = camY + viewH * 0.42
        if py < line { camY = py - viewH * 0.42 }
        climbed = max(climbed, -py)
        score = Int(climbed / 2)
    }

    private func finish() {
        if score > best { best = score; newBest = true; UserDefaults.standard.set(best, forKey: "best") }
        phase = .over
        if newBest { onEvent(.newBest) }
    }

    #if DEBUG
    /// Launch with -autopilot to let the bird climb on its own (for testing the higher levels).
    let autopilot = ProcessInfo.processInfo.arguments.contains("-autopilot")
    private func autoSteer() -> CGFloat {
        let solid = plats.filter { $0.gone == 0 && $0.kind != .breakable }
        let reach = vy < 0 ? vy * vy / (2 * World.gravity) : 0     // how much higher this jump still goes
        let pick = solid.filter { $0.y > py - reach + 4 && $0.y < py + 40 }.min { $0.y < $1.y }
        guard let p = pick else { return 0 }
        let dx = p.x + World.platW / 2 - px
        return abs(dx) < 3 ? 0 : (dx > 0 ? 1 : -1)
    }
    #endif

    // MARK: level generation

    /// Lays platforms upward until the screen is covered. Every gap on the main path is jumpable;
    /// crumbling platforms are extras placed between steps, never part of the path.
    private func fill() {
        while topY > camY - 60 {
            let h = -topY
            let d = min(1, h / 16000)
            let gap = CGFloat.random(in: (16 + 18 * d)...min(World.maxGap, 28 + 32 * d))
            topY -= gap

            var p = Platform(x: .random(in: 0...(World.width - World.platW)), y: topY, kind: .normal)
            let r = CGFloat.random(in: 0..<1)
            if h > 500 && r < 0.06 + 0.30 * d {
                p.kind = .moving; p.vx = (Bool.random() ? 1 : -1) * (0.45 + 0.8 * d)
            } else if h > 900 && r < 0.14 + 0.38 * d {
                p.kind = .vanish
            }
            if p.kind != .vanish {
                let e = CGFloat.random(in: 0..<1)
                if h > 300 && e < 0.07 { p.extra = .spring; p.extraX = .random(in: 2...12) }
                else if h > 1200 && e < 0.085 { p.extra = .propeller; p.extraX = .random(in: 2...11) }
            }
            plats.append(p)

            if h > 200 && CGFloat.random(in: 0..<1) < 0.12 + 0.25 * d {
                let y = topY + gap * .random(in: 0.35...0.65)
                plats.append(Platform(x: .random(in: 0...(World.width - World.platW)), y: y, kind: .breakable))
            }
            let farFromLast = monsters.last.map { $0.y - topY > 400 } ?? true
            if h > 3000 && farFromLast && CGFloat.random(in: 0..<1) < 0.025 + 0.03 * d {
                // keep it on the opposite side from the step it sits above
                let mx: CGFloat = p.x > World.width / 2 ? .random(in: 8...40) : .random(in: 88...120)
                monsters.append(Monster(x: mx, y: topY - gap * 0.5 - 6, baseX: mx))
            }
        }
    }

    private func cull() {
        let floor = camY + viewH + 40
        plats.removeAll { $0.y > floor || $0.gone > 60 }
        monsters.removeAll { $0.y > floor }
    }
}
