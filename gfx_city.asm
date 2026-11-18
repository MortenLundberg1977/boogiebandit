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
.const CL_PAINT = 8             // the spray booth of a paint garage (drivable)
.const SUB_ROW = 107            // the suburb: map rows 107-127 (see "the suburb")

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
.var STDASH = one(rows8("....", "....", "....", "....", "wwww", "....", "....", "...."), CL_FREE)   // the middle row of a 5-row street: line at y + 4
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

// card shop: white letters on black, a playing card, a striped awning
.var cardText = List()
.for (var y = 0; y < 8; y++) {
    .var s = ""
    .for (var i = 0; i < 5; i++) .for (var x = 0; x < 4; x++) .eval s = s + ((y >= 1 && fontPix("CARDS".charAt(i), x, y - 1)) ? "w" : "b")
    .eval cardText.add(s)
}
.var CARDWORD = stamp(cardText, CL_SOLID)
.var cardSign = stamp(List().add(
    "bbbbbbbb", "bbwwwwbb", "bbwbbwbb", "bbwbbwbb", "bbwbbwbb", "bbwbbwbb", "bbwyywbb", "bbwyywbb",
    "bbwyywbb", "bbwyywbb", "bbwbbwbb", "bbwbbwbb", "bbwbbwbb", "bbwbbwbb", "bbwwwwbb", "bbbbbbbb"), CL_SOLID)
.var roofShop = stamp(List().add(
    "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb",
    "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb",
    "bbbbbbbbbbbb", "wwwwwwwwwwww", "yywwyywwyyww", "yywwyywwyyww", "yywwyywwyyww", "yywwyywwyyww", "wwwwwwwwwwww", "bbbbbbbbbbbb"), CL_SOLID)

// paint garage: a sign on the roof and an open spray booth at the front
.var paintText = List()
.for (var y = 0; y < 8; y++) {
    .var s = ""
    .for (var i = 0; i < 5; i++) .for (var x = 0; x < 4; x++) .eval s = s + ((y >= 1 && fontPix("PAINT".charAt(i), x, y - 1)) ? "y" : "b")
    .eval paintText.add(s)
}
.var PAINTWORD = stamp(paintText, CL_SOLID)
.var paintBay = stamp(List().add(
    "wwwwwwwwwwwwwwww", "wbybbbybbybbbybw", "wbybbbybbybbbybw", "wbbbbbbbbbbbbbbw", "wbbbwbbbbbbwbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw",
    "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw",
    "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "wbbbbbbbbbbbbbbw", "yybbyybbyybbyybb", "yybbyybbyybbyybb"), CL_PAINT)

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
// other parked cars: the city has one colour RAM value, so they use the
// colours the characters have: white, black, black with yellow stripes
.var carW = stamp(List().add(
    "........", "........", "..wwww..", ".wwwwww.", ".wwwwww.", ".bbbbbb.", ".bbbbbb.", ".wwwwww.",
    ".wwwwww.", ".wwwwww.", ".wwwwww.", ".wwwwww.", ".wwwwww.", ".bbbbbb.", ".bbbbbb.", ".wwwwww.",
    ".wwwwww.", ".wwwwww.", "..wwww..", "........", "........", "........", "........", "........"), CL_SOLID)
.var carB = stamp(List().add(
    "........", "........", "..bbbb..", ".bbbbbb.", ".bbbbbb.", ".bwwwwb.", ".bwwwwb.", ".bbbbbb.",
    ".bbbbbb.", ".bbbbbb.", ".bbbbbb.", ".bbbbbb.", ".bbbbbb.", ".bwwwwb.", ".bbbbbb.", ".bbbbbb.",
    ".bbbbbb.", ".bbbbbb.", "..bbbb..", "........", "........", "........", "........", "........"), CL_SOLID)
.var carS = stamp(List().add(
    "........", "........", "..byyb..", ".bbyybb.", ".bbyybb.", ".bwwwwb.", ".bwwwwb.", ".bbyybb.",
    ".bbyybb.", ".bbyybb.", ".bbyybb.", ".bbyybb.", ".bbyybb.", ".bwwwwb.", ".bbyybb.", ".bbyybb.",
    ".bbyybb.", ".bbyybb.", "..byyb..", "........", "........", "........", "........", "........"), CL_SOLID)
.var parkedCars = List().add(cabV, carW, cabV, carB, carW, carS, cabV, carB)
// which car stands at (x, y): from the position, so no extra random calls
// (the rest of the city stays the same)
.function parked(x, y) {
    .var i = mod(x * 5 + y * 3 + floor(y / 7), parkedCars.size())
    .if (y >= SUB_ROW && (i == 1 || i == 4)) .return carB     // (a white car would be green there)
    .var car = parkedCars.get(i)
    .return car
}
// for stealing them: the kinds (colour of the stolen car in boogie.asm,
// kind_col) and per character $80 + kind * 8 + row * 2 + column, else 0
.var carKinds = List().add(cabV, carW, carB, carS)
.var parkInfo = List()
.for (var i = 0; i < 256; i++) .eval parkInfo.add(0)
.for (var k = 0; k < carKinds.size(); k++) {
    .for (var r = 0; r < 3; r++) {
        .for (var c = 0; c < 2; c++) {
            .var ch = carKinds.get(k).get(r).get(c)
            .var v = $80 + k * 8 + r * 2 + c
            .errorif parkInfo.get(ch) != 0 && parkInfo.get(ch) != v, "a parked car character is shared"
            .eval parkInfo.set(ch, v)
        }
    }
}

// ---------------------------------------------------------------- the suburb
// The south edge of the map (rows SUB_ROW-127) is the outskirts: lawns,
// houses, trees and the friend's house. A raster split (boogie.asm) turns
// $d022 green from that row down, so there "w" is grass. City characters
// placed there that have "w" pixels get a copy without them (subVariant).

.const CL_SAFE = 16             // the friend's driveway (drivable)
.var subChars = Hashtable()     // characters made for the suburb (keep their "w")
.function subStamp(rows, cls) {
    .var st = stamp(rows, cls)
    .for (var y = 0; y < st.size(); y++) .for (var x = 0; x < st.get(0).size(); x++) .eval subChars.put("" + st.get(y).get(x), true)
    .return st
}
// a hipped roof seen from above, w x h characters, on a 1 pixel lawn border:
// faces f (north/south) and s (east/west), hips and ridge in l, eaves in e
.function roofArt(wc, hc, f, s, l, e) {
    .var W = wc * 4
    .var H = hc * 8
    .var rows = List()
    .for (var y = 0; y < H; y++) {
        .var str = ""
        .for (var x = 0; x < W; x++) {
            .var c = "w"
            .if (x >= 1 && x <= W - 2 && y >= 1 && y <= H - 2) {
                .var ax = min(x - 1, W - 2 - x) * 2
                .var ay = min(y - 1, H - 2 - y)
                .eval c = (ax < ay) ? s : f
                .if (abs(ax - ay) <= 1) .eval c = l
                .if (ax > ay && (y == floor(H / 2) - 1 || y == floor(H / 2))) .eval c = l
                .if (ax > ay && c == f && mod(y, 3) == 0 && mod(x, 2) == 0 && f == "b") .eval c = "."
                .if (x == 1 || x == W - 2 || y == 1 || y == H - 2) .eval c = e
            }
            .eval str = str + c
        }
        .eval rows.add(str)
    }
    .return rows
}
.var houseA = subStamp(roofArt(4, 4, "b", "b", ".", "b"), CL_SOLID)
.var houseB = subStamp(roofArt(5, 4, "b", "b", ".", "b"), CL_SOLID)
.var friendHouse = subStamp(roofArt(6, 4, "y", "y", "b", "b"), CL_SOLID)
// the friend's driveway: grey with a white-ish (green) edge, drivable
.var DRIVE = subStamp(List().add("....", "....", "....", "....", "....", "....", "....", "...."), CL_SAFE).get(0).get(0)
.var DRIVE_L = subStamp(List().add("w...", "w...", "w...", "w...", "w...", "w...", "w...", "w..."), CL_SAFE).get(0).get(0)
.var DRIVE_R = subStamp(List().add("...w", "...w", "...w", "...w", "...w", "...w", "...w", "...w"), CL_SAFE).get(0).get(0)
// a tree (2 x 2): a dark round crown with green leaves showing through
.var treeArt = List()
.for (var y = 0; y < 16; y++) {
    .var s = ""
    .for (var x = 0; x < 8; x++) {
        .var dx = x * 2 + 1 - 8
        .var dy = y + 0.5 - 8
        .var d = sqrt(dx * dx + dy * dy)
        .var c = "w"
        .if (d < 7.4) .eval c = "b"
        .if (d < 6 && mod(x + y * 3, 5) == 0) .eval c = "w"
        .eval s = s + c
    }
    .eval treeArt.add(s)
}
.var TREE = subStamp(treeArt, CL_SOLID)
.var HEDGE = subStamp(List().add("wbwb", "bbbb", "bwbb", "bbbb", "bbwb", "bbbb", "wbbw", "wwww"), CL_SOLID).get(0).get(0)

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
.const SH = 5                                               // streets: 5 rows high
.var STY = List()
.for (var j = 0; j < 8; j++) .eval STY.add(6 + 16 * j)

// roads
.for (var k = 0; k < AVX.size(); k++) .eval mfill(AVX.get(k), 2, 6, 124, ROADCH)
.for (var j = 0; j < STY.size(); j++) .eval mfill(2, STY.get(j), 124, SH, ROADCH)
.function nearStreet(y) {
    .for (var j = 0; j < STY.size(); j++) .if (y >= STY.get(j) - 1 && y <= STY.get(j) + SH) .return true
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
        .eval mfill(ax, STY.get(j) + SH, 6, 1, ZEB_V)
    }
}
.for (var j = 0; j < STY.size(); j++) {
    .var sy = STY.get(j)
    .for (var x = 2; x < 126; x++) {
        .if (!nearAvenue(x) && mod(floor(x / 2), 2) == 0) .eval mset(x, sy + floor(SH / 2), STDASH)
    }
    .for (var k = 0; k < AVX.size(); k++) {
        .eval mfill(AVX.get(k) - 1, sy, 1, SH, ZEB_H)
        .eval mfill(AVX.get(k) + 6, sy, 1, SH, ZEB_H)
    }
}

// lots between the roads
.var LX0 = List().add(2, 19, 51, 83, 115)
.var LX1 = List().add(12, 44, 76, 108, 125)
.var LY0 = List().add(2, 11, 27, 43, 59, 75, 91, 107, 123)    // after a street and its crosswalk
.var LY1 = List().add(5, 21, 37, 53, 69, 85, 101, 117, 125)

// houses with lawns and trees instead of city blocks (in the suburb)
.function houses(bx0, by0, bw, bh) {
    .eval mfill(bx0, by0, bw, bh, WALK)
    .if (bh < 4) .return mfill(bx0, by0 + bh - 1, bw, 1, HEDGE)     // backyards: a hedge
    .var x = bx0
    .while (x + 4 <= bx0 + bw) {
        .var big = (x + 5 <= bx0 + bw) && rnd(2) == 0
        .eval mstamp(x, by0, big ? houseB : houseA)
        .if (bh >= 7 && rnd(3) != 0) .eval mstamp(x + 1 + rnd(2), by0 + bh - 2, TREE)
        .eval x = x + (big ? 5 : 4) + rnd(2)
    }
    .return 0
}

.function buildings(bx0, by0, bw, bh) {
    .if (by0 >= SUB_ROW) .return houses(bx0, by0, bw, bh)
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
.var garageLots = List().add(List().add(3, 2), List().add(2, 4), List().add(1, 6))
// card shops (robbed like banks: targets 8-15, smaller loot)
.var cardLots = List().add(List().add(2, 1), List().add(1, 3), List().add(3, 5), List().add(2, 7),
                           List().add(2, 2), List().add(3, 3), List().add(1, 5), List().add(2, 5))
.const FRIEND_LOT_X = 0          // the friend's house: lot (0, 7), in the suburb
.const FRIEND_LOT_Y = 7
.var friendX = 0                 // the middle of his driveway, world pixels
.var friendY = 0
.var garageX = List()            // middle of the spray booth, world pixels
.var garageY = List()
.function isLot(list, kx, ky) {
    .for (var i = 0; i < list.size(); i++) .if (list.get(i).get(0) == kx && list.get(i).get(1) == ky) .return i
    .return -1
}
.var bankDoorX = List()          // door centre, world pixels
.var bankDoorY = List()          // a spot on the sidewalk just below the door
.for (var i = 0; i < bankLots.size() + cardLots.size(); i++) {
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
        .var g = isLot(garageLots, kx, ky)
        .var cs = isLot(cardLots, kx, ky)
        .if (kx == FRIEND_LOT_X && ky == FRIEND_LOT_Y) {
            // the friend's house: yellow roof, a driveway down to the street
            .eval mfill(bx0, by0, bw, bh + 2, WALK)
            .eval mstamp(bx0 + 1, by0, friendHouse)
            .for (var y = by0 + 4; y <= by1 + 2; y++) {
                .eval mset(bx0 + 2, y, DRIVE_L)
                .eval mset(bx0 + 3, y, DRIVE)
                .eval mset(bx0 + 4, y, DRIVE_R)
            }
            .eval mstamp(bx0 + bw - 2, by0 + 4, TREE)
            .eval friendX = (bx0 + 3) * 8 + 4
            .eval friendY = (by1 + 1) * 8
        } else {
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
        .if (cs >= 0) {
            .var sx = bx0 + floor((bw - 10) / 2)
            .eval buildings(bx0, by0, sx - bx0, bh)
            .eval nine(sx, by0, 10, bh, roofShop)
            .eval buildings(sx + 10, by0, bx1 - sx - 9, bh)
            .eval mstamp(sx + 2, by0 + 1, CARDWORD)
            .eval mstamp(sx + 4, by0 + 3, cardSign)
            .eval mstamp(sx + 4, by0 + bh - 1, bankDoor)
            .eval bankDoorX.set(bankLots.size() + cs, (sx + 5) * 8)
            .eval bankDoorY.set(bankLots.size() + cs, (by0 + bh) * 8 + 6)
        } else {
        .if (g >= 0) {
            // a paint garage, the spray booth open to the street below
            .var gx = bx0 + floor((bw - 10) / 2)
            .eval buildings(bx0, by0, gx - bx0, bh)
            .eval nine(gx, by0, 10, bh, roofC)
            .eval buildings(gx + 10, by0, bx1 - gx - 9, bh)
            .eval mstamp(gx + 2, by0 + 1, PAINTWORD)
            .eval mstamp(gx + 3, by0 + bh - 3, paintBay)
            .eval garageX.add((gx + 5) * 8)
            .eval garageY.add((by0 + bh - 1) * 8)
        } else {
        .if (p >= 0) {
            .eval mfill(bx0, by0, bw, bh, ROADCH)
            .for (var x = bx0; x < bx0 + bw - 2; x = x + 3) {
                .eval mfill(x, by0, 1, 3, STALL)
                .if (bh >= 8) .eval mfill(x, by0 + bh - 3, 1, 3, STALL)
                // half the top stalls and a quarter of the bottom ones taken:
                // room to drive in (same random calls, the city stays the same)
                .if (rnd(4) >= 2) .eval mstamp(x + 1, by0, parked(x, by0))
                .if (rnd(4) == 0 && bh >= 8) .eval mstamp(x + 1, by0 + bh - 3, parked(x, by0 + bh))   // (lots shorter than 8 rows: one row of stalls)
            }
        } else {
            .eval buildings(bx0, by0, bw, bh)
        }
        }
        }
        }
        }
    }
}

// parked cars along the avenue curbs, manholes on the roads
.for (var k = 0; k < AVX.size(); k++) {
    .var ax = AVX.get(k)
    .for (var j = 0; j < STY.size() - 1; j++) {
        .var ys = STY.get(j) + SH + 2
        // at most one per block, on one side: never one on each side
        .var side = rnd(5)
        .if (side < 2) .eval mstamp(ax, ys + 1 + rnd(3), parked(ax, ys))
        .if (side == 2 || side == 3) .eval mstamp(ax + 4, ys + 1 + rnd(3), parked(ax + 4, ys + 4))
    }
}
.for (var n = 0; n < 24; n++) {
    .var x = AVX.get(rnd(4)) + 1 + rnd(3)
    .var y = 2 + rnd(120)
    .if (mget(x, y) == ROADCH && mget(x + 1, y) == ROADCH) .eval mstamp(x, y, MANHOLE)
}

// the suburb rows: city characters there lose their "w" pixels (green
// there): road markings and the card shop's white turn yellow, the rest grey
.var subKeep = Hashtable()
.eval subKeep.put("" + WALK, true)
.eval subKeep.put("" + WALK2, true)
.eval subKeep.put("" + HYDRANT, true)
.for (var c = 0; c < parkedCars.size(); c++) .for (var y = 0; y < 3; y++) .for (var x = 0; x < 2; x++) .eval subKeep.put("" + parkedCars.get(c).get(y).get(x), true)
.var subYellow = Hashtable()
.eval subYellow.put("" + STDASH, true)
.eval subYellow.put("" + ZEB_H, true)
.eval subYellow.put("" + ZEB_V, true)
.for (var x = 0; x < 5; x++) .eval subYellow.put("" + CARDWORD.get(0).get(x), true)
.for (var y = 0; y < 2; y++) .for (var x = 0; x < 2; x++) .eval subYellow.put("" + cardSign.get(y).get(x), true)
.var subMap = Hashtable()
.function subVariant(c) {
    .var key = "" + c
    .if (subChars.containsKey(key) || subKeep.containsKey(key)) .return c
    .if (subMap.containsKey(key)) .return subMap.get(key)
    .var to = subYellow.containsKey(key) ? 3 : 0
    .var src = chars.get(c)
    .var nb = List()
    .var changed = false
    .for (var i = 0; i < 8; i++) {
        .var v = 0
        .for (var p = 0; p < 4; p++) {
            .var px = (src.get(i) >> (6 - 2 * p)) & 3
            .if (px == 1) {
                .eval px = to
                .eval changed = true
            }
            .eval v = v * 4 + px
        }
        .eval nb.add(v)
    }
    .var n = changed ? addChar(nb, charClass.get(c)) : c
    .eval subMap.put(key, n)
    .return n
}
.for (var y = SUB_ROW; y < MH; y++) .for (var x = 0; x < MW; x++) .eval mset(x, y, subVariant(mget(x, y)))

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
                              "BUSTED!", "ESCAPED!", "TOO SLOW!",   // 16-18: messages
                              "SAFE! LEVEL UP!", "HOT CAR!", "LOSE THE COPS!")   // 19-21: at the friend's house
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
.for (var c = 0; c < parkedCars.size(); c++) .for (var y = 0; y < 3; y++) .for (var x = 0; x < 2; x++) .eval mapCode.set(parkedCars.get(c).get(y).get(x), 1)
// paint garages show yellow on the map: the sign and the booth
.for (var x = 0; x < 5; x++) .eval mapCode.set(PAINTWORD.get(0).get(x), 3)
.for (var y = 0; y < 3; y++) .for (var x = 0; x < 4; x++) .eval mapCode.set(paintBay.get(y).get(x), 3)
// the friend's house shows yellow on the map too
.for (var y = 0; y < 4; y++) .for (var x = 0; x < 6; x++) .eval mapCode.set(friendHouse.get(y).get(x), 3)
.eval mapCode.set(DRIVE, 3)
.eval mapCode.set(DRIVE_L, 3)
.eval mapCode.set(DRIVE_R, 3)

// where the arrow can point (boogie.asm door_xl/...): the banks and card
// shops (0-15), the friend's driveway (16), the paint garages (17-19)
.var goalX = List()
.var goalY = List()
.for (var i = 0; i < bankDoorX.size(); i++) {
    .eval goalX.add(bankDoorX.get(i))
    .eval goalY.add(bankDoorY.get(i))
}
.eval goalX.add(friendX)
.eval goalY.add(friendY)
.for (var i = 0; i < garageX.size(); i++) {
    .eval goalX.add(garageX.get(i))
    .eval goalY.add(garageY.get(i))
}
