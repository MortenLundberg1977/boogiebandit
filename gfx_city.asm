// Boogie Bandit - the city, built at build time by KickAssembler script:
// character set (multicolor), the 128 x 128 character map, the banks and
// the comic bubble characters. boogie.asm emits the data.
//
// Pixel symbols in the art (multicolor, 4 pixels per character):
//   .  asphalt          $d021 (ROAD_COL)
//   w  sidewalk/light   $d022 (WALK_COL)
//   b  brown            $d023 (ROOF_COL)
//   y  yellow           color RAM (one value for the whole screen)

.const CL_FREE = 0              // class bits: 1 = blocks the car, 2 = blocks the walker
.const CL_SOLID = 3
.const CL_DOOR = 7              // 4 = bank door

.var chars = List()
.var charKeys = Hashtable()
.var charClass = List()

.function pv(ch) {
    .if (ch == "w") .return 1
    .if (ch == "b") .return 2
    .if (ch == "y") .return 3
    .return 0
}
.function cellBytes(rows, cx, cy) {
    .var bytes = List()
    .for (var l = 0; l < 8; l++) {
        .var s = rows.get(cy * 8 + l)
        .var v = 0
        .for (var p = 0; p < 4; p++) .eval v = v * 4 + pv(s.charAt(cx * 4 + p))
        .eval bytes.add(v)
    }
    .return bytes
}
.function addChar(bytes, cls) {
    .var key = "" + cls
    .for (var i = 0; i < 8; i++) .eval key = key + "," + bytes.get(i)
    .if (!charKeys.containsKey(key)) {
        .eval charKeys.put(key, chars.size())
        .eval chars.add(bytes)
        .eval charClass.add(cls)
    }
    .return charKeys.get(key)
}
// Slice art (width a multiple of 4, height a multiple of 8) into characters.
.function stamp(rows, cls) {
    .var st = List()
    .for (var cy = 0; cy < rows.size() / 8; cy++) {
        .var line = List()
        .for (var cx = 0; cx < rows.get(0).size() / 4; cx++) .eval line.add(addChar(cellBytes(rows, cx, cy), cls))
        .eval st.add(line)
    }
    .return st
}
.function one(rows, cls) { .return stamp(rows, cls).get(0).get(0) }
.function rows8(a, b, c, d, e, f, g, h) { .return List().add(a, b, c, d, e, f, g, h) }

// ---------------------------------------------------------------- road
.var ROADCH = one(rows8("....", "....", "....", "....", "....", "....", "....", "...."), CL_FREE)
.var SKID_V = one(rows8(".b..", ".b..", "..b.", "..b.", ".b..", ".b..", "..b.", "..b."), CL_FREE)
.var SKID_H = one(rows8("....", "....", "....", "bbbb", "bbbb", "....", "....", "...."), CL_FREE)
.var SKID_U = one(rows8("...b", "...b", "..bb", "..b.", ".bb.", ".b..", "bb..", "b..."), CL_FREE)   // "/"
.var SKID_D = one(rows8("b...", "bb..", ".b..", ".bb.", "..b.", "..bb", "...b", "...b"), CL_FREE)   // "\"
.var AVL = one(rows8("...y", "...y", "...y", "...y", "...y", "...y", "...y", "...y"), CL_FREE)
.var AVR = one(rows8("y...", "y...", "y...", "y...", "y...", "y...", "y...", "y..."), CL_FREE)
.var STDASH = one(rows8("....", "....", "....", "....", "....", "....", "wwww", "...."), CL_FREE)
.var ZEB_H = one(rows8("wwww", "wwww", "....", "....", "wwww", "wwww", "....", "...."), CL_FREE)
.var ZEB_V = one(rows8("ww..", "ww..", "ww..", "ww..", "ww..", "ww..", "ww..", "ww.."), CL_FREE)
.var MANHOLE = stamp(List().add(
    "........", "..bbbb..", ".b.b.bb.", "b.b.b.bb", "bb.b.b.b", ".bb.b.b.", "..bbbb..", "........"), CL_FREE)
.var STALL = one(rows8("w...", "w...", "w...", "w...", "w...", "w...", "w...", "w..."), CL_FREE)

// ---------------------------------------------------------------- sidewalk, wall
.var WALK = one(rows8("wwww", "wwww", "wwww", "wwww", "wwww", "wwww", "wwww", "wwww"), CL_FREE)
.var WALK2 = one(rows8("wwww", "wwww", "ww.w", "w.ww", "wwww", "wwww", "wwww", "wwww"), CL_FREE)
.var HYDRANT = one(rows8("wwww", "wwww", "wbbw", "bbbb", "wbbw", "wwww", "wwww", "wwww"), CL_FREE)
.var WALLCH = one(rows8("bbbw", "bbbw", "wwww", "bwbb", "bwbb", "wwww", "bbbw", "bbbw"), CL_SOLID)

// ---------------------------------------------------------------- roofs
// 12 x 24 pictures cut into 3 x 3 characters (9-slice). The bottom band is
// the front of the building (a facade with lit windows).
.var roofA = stamp(List().add(
    "wwwwwwwwwwww", "wbbbbbbbbbbw", "wbbbbbbbbbbw", "wbbbbbbb.bbw", "wbbbbbbbbbbw", "wbb.bbbbbbbw", "wbbbbbbbbbbw", "wbbbbbbbbbbw",
    "wbbbbbbbbbbw", "wbbbbb.bbbbw", "wbbbbbbbbbbw", "wbbbbbbbbbbw", "wbb.bbbbbbbw", "wbbbbbbbbbbw", "wbbbbbbbb.bw", "wbbbbbbbbbbw",
    "wwwwwwwwwwww", "bbbbbbbbbbbb", "byybbyybbyyb", "byybbyybbyyb", "bbbbbbbbbbbb", "byybbyybbyyb", "byybbyybbyyb", "bbbbbbbbbbbb"), CL_SOLID)
.var roofB = stamp(List().add(
    "bbbbbbbbbbbb", "bwwwwwwwwwwb", "bwwwwwwwwwwb", "bwwwwwwwwwwb", "bwwww..wwwwb", "bwwwwwwwwwwb", "bwwwwwwwwwwb", "bwwwwwwwwwwb",
    "bwwwwwwwwwwb", "bwwwwwwwwwwb", "bww..wwwwwwb", "bwwwwwwwwwwb", "bwwwwwwwwwwb", "bwwwwwwww.wb", "bwwwwwwwwwwb", "bwwwwwwwwwwb",
    "bbbbbbbbbbbb", "............", ".yy..yy..yy.", ".yy..yy..yy.", "............", ".yy..yy..yy.", ".yy..yy..yy.", "bbbbbbbbbbbb"), CL_SOLID)
.var roofC = stamp(List().add(
    "bbbbbbbbbbbb", "bwwwwwwwwwwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbwwbbbwb", "bwbbbyybbbwb", "bwbbbwwbbbwb", "bwbbbbbbbbwb",
    "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb", "bwbbbbbbbbwb",
    "wwwwwwwwwwww", "bbbbbbbbbbbb", "byybbyybbyyb", "byybbyybbyyb", "wwwwwwwwwwww", "byybbyybbyyb", "byybbyybbyyb", "bbbbbbbbbbbb"), CL_SOLID)
.var roofBank = stamp(List().add(
    "yyyyyyyyyyyy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy",
    "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy", "ywwwwwwwwwwy",
    "yyyyyyyyyyyy", "wwwwwwwwwwww", "wbbwwbbwwbbw", "wbbwwbbwwbbw", "wbbwwbbwwbbw", "wbbwwbbwwbbw", "wwwwwwwwwwww", "bbbbbbbbbbbb"), CL_SOLID)
.var roofs = List().add(roofA, roofB, roofC)
.var bankSign = stamp(List().add(
    "wwwwwwww", "wwwwwwww", "wwwyywww", "wyyyyyyw", "yybyybbw", "yybyybww", "wyyyyyyw", "wbyyyyyy",
    "wwwyybyy", "wwwyybyy", "yyyyyyyb", "wbbyybbw", "wwwyywww", "wwwwbbww", "wwwwwwww", "wwwwwwww"), CL_SOLID)
.var bankText = List()
.for (var y = 0; y < 8; y++) {
    .var s = ""
    .for (var i = 0; i < 4; i++) .for (var x = 0; x < 4; x++) .eval s = s + ((y >= 1 && fontPix("BANK".charAt(i), x, y - 1)) ? "b" : "w")
    .eval bankText.add(s)
}
.var BANKWORD = stamp(bankText, CL_SOLID)
.var bankDoor = stamp(List().add(
    "yyyyyyyy", "ybbbbbby", "ybbbbbby", "ybbbbbby", "ybbybbby", "ybbbbbby", "ybbbbbby", "yyyyyyyy"), CL_DOOR)

// water tank (2 x 2 characters, drawn on brown roofs)
.var tankArt = List()
.for (var y = 0; y < 16; y++) {
    .var s = ""
    .for (var x = 0; x < 8; x++) {
        .var dx = x * 2 + 1 - 8
        .var dy = y + 0.5 - 8
        .var d = sqrt(dx * dx + dy * dy)
        .var c = "b"
        .if (d < 7.2) .eval c = "."
        .if (d < 5.6) .eval c = "w"
        .if (d < 2.2) .eval c = "b"
        .eval s = s + c
    }
    .eval tankArt.add(s)
}
.var TANK = stamp(tankArt, CL_SOLID)

// ---------------------------------------------------------------- parked cabs
.var cabV = stamp(List().add(
    "........", "........", "..yyyy..", ".yyyyyy.", ".yyyyyy.", ".bbbbbb.", ".bbbbbb.", ".yyyyyy.",
    ".yyyyyy.", ".yywwyy.", ".yyyyyy.", ".yyyyyy.", ".yyyyyy.", ".yyyyyy.", ".yyyyyy.", ".bbbbbb.",
    ".yyyyyy.", ".yyyyyy.", "..yyyy..", "........", "........", "........", "........", "........"), CL_SOLID)

// ---------------------------------------------------------------- the map
.const MW = 128
.const MH = 128
.var cityMap = List()
.for (var i = 0; i < MW * MH; i++) .eval cityMap.add(WALLCH)
.function mset(x, y, c) {
    .if (x >= 0 && x < MW && y >= 0 && y < MH) .eval cityMap.set(y * MW + x, c)
    .return 0
}
.function mget(x, y) { .return cityMap.get(y * MW + x) }
.function mfill(x0, y0, w, h, c) {
    .for (var y = y0; y < y0 + h; y++) .for (var x = x0; x < x0 + w; x++) .eval mset(x, y, c)
    .return 0
}
.function mstamp(x0, y0, st) {
    .for (var y = 0; y < st.size(); y++) .for (var x = 0; x < st.get(0).size(); x++) .eval mset(x0 + x, y0 + y, st.get(y).get(x))
    .return 0
}
.function nine(x0, y0, w, h, st) {
    .for (var j = 0; j < h; j++) {
        .for (var i = 0; i < w; i++) {
            .var cx = (i == 0) ? 0 : ((i == w - 1) ? 2 : 1)
            .var cy = (j == 0) ? 0 : ((j == h - 1) ? 2 : 1)
            .eval mset(x0 + i, y0 + j, st.get(cy).get(cx))
        }
    }
    .return 0
}

.var AVX = List().add(13, 45, 77, 109)                     // avenues: 6 columns wide
.var STY = List()                                           // streets: 4 rows high
.for (var j = 0; j < 8; j++) .eval STY.add(6 + 16 * j)

// roads
.for (var k = 0; k < AVX.size(); k++) .eval mfill(AVX.get(k), 2, 6, 124, ROADCH)
.for (var j = 0; j < STY.size(); j++) .eval mfill(2, STY.get(j), 124, 4, ROADCH)
.function nearStreet(y) {
    .for (var j = 0; j < STY.size(); j++) .if (y >= STY.get(j) - 1 && y <= STY.get(j) + 4) .return true
    .return false
}
.function nearAvenue(x) {
    .for (var k = 0; k < AVX.size(); k++) .if (x >= AVX.get(k) - 1 && x <= AVX.get(k) + 6) .return true
    .return false
}
// markings: double yellow on the avenues, dashes on the streets, crosswalks
.for (var k = 0; k < AVX.size(); k++) {
    .var ax = AVX.get(k)
    .for (var y = 2; y < 126; y++) {
        .if (!nearStreet(y)) {
            .eval mset(ax + 2, y, AVL)
            .eval mset(ax + 3, y, AVR)
        }
    }
    .for (var j = 0; j < STY.size(); j++) {
        .eval mfill(ax, STY.get(j) - 1, 6, 1, ZEB_V)
        .eval mfill(ax, STY.get(j) + 4, 6, 1, ZEB_V)
    }
}
.for (var j = 0; j < STY.size(); j++) {
    .var sy = STY.get(j)
    .for (var x = 2; x < 126; x++) {
        .if (!nearAvenue(x) && mod(floor(x / 2), 2) == 0) .eval mset(x, sy + 1, STDASH)
    }
    .for (var k = 0; k < AVX.size(); k++) {
        .eval mfill(AVX.get(k) - 1, sy, 1, 4, ZEB_H)
        .eval mfill(AVX.get(k) + 6, sy, 1, 4, ZEB_H)
    }
}

// lots between the roads
.var LX0 = List().add(2, 19, 51, 83, 115)
.var LX1 = List().add(12, 44, 76, 108, 125)
.var LY0 = List().add(2, 10, 26, 42, 58, 74, 90, 106, 122)
.var LY1 = List().add(5, 21, 37, 53, 69, 85, 101, 117, 125)

.function buildings(bx0, by0, bw, bh) {
    .var x = bx0
    .while (x < bx0 + bw) {
        .var w = 4 + rnd(4)
        .if (bx0 + bw - (x + w) < 3) .eval w = bx0 + bw - x
        .var style = rnd(3)
        .eval nine(x, by0, w, bh, roofs.get(style))
        .if (style == 0 && w >= 4 && bh >= 5 && rnd(3) != 0) {
            .eval mstamp(x + 1 + rnd(w - 3), by0 + 1 + rnd(bh - 4), TANK)
        }
        .eval x = x + w
    }
    .return 0
}

// banks: (lot column, lot row); doors face the street below
.var bankLots = List().add(List().add(1, 1), List().add(3, 1), List().add(2, 3), List().add(1, 4),
                           List().add(3, 4), List().add(2, 6), List().add(1, 7), List().add(3, 7))
.var parkLots = List().add(List().add(1, 2), List().add(3, 6))
.function isLot(list, kx, ky) {
    .for (var i = 0; i < list.size(); i++) .if (list.get(i).get(0) == kx && list.get(i).get(1) == ky) .return i
    .return -1
}
.var bankDoorX = List()          // door centre, world pixels
.var bankDoorY = List()          // a spot on the sidewalk just below the door
.for (var i = 0; i < bankLots.size(); i++) {
    .eval bankDoorX.add(0)
    .eval bankDoorY.add(0)
}

.for (var ky = 0; ky < LY0.size(); ky++) {
    .for (var kx = 0; kx < LX0.size(); kx++) {
        .var x0 = LX0.get(kx)
        .var x1 = LX1.get(kx)
        .var y0 = LY0.get(ky)
        .var y1 = LY1.get(ky)
        .eval mfill(x0, y0, x1 - x0 + 1, y1 - y0 + 1, WALK)
        .for (var n = 0; n < 3; n++) .eval mset(x0 + rnd(x1 - x0 + 1), y0 + rnd(y1 - y0 + 1), WALK2)
        .var bx0 = x0 + ((x0 > 2) ? 2 : 0)
        .var bx1 = x1 - ((x1 < 125) ? 2 : 0)
        .var by0 = y0 + ((y0 > 2) ? 2 : 0)
        .var by1 = y1 - ((y1 < 125) ? 2 : 0)
        .var bw = bx1 - bx0 + 1
        .var bh = by1 - by0 + 1
        .if (by1 < 125) .eval mset(bx0 + 1 + rnd(bw - 2), by1 + 2, HYDRANT)
        .var b = isLot(bankLots, kx, ky)
        .var p = isLot(parkLots, kx, ky)
        .if (b >= 0) {
            .var bankx = bx0 + floor((bw - 10) / 2)
            .eval buildings(bx0, by0, bankx - bx0, bh)
            .eval nine(bankx, by0, 10, bh, roofBank)
            .eval buildings(bankx + 10, by0, bx1 - bankx - 9, bh)
            .eval mstamp(bankx + 3, by0 + 1, BANKWORD)
            .eval mstamp(bankx + 4, by0 + 3, bankSign)
            .eval mstamp(bankx + 4, by0 + bh - 1, bankDoor)
            .eval bankDoorX.set(b, (bankx + 5) * 8)
            .eval bankDoorY.set(b, (by0 + bh) * 8 + 6)
        } else {
        .if (p >= 0) {
            .eval mfill(bx0, by0, bw, bh, ROADCH)
            .for (var x = bx0; x < bx0 + bw - 2; x = x + 3) {
                .eval mfill(x, by0, 1, 3, STALL)
                .eval mfill(x, by0 + bh - 3, 1, 3, STALL)
                // half the top stalls and a quarter of the bottom ones taken:
                // room to drive in (same random calls, the city stays the same)
                .if (rnd(4) >= 2) .eval mstamp(x + 1, by0, cabV)
                .if (rnd(4) == 0) .eval mstamp(x + 1, by0 + bh - 3, cabV)
            }
        } else {
            .eval buildings(bx0, by0, bw, bh)
        }
        }
    }
}

// parked cabs along the avenue curbs, manholes on the roads
.for (var k = 0; k < AVX.size(); k++) {
    .var ax = AVX.get(k)
    .for (var j = 0; j < STY.size() - 1; j++) {
        .var ys = STY.get(j) + 6
        // never side by side: left curb in the upper half of the block,
        // right curb in the lower half, so a car always fits between them
        .if (rnd(3) != 0) .eval mstamp(ax, ys + rnd(2), cabV)
        .if (rnd(3) != 0) .eval mstamp(ax + 4, ys + 5 + rnd(2), cabV)
    }
}
.for (var n = 0; n < 24; n++) {
    .var x = AVX.get(rnd(4)) + 1 + rnd(3)
    .var y = 2 + rnd(120)
    .if (mget(x, y) == ROADCH && mget(x + 1, y) == ROADCH) .eval mstamp(x, y, MANHOLE)
}

.var CITY_CHARS = chars.size()

// ---------------------------------------------------------------- comic bubbles
// '.' = grey halo, b = outline/letters, y = fill (color RAM per bubble),
// w = letter shadow.
.var B_TL = one(rows8("....", "....", "..bb", ".byy", "byyy", "byyy", "byyy", "byyy"), CL_FREE)
.var B_T = one(rows8("....", "....", "bbbb", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy"), CL_FREE)
.var B_TS = one(rows8("..b.", ".byb", "byyy", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy"), CL_FREE)
.var B_TR = one(rows8("....", "....", "bb..", "yyb.", "yyyb", "yyyb", "yyyb", "yyyb"), CL_FREE)
.var B_L = one(rows8("byyy", "byyy", "byyy", "byyy", "byyy", "byyy", "byyy", "byyy"), CL_FREE)
.var B_R = one(rows8("yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyyb"), CL_FREE)
.var B_BL = one(rows8("byyy", "byyy", "byyy", "byyy", "byyy", ".byy", "..bb", "...."), CL_FREE)
.var B_B = one(rows8("yyyy", "yyyy", "yyyy", "yyyy", "yyyy", "bbbb", "....", "...."), CL_FREE)
.var B_BS = one(rows8("yyyy", "yyyy", "yyyy", "yyyy", "yyyy", "byyy", ".byb", "..b."), CL_FREE)
.var B_BR = one(rows8("yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyb.", "bb..", "...."), CL_FREE)

.var bubbleWords = List().add("KAPOW!", "BLAM!", "ZOWIE!", "WHAM!", "BOOM!", "POW!", "BANG!", "ZAP!",
                              "CRASH!", "BAM!", "SWAG!", "YOINK!", "LOOT!", "CASH!", "KABOOM!", "KACHING!",
                              "BUSTED!", "ESCAPED!", "TOO SLOW!")   // 16-18: messages
.var glyphOrder = ""
.for (var w = 0; w < bubbleWords.size(); w++) {
    .var s = bubbleWords.get(w)
    .for (var i = 0; i < s.size(); i++) {
        .var c = s.charAt(i)
        .var found = false
        .for (var g = 0; g < glyphOrder.size(); g++) .if (glyphOrder.charAt(g) == c) .eval found = true
        .if (!found) .eval glyphOrder = glyphOrder + c
    }
}
.function glyphIndex(c) {
    .for (var g = 0; g < glyphOrder.size(); g++) .if (glyphOrder.charAt(g) == c) .return g
    .return 0
}
.var glTL = List()
.var glTR = List()
.var glBL = List()
.var glBR = List()
.for (var g = 0; g < glyphOrder.size(); g++) {
    .var c = glyphOrder.charAt(g)
    .var art = List()
    .for (var y = 0; y < 16; y++) {
        .var s = ""
        .for (var x = 0; x < 8; x++) {
            .var on = y >= 1 && y <= 14 && fontPix(c, floor(x / 2), floor((y - 1) / 2))
            .var sh = x >= 1 && y >= 2 && y <= 15 && fontPix(c, floor((x - 1) / 2), floor((y - 2) / 2))
            .eval s = s + (on ? "b" : (sh ? "w" : "y"))
        }
        .eval art.add(s)
    }
    .var st = stamp(art, CL_FREE)
    .eval glTL.add(st.get(0).get(0))
    .eval glTR.add(st.get(0).get(1))
    .eval glBL.add(st.get(1).get(0))
    .eval glBR.add(st.get(1).get(1))
}
.var wordStart = List()
.var wordLen = List()
.var wordGlyphs = List()
.for (var w = 0; w < bubbleWords.size(); w++) {
    .var s = bubbleWords.get(w)
    .eval wordStart.add(wordGlyphs.size())
    .eval wordLen.add(s.size())
    .for (var i = 0; i < s.size(); i++) .eval wordGlyphs.add(glyphIndex(s.charAt(i)))
}

.print "City characters: " + CITY_CHARS + ", with bubbles: " + chars.size()
.errorif chars.size() > 256, "Too many characters: " + chars.size()

// ---------------------------------------------------------------- skid marks
// per car frame (16 directions): the mark character and the two rear wheels
.var skidFor = List().add(SKID_V, SKID_U, SKID_U, SKID_H, SKID_H, SKID_D, SKID_D, SKID_V)
.var wheelLX = List()
.var wheelLY = List()
.var wheelRX = List()
.var wheelRY = List()
.for (var f = 0; f < 16; f++) {
    .var a = f * PI / 8
    .var dx = sin(a)
    .var dy = -cos(a)
    .var px = cos(a)
    .var py = sin(a)
    .eval wheelLX.add(round(-dx * 7 - px * 4))
    .eval wheelLY.add(round(-dy * 7 - py * 4))
    .eval wheelRX.add(round(-dx * 7 + px * 4))
    .eval wheelRY.add(round(-dy * 7 + py * 4))
}

// ---------------------------------------------------------------- city map colours
// per character: 0 black (the wall around the city), 1 street level (roads,
// sidewalks, parked cabs), 2 building. Banks are painted in at run time.
.var mapCode = List()
.for (var i = 0; i < 256; i++) {
    .var v = 0
    .if (i < CITY_CHARS) .eval v = ((charClass.get(i) & 1) != 0) ? 2 : 1
    .eval mapCode.add(v)
}
.eval mapCode.set(WALLCH, 0)
.for (var y = 0; y < cabV.size(); y++) .for (var x = 0; x < cabV.get(0).size(); x++) .eval mapCode.set(cabV.get(y).get(x), 1)
