import SwiftUI
import CoreMotion

/// Full-screen game: a Canvas for the picture, a UIKit layer on top for touches.
struct GameView: View {
    @StateObject private var game = Game()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            let ins = geo.safeAreaInsets
            let size = CGSize(width: geo.size.width + ins.leading + ins.trailing, height: geo.size.height + ins.top + ins.bottom)
            let s = size.width / World.width
            let _ = game.frame
            ZStack {
                Canvas { ctx, _ in Renderer(game: game, ctx: ctx, s: s, k: displayScale).draw() }
                Touches(game: game, scale: s)
            }
            .frame(width: size.width, height: size.height)
            .offset(x: -ins.leading, y: -ins.top)
            .onAppear { game.layout(viewH: size.height / s, topInset: max(ins.top / s, 6)); start() }
            .onChange(of: size) { _, n in game.layout(viewH: n.height / s, topInset: max(ins.top / s, 6)) }
        }
        .background(Palette.bg.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, p in
            if p != .active && game.phase == .playing { game.phase = .paused }
        }
    }

    private func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        let soft = UIImpactFeedbackGenerator(style: .light)
        let firm = UIImpactFeedbackGenerator(style: .medium)
        let notify = UINotificationFeedbackGenerator()
        game.onEvent = { e in
            Sound.shared.play(e)
            switch e {
            case .spring, .propeller, .stomp: firm.impactOccurred()
            case .crack: soft.impactOccurred()
            case .die, .fall: notify.notificationOccurred(.error)
            case .newBest: notify.notificationOccurred(.success)
            case .jump: break
            }
        }
        Ticker.shared.start {
            game.tilt = Tilt.shared.x
            game.step()
        }
    }
}

/// Tracks every finger directly. A tap goes to the menus; holding the left or right half steers.
struct Touches: UIViewRepresentable {
    let game: Game
    let scale: CGFloat
    func makeUIView(context: Context) -> TouchView { let v = TouchView(); v.game = game; v.scale = scale; return v }
    func updateUIView(_ v: TouchView, context: Context) { v.game = game; v.scale = scale }

    final class TouchView: UIView {
        weak var game: Game?
        var scale: CGFloat = 1
        private var active: [UITouch] = []

        override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = true; backgroundColor = .clear }
        required init?(coder: NSCoder) { fatalError() }

        private func world(_ t: UITouch) -> CGPoint { let p = t.location(in: self); return CGPoint(x: p.x / scale, y: p.y / scale) }
        private func refresh() {
            // the newest finger wins, so you can switch sides without lifting the other thumb
            guard let game, let t = active.last else { game?.hold = 0; return }
            game.hold = world(t).x < World.width / 2 ? -1 : 1
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let game else { return }
            for t in touches {
                let p = world(t)
                game.tap(x: p.x, y: p.y)
                if game.steers(x: p.x, y: p.y) { active.append(t) }
            }
            refresh()
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { refresh() }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { active.removeAll { touches.contains($0) }; refresh() }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { active.removeAll { touches.contains($0) }; refresh() }
    }
}

/// Phone tilt, read once per frame.
final class Tilt {
    static let shared = Tilt()
    private let motion = CMMotionManager()
    private init() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates()
    }
    var x: CGFloat { CGFloat(motion.deviceMotion?.gravity.x ?? 0) }
}

/// Fixed-step 60 Hz clock driven by the display link.
final class Ticker {
    static let shared = Ticker()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0, acc: CFTimeInterval = 0
    private var tick: (() -> Void)?
    func start(_ f: @escaping () -> Void) {
        tick = f; link?.invalidate(); last = 0; acc = 0
        link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        link?.add(to: .main, forMode: .common)
    }
    @objc private func frame(_ l: CADisplayLink) {
        if last == 0 { last = l.timestamp }
        acc += min(l.timestamp - last, 0.1); last = l.timestamp
        let dt = 1.0 / 60.0
        while acc >= dt { tick?(); acc -= dt }
    }
}
