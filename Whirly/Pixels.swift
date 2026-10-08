import SwiftUI

enum Palette {
    static let bg = Color(white: 0.97)
    static let ink = Color(white: 0.30)
    static let light = Color(white: 0.72)
    static let shadow = Color(white: 0.86)
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
    static let colors: [Character: Color] = [
        "#": ink,
        "=": Color(white: 0.56),                 // mid grey
        "+": Color(white: 0.84),                 // light grey
        "-": Color(white: 0.91),                // clouds
        "w": .white,
        "o": rgb(0.98, 0.60, 0.18),              // beak and feet
        "r": rgb(0.92, 0.26, 0.21),
        "y": rgb(0.98, 0.76, 0.10),
        "g": rgb(0.36, 0.74, 0.36),              // moss
        "G": rgb(0.18, 0.52, 0.26),
        "b": rgb(0.26, 0.52, 0.96),
        "L": rgb(0.70, 0.80, 0.95),              // moving platform
        "B": rgb(0.38, 0.54, 0.80),
        "K": rgb(0.22, 0.32, 0.52),
        "N": rgb(0.86, 0.72, 0.56),              // crumbling clay
        "n": rgb(0.70, 0.54, 0.40),
        "D": rgb(0.42, 0.30, 0.22),
        "s": rgb(0.80, 0.84, 0.88),              // spring metal
        "S": rgb(0.50, 0.55, 0.62),
    ]
}

/// Pixel sprites as rows of characters; "." is transparent, other characters index `Palette.colors`.
enum Sprites {
    /// Pads or trims every row to `w` so a typo can't skew a sprite.
    static func fix(_ rows: [String], _ w: Int) -> [String] {
        rows.map { r in r.count >= w ? String(r.prefix(w)) : r + String(repeating: ".", count: w - r.count) }
    }

    // MARK: bird (14 × 12, facing right; the wing is drawn on top so it can flap)
    static let birdW: CGFloat = 14
    static let bird = fix([
        "...######.....",
        ".##======##...",
        "#======ww==#..",
        "#======w#==#o.",
        "#=========oooo",
        "#=======++#o..",
        "#=====++++#...",
        "#====+++++#...",
        ".#===++++#....",
        "..##+++##.....",
        "....o..o......",
        "...oo.oo......",
    ], 14)
    static let birdDead = fix([
        "...######.....",
        ".##======##...",
        "#======#=#=#..",
        "#=======#==#o.",
        "#======#=#=ooo",
        "#=======++#o..",
        "#=====++++#...",
        "#====+++++#...",
        ".#===++++#....",
        "..##+++##.....",
        "....o..o......",
        "...oo.oo......",
    ], 14)
    /// Wing frames and where they sit on the body.
    static let wingUp = (fix(["...#.", "..#=#", ".#==#", "####."], 5), CGPoint(x: 1, y: 3))
    static let wingMid = (fix([".####", "#===#", ".###."], 5), CGPoint(x: 1, y: 5))
    static let wingDown = (fix(["####.", ".#==#", "..#=#", "...#."], 5), CGPoint(x: 1, y: 6))

    // MARK: platforms (22 wide)
    static let plat = fix([
        ".gggggggggggggggggggg.",
        "GGgGGGGgGGGGGgGGGGgGGG",
        "#==G======G=====G====#",
        ".#==================#.",
        "..##################..",
    ], 22)
    static let platMoving = fix([
        ".LLLLLLLLLLLLLLLLLLLL.",
        "KBBLBBBBBBBBBBBBBBLBBK",
        "KBLBBBBBBBBBBBBBBBBLBK",
        ".KKKKKKKKKKKKKKKKKKKK.",
        "...KKKKKKKKKKKKKKKK...",
    ], 22)
    static let platBreak = fix([
        ".NNNNNNNNNNNNNNNNNNNN.",
        "DnnnDnnnnnnDnnnnnnDnnD",
        "DnnDnnnnnnnnDnnnnDnnnD",
        ".DDDD.DDDDDD.DDDDD.DD.",
    ], 22)
    static let platBreakLeft = platBreak.map { String($0.prefix(11)) }
    static let platBreakRight = platBreak.map { String($0.suffix(11)) }
    static let platVanish = fix([
        ".====================.",
        "=wwwwwwwwwwwwwwwwwwww=",
        "=w+ww+ww+ww+ww+ww+ww+=",
        ".====================.",
    ], 22)

    // MARK: spring (8 wide)
    static let spring = fix([
        ".ssssss.",
        "SSSSSSSS",
        ".S.s.S..",
        "SSSSSSSS",
    ], 8)
    static let springOut = fix([
        ".ssssss.",
        "SSSSSSSS",
        "..S..S..",
        ".s....s.",
        "..S..S..",
        ".s....s.",
        "..S..S..",
        "SSSSSSSS",
    ], 8)

    // MARK: propeller hat (11 × 6, four spin frames)
    static let hatBody = [
        ".....#.....",
        "...gwyyrr..",
        "..ggyyyrrr.",
        ".gggyyyrrrr",
        "bbbbbbbbbbb",
    ]
    static let hatFrames = [
        fix(["bbbbb#rrrrr"] + hatBody, 11),
        fix([".bbbb#rrrr."] + hatBody, 11),
        fix(["...bb#rr..."] + hatBody, 11),
        fix([".rrrr#bbbb."] + hatBody, 11),
    ]

    // MARK: monster (16 × 12, two walking frames)
    static let monsterTop = [
        "..#....##....#..",
        "...#..####..#...",
        "....########....",
        "..############..",
        ".###ww####ww###.",
        ".###wr####rw###.",
        "################",
        "#=############=#",
        "#=#w#w#w#w#w#=#.",
        "...##########...",
    ]
    static let monsterA = fix(monsterTop + ["...#..#..#..#...", "..##.##..##.##.."], 16)
    static let monsterB = fix(monsterTop + ["....#..#..#..#..", "...##.##.##.##.."], 16)

    // MARK: background clouds
    static let clouds = [
        fix([
            ".....----.........",
            "...--------..--...",
            ".--------------...",
            "------------------",
            ".----------------.",
        ], 18),
        fix([
            "...---....",
            ".-------..",
            "----------",
            ".--------.",
        ], 10),
    ]
}

/// A chunky 5 × 7 pixel font, like the score in the original.
enum Font5x7 {
    static func advance(_ size: CGFloat) -> CGFloat { size == 1 ? 7 : 6 * size }
    static let glyphs: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        ":": [".....", "..#..", "..#..", ".....", "..#..", "..#..", "....."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    ]
    static func width(_ s: String, size: CGFloat = 1) -> CGFloat { CGFloat(s.count) * advance(size) - size }
}
