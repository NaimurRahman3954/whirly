import AVFoundation

/// A one-voice square-wave beeper. Each event replaces whatever is playing, like an old phone speaker.
/// Uses the ambient session, so the silent switch mutes it.
final class Sound {
    static let shared = Sound()
    var on: Bool { didSet { UserDefaults.standard.set(!on, forKey: "muted") } }

    private struct Seg { var f0, f1: Double; var n: Int; var total: Int; var vol: Float; var noise: Bool }
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var segs: [Seg] = []
    private var phase: Double = 0
    private var rate: Double = 44100

    private init() {
        on = !UserDefaults.standard.bool(forKey: "muted")
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if rate <= 0 { rate = 44100 }
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: fmt) { [unowned self] _, _, count, abl in
            let out = UnsafeMutableAudioBufferListPointer(abl)[0].mData!.assumingMemoryBound(to: Float.self)
            self.lock.lock()
            for i in 0..<Int(count) {
                var v: Float = 0
                if var s = self.segs.first {
                    let t = Double(s.total - s.n) / Double(s.total)
                    self.phase += (s.f0 + (s.f1 - s.f0) * t) / self.rate
                    if self.phase >= 1 { self.phase -= 1 }
                    let raw: Float = s.noise ? Float.random(in: -1...1) : (self.phase < 0.5 ? 1 : -1)
                    v = raw * s.vol * Float(1 - t * 0.6)
                    s.n -= 1
                    if s.n <= 0 { self.segs.removeFirst() } else { self.segs[0] = s }
                }
                out[i] = v
            }
            self.lock.unlock()
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = 0.35
        try? engine.start()
    }

    func play(_ e: Event) {
        guard on else { return }
        // (start Hz, end Hz, seconds, volume, noise)
        let list: [(Double, Double, Double, Float, Bool)]
        var append = false
        switch e {
        case .jump: list = [(330, 640, 0.07, 0.22, false)]
        case .spring: list = [(220, 1100, 0.24, 0.28, false)]
        case .propeller: list = (0..<58).map { i in i % 2 == 0 ? (520, 560, 0.06, 0.12, false) : (400, 430, 0.06, 0.12, false) }
        case .crack: list = [(0, 0, 0.09, 0.22, true)]
        case .stomp: list = [(720, 200, 0.12, 0.28, false)]
        case .die: list = [(600, 80, 0.7, 0.28, false)]
        case .fall: list = [(500, 60, 0.6, 0.28, false)]
        case .newBest: append = true; list = [(523, 523, 0.08, 0.22, false), (659, 659, 0.08, 0.22, false), (784, 784, 0.08, 0.22, false), (1046, 1046, 0.22, 0.22, false)]
        }
        if !engine.isRunning { try? engine.start() }
        let new = list.map { Seg(f0: $0.0, f1: $0.1, n: Int($0.2 * rate), total: Int($0.2 * rate), vol: $0.3, noise: $0.4) }
        lock.lock()
        if append { segs += new } else { segs = new }
        lock.unlock()
    }
}
