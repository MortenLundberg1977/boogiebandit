// Boogie Bandit - the REU edition's newspaper (shown when Vinnie is busted):
// a front page painted at build time into a multicolor bitmap (160 x 200),
// stored raw in the REU (boogie.asm: REU edition). Pixel values:
//   0 paper   $d021 (white)
//   1 grey    screen RAM high nibble (dark grey)
//   2 ink     screen RAM low nibble (black)
//   3 accent  colour RAM per cell (light grey in the photo, red for EXTRA!)
// Uses its own random numbers (newsRnd), so the city stays the same.

.var newsPix = List()
.for (var i = 0; i < 160 * 200; i++) .eval newsPix.add(0)
.var newsRed = Hashtable()              // cells whose accent is red
.var newsSeed = 1977
.function newsRnd(n) {
    .eval newsSeed = mod(newsSeed * 75 + 74, 65537)
    .return mod(newsSeed, n)
}
.function npix(x, y, v) {
    .if (x >= 0 && x < 160 && y >= 0 && y < 200) .eval newsPix.set(y * 160 + x, v)
    .return 0
}
.function nrect(x, y, w, h, v) {
    .for (var j = 0; j < h; j++) .for (var i = 0; i < w; i++) .eval npix(x + i, y + j, v)
    .return 0
}
// text in the game's 4 x 7 font, each pixel s x s (t: the height scale)
.function ntext(x, y, s, t, str, v) {
    .for (var c = 0; c < str.size(); c++) {
        .var ch = str.charAt(c)
        .if (ch != " ") {
            .for (var gy = 0; gy < 7; gy++) .for (var gx = 0; gx < 4; gx++) {
                .if (fontPix(ch, gx, gy)) .eval nrect(x + c * 5 * s + gx * s, y + gy * t, s, t, v)
            }
        }
    }
    .return 0
}
.function ntextC(y, s, t, str, v) {                 // centred
    .return ntext(floor((160 - (str.size() * 5 - 1) * s) / 2), y, s, t, str, v)
}
// sprite-style art ("k" black, "c" grey, "w" light), each pixel s x s
.function nart(x, y, s, art) {
    .for (var j = 0; j < art.size(); j++) {
        .var row = art.get(j)
        .for (var i = 0; i < row.size(); i++) {
            .var ch = row.charAt(i)
            .var v = ch == "k" ? 2 : (ch == "c" ? 1 : (ch == "w" ? 3 : -1))
            .if (v >= 0) .eval nrect(x + i * s, y + j * s, s, s, v)
        }
    }
    .return 0
}
// lines of small "text" (grey bars of random word lengths)
.function ncolumn(x, y, w, rows) {
    .for (var r = 0; r < rows; r++) {
        .var cx = x
        .var end = (r == rows - 1) ? x + floor(w / 2) : x + w
        .while (cx < end - 3) {
            .var wl = 2 + newsRnd(6)
            .if (cx + wl > end) .eval wl = end - cx
            .eval nrect(cx, y + r * 4, wl, 2, 1)
            .eval cx = cx + wl + 1
        }
    }
    .return 0
}

// the masthead
.eval nrect(0, 0, 160, 200, 0)
.eval ntextC(4, 2, 2, "THE DAILY BOOGIE", 2)
.eval nrect(4, 21, 152, 1, 2)
.eval ntextC(24, 1, 1, "NEW YORK 1977 - FINAL - 15 CENTS", 1)
.eval nrect(4, 33, 152, 2, 2)
// EXTRA! in red, top left
.eval ntext(5, 37, 1, 1, "EXTRA!", 3)
.for (var cy = 4; cy <= 5; cy++) .for (var cx = 1; cx <= 8; cx++) .eval newsRed.put("" + (cy * 40 + cx), true)
// the headline
.eval ntextC(46, 3, 3, "BUSTED!", 2)
.eval ntextC(72, 1, 1, "COPS NAB THE BOOGIE BANDIT", 2)
.eval nrect(4, 81, 152, 1, 1)
// the photo: a police lineup, Vinnie with his hands up next to an newsCop
.const PX = 6
.const PY = 85
.eval nrect(PX, PY, 78, 80, 2)
.eval nrect(PX + 1, PY + 1, 76, 78, 0)
.for (var h = 0; h < 6; h++) {
    .eval nrect(PX + 1, PY + 6 + h * 12, 76, 1, 1)
    .eval ntext(PX + 2, PY + 8 + h * 12, 1, 1, "" + (7 - h), 1)
}
.var newsVinnie = List().add(
    "w..........w", ".c..kkkk..c.", ".c.kkkkkk.c.", "..ckkkkkkc..", "..ckwwwwkc..",
    "...wkwwkw...", "...wwwwww...", "....wkkw....", "...cccccc...", "...cccccc...",
    "...ccwwcc...", "...cccccc...", "...kkkkkk...", "..kk....kk..", "..kk....kk..",
    ".kk......kk.", ".kk......kk.", "kkk......kkk")
.var newsCop = List().add(
    "..cccccc..", ".cccwwccc.", ".kkkkkkkk.", "..wkwwkw..", "..wwwwww..", "...wkkw...", "....ww....",
    "wccccccccw", "wccwcccccw", "w..cccc..w", "...cccc...", "...kkkk...", "...cccc...",
    "..c....c..", ".kk....kk.", ".kk....kk.")
.eval nart(PX + 4, PY + 24, 3, newsVinnie)
.eval nart(PX + 44, PY + 30, 3, newsCop)
.eval ntext(PX + 1, PY + 82, 1, 1, "VINNIE IN CUFFS", 2)
// the columns
.eval ncolumn(90, 86, 66, 8)
.eval ntext(90, 120, 1, 1, "LOOT GONE", 2)
.eval ncolumn(90, 130, 66, 15)
.eval ncolumn(6, 176, 78, 5)

// to a bitmap: 4 pixels a byte, cells of 8 rows
.var newsBitmap = List()
.for (var cell = 0; cell < 1000; cell++) {
    .var cx = mod(cell, 40) * 4
    .var cy = floor(cell / 40) * 8
    .for (var r = 0; r < 8; r++) {
        .var v = 0
        .for (var p = 0; p < 4; p++) .eval v = v * 4 + newsPix.get((cy + r) * 160 + cx + p)
        .eval newsBitmap.add(v)
    }
}
.var newsScreen = List()
.var newsColour = List()
.for (var cell = 0; cell < 1024; cell++) {
    .eval newsScreen.add($b0)                          // dark grey, black
    .eval newsColour.add(newsRed.containsKey("" + cell) ? 2 : 15)
}
