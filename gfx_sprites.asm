// Boogie Bandit - sprites generated at build time.
// Multicolor art symbols: . transparent, k black ($d025), c sprite color,
// w white ($d026). Art is drawn in screen pixels (1:1) and sampled into
// multicolor sprite pixels (2 screen pixels wide), rotated if needed.

.function artVal(ch) {
    .if (ch == "k") .return 1
    .if (ch == "c") .return 2
    .if (ch == "w") .return 3
    .return 0
}
// Rotate art clockwise by deg degrees around the sprite centre (12, 10.5).
.function rotSprite(art, deg) {
    .var h = art.size()
    .var w = art.get(0).size()
    .var a = deg * PI / 180
    .var ca = cos(a)
    .var sa = sin(a)
    .var out = List()
    .for (var y = 0; y < 21; y++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var p = 0; p < 4; p++) {
                .var mx = b * 4 + p
                .var val = 0
                .for (var s = 0; s < 2; s++) {
                    .if (val == 0) {
                        .var sx = 2 * mx + s + 0.5 - 12
                        .var sy = y + 0.5 - 10.5
                        .var ux = sx * ca + sy * sa
                        .var uy = -sx * sa + sy * ca
                        .var ax = floor(ux + w / 2)
                        .var ay = floor(uy + h / 2)
                        .if (ax >= 0 && ax < w && ay >= 0 && ay < h) .eval val = artVal(art.get(ay).charAt(ax))
                    }
                }
                .eval v = v * 4 + val
            }
            .eval out.add(v)
        }
    }
    .eval out.add(0)
    .return out
}

// ---------------------------------------------------------------- the getaway car
// A 70s sedan with a vinyl roof, nose up (heading 0 = north).
.var carArt = List().add(
    "..wccccccw..",
    ".cccccccccc.",
    "kcccccccccck",
    "kcccccccccck",
    "kcccccccccck",
    ".cccccccccc.",
    ".ckwwwwwwkc.",
    ".ckwwwwwwkc.",
    ".cckkkkkkcc.",
    ".cckkkkkkcc.",
    ".cckkkkkkcc.",
    ".cckkkkkkcc.",
    ".ckwwwwwwkc.",
    ".cccccccccc.",
    "kcccccccccck",
    "kcccccccccck",
    "kcccccccccck",
    ".cccccccccc.",
    ".cccccccccc.",
    "..kcccccck..")
.var sprHi = List()
.for (var f = 0; f < 16; f++) {
    .var d = rotSprite(carArt, f * 22.5)
    .for (var i = 0; i < 64; i++) .eval sprHi.add(d.get(i))
}

// ---------------------------------------------------------------- arrow to the bank
// A yellow arrow on a black dial with a white rim, 16 directions.
.for (var f = 0; f < 16; f++) {
    .var a = f * PI / 8
    .var ca = cos(a)
    .var sa = sin(a)
    .for (var y = 0; y < 21; y++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var p = 0; p < 4; p++) {
                .var sx = 2 * (b * 4 + p) + 1 - 12
                .var sy = y + 0.5 - 10.5
                .var r = sqrt(sx * sx + sy * sy)
                .var ux = sx * ca + sy * sa
                .var uy = -sx * sa + sy * ca
                .var val = 0
                .if (r < 10.6) {
                    .eval val = (r >= 9.2) ? 3 : 1
                    .var head = uy >= -8.5 && uy <= -1.5 && abs(ux) <= (uy + 8.5) * 0.75
                    .var shaft = abs(ux) <= 1.9 && uy >= -2 && uy <= 7.5
                    .if (head || shaft) .eval val = 2
                }
                .eval v = v * 4 + val
            }
            .eval sprHi.add(v)
        }
    }
    .eval sprHi.add(0)
}
.errorif sprHi.size() != 32 * 64, "high sprite block must be 32 sprites"

// ---------------------------------------------------------------- low block ($c800)
.var sprLo = List()
.function addSprite(bytes) {
    .for (var i = 0; i < 64; i++) .eval sprLo.add(i < bytes.size() ? bytes.get(i) : 0)
    .return 0
}

// HUD boxes: black box, three 3x5 cells for digits (filled at run time), a
// yellow label below. Pixel codes: 1 black box, 2 label (sprite color).
.function hudSprite(label) {
    .var out = List()
    .for (var y = 0; y < 21; y++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var p = 0; p < 4; p++) {
                .var val = (y <= 12) ? 1 : 0
                .if (y >= 7 && y <= 11 && p >= 1) {
                    .if (font3.get(label.charAt(b)).get(y - 7).charAt(p - 1) == "#") .eval val = 2
                }
                .eval v = v * 4 + val
            }
            .eval out.add(v)
        }
    }
    .return out
}
.eval addSprite(hudSprite("FPS"))       // 0
.eval addSprite(hudSprite("SCO"))       // 1
.eval addSprite(hudSprite("RE "))       // 2

// the bandit: 4 directions (up, right, down, left) x 2 steps, then the same
// carrying the loot bag
.var manDown = List().add(
    "...kkkk...", "..kkkkkk..", ".kkkkkkkk.", ".kkwwwwkk.", "..wkwwkw..", "..wwwwww..", "...wkkw...",
    ".cccwwccc.", "ccccwwcccc", "cc.cccc.cc", "cc.cccc.cc", "ww.cccc.ww", "...kkkk...")
.var manUp = List().add(
    "...kkkk...", "..kkkkkk..", ".kkkkkkkk.", ".kkkkkkkk.", "..kkkkkk..", "..kkkkkk..", "...wwww...",
    ".cccccccc.", "cccccccccc", "cc.cccc.cc", "cc.cccc.cc", "ww.cccc.ww", "...kkkk...")
.var manRight = List().add(
    "...kkkk...", "..kkkkkk..", "..kkkkkkk.", "..kkkwww..", "..kkkwkw..", "..kkwwww..", "...kwww...",
    "...ccccc..", "..cccccc..", "..cccccc..", "..ccwccc..", "...cwcc...", "...kkkk...")
.var legsA = List().add("..k....k..", ".kk....kk.", ".kk....kk.")
.var legsB = List().add("...k..k...", "...k..k...", "..kk..kk..")
.var legsSideA = List().add("..k...k...", ".k.....k..", "kk.....kk.")
.var legsSideB = List().add("....kk....", "....kk....", "....kkk...")
.function mirror(s) {
    .var r = ""
    .for (var i = s.size() - 1; i >= 0; i--) {
        .var c = s.charAt(i)
        .eval r = r + c
    }
    .return r
}
.function manFrame(body, legs, flip, bag) {
    .var art = List()
    .for (var i = 0; i < body.size() + legs.size(); i++) {
        .var s = (i < body.size()) ? body.get(i) : legs.get(i - body.size())
        .if (flip) .eval s = mirror(s)
        .var extra = "......"
        .if (bag) {
            .if (i == 8) .eval extra = "..kk.."
            .if (i == 9) .eval extra = ".wwww."
            .if (i >= 10 && i <= 13) .eval extra = "wwwwww"
            .if (i == 14) .eval extra = ".wwww."
        }
        .eval art.add("......" + s + extra)
    }
    .eval art.add("......................")
    .return art
}
.for (var bag = 0; bag < 2; bag++) {
    .eval addSprite(rotSprite(manFrame(manUp, legsA, false, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manUp, legsB, false, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manRight, legsSideA, false, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manRight, legsSideB, false, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manDown, legsA, false, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manDown, legsB, false, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manRight, legsSideA, true, bag == 1), 0))
    .eval addSprite(rotSprite(manFrame(manRight, legsSideB, true, bag == 1), 0))
}

// bank marker: a bouncing arrow pointing down at the door (2 colours)
.for (var fr = 0; fr < 2; fr++) {
    .var art = List()
    .for (var y = 0; y < 20; y++) {
        .var s = ""
        .for (var x = 0; x < 16; x++) {
            .var c = "."
            .var fx = x + 0.5 - 8
            .var inside = (abs(fx) <= 3 && y <= 10) || (y >= 9 && y <= 18 && abs(fx) <= (18 - y) * 0.85)
            .var near = false
            .for (var ox = -1; ox <= 1; ox++) {
                .for (var oy = -1; oy <= 1; oy++) {
                    .var gx = fx + ox
                    .var gy = y + oy
                    .if ((abs(gx) <= 3 && gy >= 0 && gy <= 10) || (gy >= 9 && gy <= 18 && abs(gx) <= (18 - gy) * 0.85)) .eval near = true
                }
            }
            .if (near) .eval c = "k"
            .if (inside) .eval c = (fr == 0) ? "c" : "w"
            .if (inside && fx < -1 && fr == 0) .eval c = "w"
            .eval s = s + c
        }
        .eval art.add(s)
    }
    .eval addSprite(rotSprite(art, 0))
}

// "PRESS FIRE" in three hi-res sprites (shown x- and y-expanded on the title)
.var pfText = "PRESS FIRE"
.var pfRows = List()
.for (var y = 0; y < 21; y++) {
    .var bits = List()
    .for (var x = 0; x < 72; x++) .eval bits.add(0)
    .if (y < 7) {
        .for (var i = 0; i < pfText.size(); i++) {
            .for (var gx = 0; gx < 4; gx++) .if (fontPix(pfText.charAt(i), gx, y)) .eval bits.set(11 + i * 5 + gx, 1)
        }
    }
    .eval pfRows.add(bits)
}
.for (var sp = 0; sp < 3; sp++) {
    .var out = List()
    .for (var y = 0; y < 21; y++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var p = 0; p < 8; p++) .eval v = v * 2 + pfRows.get(y).get(sp * 24 + b * 8 + p)
            .eval out.add(v)
        }
    }
    .eval addSprite(out)
}
.errorif sprLo.size() > 32 * 64, "low sprite block is full"

// sprite numbers (pointer = $c800 block 32+n, $d800 block 96+n)
.const SP_FPS = 32
.const SP_SC1 = 33
.const SP_SC2 = 34
.const SP_MAN = 35              // + dir*2 + step, +8 with the bag
.const SP_MARK = 51
.const SP_PRESS = 53
.const SP_CAR = 96
.const SP_ARROW = 112

// HUD digit rows: box pixel then three digit pixels (white on black)
.var digitRows = List()
.for (var d = 0; d < 10; d++) {
    .for (var r = 0; r < 5; r++) {
        .var v = 1
        .for (var p = 0; p < 3; p++) .eval v = v * 4 + ((font3.get("" + d).get(r).charAt(p) == "#") ? 3 : 1)
        .eval digitRows.add(v)
    }
}
