// Boogie Bandit - the title picture, painted at build time into a
// 160 x 200 multicolor bitmap: striped 70s sky, a striped sunset, the
// skyline, a street, and the logo in a slanted, striped 70s style.
// Colours are C64 colour numbers; the background ($d021) is black.

.const IW = 160
.const IH = 200
.var ipix = List()
.for (var i = 0; i < IW * IH; i++) .eval ipix.add(0)
.function ip(x, y, c) {
    .if (x >= 0 && x < IW && y >= 0 && y < IH) .eval ipix.set(y * IW + x, c)
    .return 0
}
.function ig(x, y) {
    .if (x >= 0 && x < IW && y >= 0 && y < IH) .return ipix.get(y * IW + x)
    .return -1
}
.function irect(x0, y0, w, h, c) {
    .for (var y = y0; y < y0 + h; y++) .for (var x = x0; x < x0 + w; x++) .eval ip(x, y, c)
    .return 0
}

// sky bands (band edges on character rows, so every cell stays legal)
.eval irect(0, 0, IW, 40, 6)          // blue
.eval irect(0, 40, IW, 32, 4)         // purple
.eval irect(0, 72, IW, 32, 10)        // light red
.eval irect(0, 104, IW, 48, 8)        // orange

// the sun: yellow, horizontal gaps that widen towards the horizon
.for (var y = 104; y < 152; y++) {
    .for (var x = 0; x < IW; x++) {
        .var dx = (x - 80) * 2 + 1
        .var dy = y - 152
        .if (dx * dx + dy * dy < 46 * 46) {
            .var gap = false
            .if (y >= 124) {
                .var s = y - 124
                .if (mod(s, 7) < 1 + floor(s / 9)) .eval gap = true
            }
            .if (!gap) .eval ip(x, y, 7)
        }
    }
}

// skyline: black buildings with lit windows (bottom at y = 152)
.function tower(x0, w, top, lit) {
    .eval irect(x0, top, w, 152 - top, 0)
    .for (var y = top + 3; y < 148; y = y + 4) {
        .for (var x = x0 + 1; x < x0 + w - 1; x = x + 2) {
            .if (rnd(100) < lit) .eval ip(x, y, 7)
        }
    }
    .return 0
}
.var sx = 0
.while (sx < IW) {
    .var w = 6 + rnd(9)
    .var top = 112 + rnd(26)
    .if (sx + w > 62 && sx < 98) .eval top = 138 + rnd(8)
    .eval tower(sx, w, top, 35)
    .eval sx = sx + w + rnd(3)
}
.eval tower(18, 8, 76, 45)            // twin towers
.eval tower(28, 8, 76, 45)
.eval tower(104, 10, 92, 40)          // a spire building
.eval irect(106, 86, 6, 6, 0)
.eval irect(107, 80, 4, 6, 0)
.eval irect(108, 72, 2, 8, 0)
.eval tower(128, 9, 100, 40)          // a stepped crown
.eval irect(130, 94, 5, 6, 0)
.eval irect(131, 89, 3, 5, 0)
.eval tower(2, 10, 118, 30)
.eval tower(140, 12, 110, 35)

// the street
.eval irect(0, 152, IW, 8, 12)        // sidewalk
.eval irect(0, 160, IW, 32, 11)       // road
.for (var x = 2; x < IW; x = x + 10) .eval irect(x, 175, 5, 2, 7)
.eval irect(0, 192, IW, 8, 12)        // sidewalk

.var tag = "NEW YORK CITY 1977"
.var tagX = floor((IW - tag.size() * 5) / 2)
.for (var i = 0; i < tag.size(); i++) {
    .for (var gy = 0; gy < 7; gy++) .for (var gx = 0; gx < 4; gx++) {
        .if (fontPix(tag.charAt(i), gx, gy)) .eval ip(tagX + i * 5 + gx, 152 + gy, 1)
    }
}

// the logo: 4x7 font scaled 4 wide x 3 high, slanted, striped
// yellow/orange/red by character row, brown drop shadow, black outline
.function logoLine(text, y0) {
    .var lw = 16
    .var gap = 4
    .var x0 = floor((IW - (text.size() * lw + (text.size() - 1) * gap)) / 2) - 2
    .var on = Hashtable()
    .for (var i = 0; i < text.size(); i++) {
        .for (var y = 0; y < 21; y++) {
            .var slant = floor((20 - y) / 5)
            .for (var x = 0; x < lw; x++) {
                .if (fontPix(text.charAt(i), floor(x / 4), floor(y / 3))) .eval on.put("" + (x0 + i * (lw + gap) + x + slant) + "," + (y0 + y), true)
            }
        }
    }
    // outline + shadow first, letters on top
    .for (var y = y0 - 1; y < y0 + 24; y++) {
        .for (var x = 0; x < IW; x++) {
            .if (!on.containsKey("" + x + "," + y)) {
                .if (on.containsKey("" + (x - 1) + "," + (y - 2)) || on.containsKey("" + x + "," + (y - 2)) || on.containsKey("" + (x - 1) + "," + (y - 1))) {
                    .eval ip(x, y, 9)
                } else {
                    .if (on.containsKey("" + (x - 1) + "," + y) || on.containsKey("" + (x + 1) + "," + y) || on.containsKey("" + x + "," + (y - 1)) || on.containsKey("" + x + "," + (y + 1))) .eval ip(x, y, 0)
                }
            }
        }
    }
    .for (var y = y0; y < y0 + 21; y++) {
        .var c = (y < y0 + 8) ? 7 : ((y < y0 + 16) ? 8 : 2)
        .for (var x = 0; x < IW; x++) .if (on.containsKey("" + x + "," + y)) .eval ip(x, y, c)
    }
    .return 0
}
.eval logoLine("BOOGIE", 8)
.eval logoLine("BANDIT", 40)

// ---------------------------------------------------------------- to multicolor bitmap
.var introBitmap = List()
.var introScreen = List()
.var introColor = List()
.var introClashes = 0
.for (var cy = 0; cy < 25; cy++) {
    .for (var cx = 0; cx < 40; cx++) {
        .var count = List()
        .for (var c = 0; c < 16; c++) .eval count.add(0)
        .for (var y = 0; y < 8; y++) .for (var x = 0; x < 4; x++) {
            .var c = ig(cx * 4 + x, cy * 8 + y)
            .eval count.set(c, count.get(c) + 1)
        }
        .var pick = List()
        .for (var n = 0; n < 3; n++) {
            .var best = -1
            .for (var c = 1; c < 16; c++) {
                .if (count.get(c) > 0 && (best < 0 || count.get(c) > count.get(best))) {
                    .var used = false
                    .for (var k = 0; k < pick.size(); k++) .if (pick.get(k) == c) .eval used = true
                    .if (!used) .eval best = c
                }
            }
            .if (best >= 0) .eval pick.add(best)
        }
        .for (var k = pick.size(); k < 3; k++) .eval pick.add(0)
        .for (var y = 0; y < 8; y++) {
            .var v = 0
            .for (var x = 0; x < 4; x++) {
                .var c = ig(cx * 4 + x, cy * 8 + y)
                .var code = 0
                .if (c != 0) {
                    .eval code = 1
                    .if (c == pick.get(1)) .eval code = 2
                    .if (c == pick.get(2)) .eval code = 3
                    .if (c != pick.get(0) && c != pick.get(1) && c != pick.get(2)) .eval introClashes = introClashes + 1
                }
                .eval v = v * 4 + code
            }
            .eval introBitmap.add(v)
        }
        .eval introScreen.add(pick.get(0) * 16 + pick.get(1))
        .eval introColor.add(pick.get(2))
    }
}
.print "Title picture colour clashes: " + introClashes
