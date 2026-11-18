// Boogie Bandit - the city, built at build time by KickAssembler script:
// character set (multicolor), the 128 x 128 character map, the banks and
// the comic bubble characters. boogie.asm emits the data.
//
// Pixel symbols in the art (multicolor, 4 pixels per character):
//   .  asphalt          $d021 (ROAD_COL)
//   w  sidewalk/light   $d022 (WALK_COL)
//   b  brown            $d023 (ROOF_COL)
//   y  colour RAM       one value per screen row: its block row's colour (bandCols)

// the colour of the "y" pixels per block row 0-16 (cyan, purple, green, white,
// yellow; no red: that is the getaway car; 13-16 the suburb, yellow there): boogie.asm sets colour RAM per
// screen row as the camera scrolls up and down (band_tab, band_rows)
.var bandCols = List().add(3, 7, 4, 3, 5, 7, 1, 3, 4, 7, 5, 3, 4, 7, 7, 7, 7)

.const CL_FREE = 0              // class bits: 1 = blocks the car, 2 = blocks the walker
.const CL_SOLID = 3
.const CL_DOOR = 7              // 4 = bank door
.const CL_PAINT = 8             // the spray booth of a paint garage (drivable)
.const SUB_ROW = 13 * 16 - 5    // the suburb: world rows 203-255 (block rows 13-16, SUB_J)
.var inSub = false              // the city builder is drawing a suburb block
.var closeAv = false            // block(): the avenue piece is closed (built over)
.var closeSt = false            // block(): the street piece is closed

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
.var AVL = one(rows8("...w", "...w", "...w", "...w", "...w", "...w", "...w", "...w"), CL_FREE)
.var AVR = one(rows8("w...", "w...", "w...", "w...", "w...", "w...", "w...", "w..."), CL_FREE)
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
// colours the characters have: white, black, black with stripes
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
// a grey car: asphalt with a black outline, white windows
.var carG = stamp(List().add(
    "........", "........", "..bbbb..", ".b....b.", ".b....b.", ".bwwwwb.", ".bwwwwb.", ".b....b.",
    ".b....b.", ".b....b.", ".b....b.", ".b....b.", ".b....b.", ".bwwwwb.", ".b....b.", ".b....b.",
    ".b....b.", ".b....b.", "..bbbb..", "........", "........", "........", "........", "........"), CL_SOLID)
// the colourful ones (cabV, carS) take the colour of their block row
.var parkedCars = List().add(cabV, carW, carG, carB, cabV, carS, carG, carW)
// which car stands at (x, y): from the position, so no extra random calls
// (the rest of the city stays the same)
.function parked(x, y) {
    .var i = mod(x * 5 + y * 3 + floor(y / 7), parkedCars.size())
    .var car = parkedCars.get(i)
    .if (inSub && (i == 1 || i == 2 || i == 6 || i == 7)) .return carB   // (white would be green there)
    .return car
}
// for stealing them: the kinds (colour of the stolen car in boogie.asm,
// kind_col) and per character $80 + kind * 8 + row * 2 + column, else 0
.var carKinds = List().add(cabV, carW, carB, carS, carG)
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

// ---------------------------------------------------------------- the city: blocks
// The city is 256 x 256 characters, built from blocks of 32 x 16: a lot (26
// x 11, top left) with its avenue on the right (columns 26-31) and its
// street below (rows 11-15). Block (i, j) starts at world column 32 i - 13
// and row 16 j - 5, so the roads are where they always were: avenue
// centres x = 128 + 256 k, street centres y = 68 + 128 j. The world is a
// grid of 9 x 17 blocks (the outer ones only partly shown; the two
// characters at each edge of the world are wall, done by map_at). Each
// grid cell names a block design; the designs are drawn here.
.const BW = 32                  // a block: 32 x 16 characters
.const BH = 16
.const GW = 9                   // the grid of blocks
.const GH = 17
.const BLK_X0 = -13             // world column / row of block (0, 0)
.const BLK_Y0 = -5
.var MW = BW
.var MH = BH
.var cityMap = List()
.for (var i = 0; i < BW * BH; i++) .eval cityMap.add(WALK)
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
.const SH = 5                   // streets: 5 rows high (avenues 6 wide)

// the buildings of a lot: city blocks, or houses with lawns in the suburb
.function houses(bx0, by0, bw, bh) {
    .eval mfill(bx0, by0, bw, bh, WALK)
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
    .if (inSub) .return houses(bx0, by0, bw, bh)
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

// the suburb: city characters lose their "w" pixels (green there): road
// markings and the card shop's white turn yellow, the rest grey
.var subKeep = Hashtable()
.eval subKeep.put("" + WALK, true)
.eval subKeep.put("" + WALK2, true)
.eval subKeep.put("" + HYDRANT, true)
.for (var c = 0; c < parkedCars.size(); c++) .for (var y = 0; y < 3; y++) .for (var x = 0; x < 2; x++) .eval subKeep.put("" + parkedCars.get(c).get(y).get(x), true)
.var subYellow = Hashtable()
.eval subYellow.put("" + STDASH, true)
.eval subYellow.put("" + AVL, true)
.eval subYellow.put("" + AVR, true)
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

// the lot inside a block: buildings from column 2, row 2, 22 x 7
.const LBX = 2
.const LBY = 2
.const LBW = 22
.const LBH = 7
.const DOOR_DX = (LBX + floor((LBW - 10) / 2) + 5) * 8      // a door in the middle
.const DOOR_DY = (LBY + LBH) * 8 + 6                        // (on the sidewalk below it)
.const GARAGE_DY = (LBY + LBH - 1) * 8
.const FRIEND_DX = (LBX + 3) * 8 + 4                        // his driveway
.const FRIEND_DY = (LBY + LBH + 1) * 8

// one block design: kind = "office", "bank", "card", "garage", "parking",
// "houses", "friend", "park"; car = a car parked on the avenue (0 none,
// 1 left lane, 2 right lane); sub = in the suburb
.var blocks = List()
.var carSpot = Hashtable()       // design -> a car parked on its avenue (for testing)
.function block(kind, car, sub) {
    .eval inSub = sub
    .for (var i = 0; i < BW * BH; i++) .eval cityMap.set(i, WALK)
    .for (var n = 0; n < 3; n++) .eval mset(rnd(26), rnd(11), WALK2)
    // roads: the avenue, the street, markings, crosswalks
    .eval mfill(26, 0, 6, 16, ROADCH)
    .eval mfill(0, 11, 32, 5, ROADCH)
    .for (var y = 1; y <= 9; y++) {
        .eval mset(28, y, AVL)
        .eval mset(29, y, AVR)
    }
    .eval mfill(26, 0, 6, 1, ZEB_V)
    .eval mfill(26, 10, 6, 1, ZEB_V)
    .for (var x = 1; x <= 24; x++) .if (mod(floor((x + 19) / 2), 2) == 0) .eval mset(x, 13, STDASH)
    .eval mfill(0, 11, 1, 5, ZEB_H)
    .eval mfill(25, 11, 1, 5, ZEB_H)
    .eval mset(LBX + 1 + rnd(LBW - 2), LBY + LBH + 1, HYDRANT)
    .var mx = 27 + rnd(3)
    .var my = 1 + rnd(8)
    .if (rnd(3) == 0) .eval mstamp(mx, my, MANHOLE)
    // a closed road: the avenue piece built over (lot buildings to column
    // 29) or the street piece (sidewalks and a row of buildings in rows 12-14)
    .if (closeAv) .eval mfill(26, 0, 6, 11, WALK)
    .if (closeSt) {
        .eval mfill(0, 11, 26, 5, WALK)
        .eval buildings(LBX, 12, LBW, 3)
    }
    // the lot
    .var cx = LBX + floor((LBW - 10) / 2)
    .if (kind == "office" || kind == "houses") .eval buildings(LBX, LBY, closeAv ? LBW + 6 : LBW, LBH)
    .if (kind == "bank") {
        .eval buildings(LBX, LBY, cx - LBX, LBH)
        .eval nine(cx, LBY, 10, LBH, roofBank)
        .eval buildings(cx + 10, LBY, LBX + LBW - cx - 10, LBH)
        .eval mstamp(cx + 3, LBY + 1, BANKWORD)
        .eval mstamp(cx + 4, LBY + 3, bankSign)
        .eval mstamp(cx + 4, LBY + LBH - 1, bankDoor)
    }
    .if (kind == "card") {
        .eval buildings(LBX, LBY, cx - LBX, LBH)
        .eval nine(cx, LBY, 10, LBH, roofShop)
        .eval buildings(cx + 10, LBY, LBX + LBW - cx - 10, LBH)
        .eval mstamp(cx + 2, LBY + 1, CARDWORD)
        .eval mstamp(cx + 4, LBY + 3, cardSign)
        .eval mstamp(cx + 4, LBY + LBH - 1, bankDoor)
    }
    .if (kind == "garage") {
        .eval buildings(LBX, LBY, cx - LBX, LBH)
        .eval nine(cx, LBY, 10, LBH, roofC)
        .eval buildings(cx + 10, LBY, LBX + LBW - cx - 10, LBH)
        .eval mstamp(cx + 2, LBY + 1, PAINTWORD)
        .eval mstamp(cx + 3, LBY + LBH - 3, paintBay)
    }
    .if (kind == "parking") {
        .eval mfill(LBX, LBY, LBW, LBH, ROADCH)
        .for (var x = LBX; x < LBX + LBW - 2; x = x + 3) {
            .eval mfill(x, LBY, 1, 3, STALL)
            .if (rnd(4) >= 2) .eval mstamp(x + 1, LBY, parked(x, LBY))
        }
    }
    .if (kind == "friend") {
        .eval mstamp(LBX + 1, LBY, friendHouse)
        .for (var y = LBY + 4; y <= LBY + LBH + 1; y++) {
            .eval mset(LBX + 2, y, DRIVE_L)
            .eval mset(LBX + 3, y, DRIVE)
            .eval mset(LBX + 4, y, DRIVE_R)
        }
        .eval mstamp(LBX + 8, LBY + 4, TREE)
        .eval houses(LBX + 11, LBY, LBW - 11, LBH)
    }
    .if (kind == "park") {
        .for (var n = 0; n < 7; n++) .eval mstamp(LBX + rnd(LBW - 2), LBY + rnd(LBH - 1), TREE)
        .eval mfill(LBX, LBY + LBH, LBW, 1, HEDGE)
    }
    .var cy = 2 + rnd(4)
    .if (car == 1) {
        .eval mstamp(26, cy, parked(26, 2))
        .eval carSpot.put("" + blocks.size(), List().add(26, cy))
    }
    .if (car == 2) .eval mstamp(30, 2 + rnd(4), parked(30, 6))
    .if (sub) .for (var i = 0; i < BW * BH; i++) .eval cityMap.set(i, subVariant(cityMap.get(i)))
    .var b = List()
    .for (var i = 0; i < BW * BH; i++) .eval b.add(cityMap.get(i))
    .eval blocks.add(b)
    .return blocks.size() - 1
}
// the designs
.var dOffice = List()
.eval dOffice.add(block("office", 0, false))
.eval dOffice.add(block("office", 1, false))
.eval dOffice.add(block("office", 0, false))
.eval dOffice.add(block("office", 2, false))
.eval dOffice.add(block("office", 0, false))
.eval dOffice.add(block("office", 1, false))
.eval dOffice.add(block("office", 2, false))
.var dBank = List()
.eval dBank.add(block("bank", 0, false))
.eval dBank.add(block("bank", 2, false))
.var dCard = List()
.eval dCard.add(block("card", 1, false))
.eval dCard.add(block("card", 0, false))
.var dGarage = block("garage", 0, false)
.var dParking = List()
.eval dParking.add(block("parking", 0, false))
.eval dParking.add(block("parking", 1, false))
.var dHouses = List()
.eval dHouses.add(block("houses", 0, true))
.eval dHouses.add(block("houses", 1, true))
.eval dHouses.add(block("houses", 2, true))
.var dSubPark = block("park", 0, true)
.var dFriend = block("friend", 0, true)
.var dSubBank = block("bank", 0, true)
.var dSubCard = block("card", 2, true)

// the grid: what stands where. Targets, garages and the friend's house
// only in whole blocks (not at the edge of the world).
.const SUB_J = 13               // block rows 13-16: the suburb
.const NCLOSED = 14             // closed road pieces in the city
.const START_X = 81 * 8         // where the car starts (on an avenue: never a closed piece)
.const START_Y = 62 * 8
.var grid = List()
.for (var i = 0; i < GW * GH; i++) .eval grid.add(-1)
.function gset(i, j, d) {
    .eval grid.set(j * GW + i, d)
    .return 0
}
.function gget(i, j) { .return grid.get(j * GW + i) }
.var bankDoorX = List()          // door centre, world pixels (banks 0-15, card shops 16-31)
.var bankDoorY = List()          // a spot on the sidewalk just below the door
.var garageX = List()            // middle of the spray booth, world pixels
.var garageY = List()
.function blockPX(i) { .return (i * BW + BLK_X0) * 8 }
.function blockPY(j) { .return (j * BH + BLK_Y0) * 8 }
// free inner blocks (city and suburb), shuffled
.function shuffled(l) {
    .for (var n = l.size() - 1; n > 0; n--) {
        .var k = rnd(n + 1)
        .var t = l.get(n)
        .eval l.set(n, l.get(k))
        .eval l.set(k, t)
    }
    .return l
}
.var cityFree = List()
.for (var j = 1; j < SUB_J; j++) .for (var i = 1; i < GW - 1; i++) .eval cityFree.add(i + j * GW)
.eval shuffled(cityFree)
.var subFree = List()
.for (var j = SUB_J; j < GH - 1; j++) .for (var i = 1; i < GW - 1; i++) .if (!(i == 1 && j == 15)) .eval subFree.add(i + j * GW)
.eval shuffled(subFree)
.var cp = 0
.var sp = 0
// 13 banks and 13 card shops in the city, 3 of each in the suburb
.for (var t = 0; t < 32; t++) {
    .var inS = mod(t, 16) >= 13
    .var g = 0
    .if (inS) {
        .eval g = subFree.get(sp)
        .eval sp = sp + 1
    } else {
        .eval g = cityFree.get(cp)
        .eval cp = cp + 1
    }
    .var d = 0
    .if (t < 16) {
        .eval d = inS ? dSubBank : dBank.get(rnd(2))
    } else {
        .eval d = inS ? dSubCard : dCard.get(rnd(2))
    }
    .eval grid.set(g, d)
    .eval bankDoorX.add(blockPX(mod(g, GW)) + DOOR_DX)
    .eval bankDoorY.add(blockPY(floor(g / GW)) + DOOR_DY)
}
.for (var n = 0; n < 6; n++) {
    .var g = cityFree.get(cp)
    .eval cp = cp + 1
    .eval grid.set(g, dGarage)
    .eval garageX.add(blockPX(mod(g, GW)) + DOOR_DX)
    .eval garageY.add(blockPY(floor(g / GW)) + GARAGE_DY)
}
.for (var n = 0; n < 8; n++) {
    .eval grid.set(cityFree.get(cp), dParking.get(rnd(2)))
    .eval cp = cp + 1
}
// the friend's house: block (1, 15), in the suburb
.eval gset(1, 15, dFriend)
.var friendX = blockPX(1) + FRIEND_DX
.var friendY = blockPY(15) + FRIEND_DY
.const GREET_X = blockPX(1) / 8 + LBX + 4 - 8   // the greeting bubble (16 wide): centred over the
.const GREET_Y = blockPY(15) / 8 + LBY - 4      // friend's house, just above it (world characters)
// the rest: offices in the city, houses (now and then a park) in the suburb
.for (var j = 0; j < GH; j++) {
    .for (var i = 0; i < GW; i++) {
        .if (gget(i, j) < 0) {
            .if (j >= SUB_J) {
                .eval gset(i, j, (rnd(5) == 0) ? dSubPark : dHouses.get(rnd(3)))
            } else {
                .eval gset(i, j, dOffice.get(rnd(dOffice.size())))
            }
        }
    }
}


// closed roads: office blocks with their avenue or street piece built over
// (T-junctions, longer ways round). Every crossing loses at most one way, so
// police and cabs (which look down each road at a crossing: npc_choose)
// always have at least two. Not next to the suburb (its grass split needs
// the street row above it free of "w" pixels) or at the edges.
.var seedKeep = seed           // (the rest of the build draws the same random numbers as before)
.eval closeAv = true
.var dNoAv = block("office", 0, false)
.eval closeAv = false
.eval closeSt = true
.var dNoSt = block("office", 0, false)
.eval closeSt = false
.var lost = Hashtable()          // crossings (avenue, street) that lost a way
.var closeList = List()
.for (var j = 1; j < SUB_J - 1; j++) .for (var i = 1; i < GW - 1; i++) .eval closeList.add(i + j * GW)
.eval shuffled(closeList)
.var nClosed = 0
.for (var n = 0; n < closeList.size() && nClosed < NCLOSED; n++) {
    .var g = closeList.get(n)
    .var i = mod(g, GW)
    .var j = floor(g / GW)
    .var isOff = false
    .for (var k = 0; k < dOffice.size(); k++) .if (dOffice.get(k) == grid.get(g)) .eval isOff = true
    .if (g == floor((START_X / 8 + 13) / 32) + floor((START_Y / 8 + 5) / 16) * GW) .eval isOff = false
    .if (isOff) {
        .var av = rnd(2) == 0
        .var c1 = av ? (toIntString(i) + "," + toIntString(j - 1)) : (toIntString(i - 1) + "," + toIntString(j))
        .var c2 = toIntString(i) + "," + toIntString(j)
        .if (!lost.containsKey(c1) && !lost.containsKey(c2)) {
            .eval lost.put(c1, true)
            .eval lost.put(c2, true)
            .eval grid.set(g, av ? dNoAv : dNoSt)
            .eval nClosed = nClosed + 1
        }
    }
}
.eval seed = seedKeep
.print "Closed roads: " + nClosed
.const NBLOCKS = blocks.size()
.const NPRIV = 4                // spare blocks: private copies of blocks a car was stolen from
.errorif NBLOCKS + NPRIV > 31, "too many block designs: " + NBLOCKS
.var WALL_SUB = subVariant(WALLCH)
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
                              "SAFE! LEVEL UP!", "HOT CAR!", "LOSE THE COPS!",   // 19-21: at the friend's house
                              "       ")   // 22: blank, for the greeting (W_GREET)
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

// for testing: where the first car parked on an avenue is (world pixels)
.for (var g = 0; g < GW * GH; g++) {
    .if (carSpot.containsKey("" + grid.get(g)) && mod(g, GW) > 0 && floor(g / GW) > 0) {
        .var sp = carSpot.get("" + grid.get(g))
        .print "A parked car: x " + toHexString(blockPX(mod(g, GW)) + sp.get(0) * 8) + ", y " + toHexString(blockPY(floor(g / GW)) + sp.get(1) * 8)
        .eval g = GW * GH
    }
}

// ---------------------------------------------------------------- the greeting
// The friend greets Vinnie in a white bubble over his house, in a small
// blocky font with a drop shadow (3 x 6 letters, the shadow one pixel right
// and down in asphalt grey). Its 15 characters borrow GREET_CH.. for the
// time it is shown: city characters that never appear in the suburb (the
// screen there shows only suburb blocks); chase.asm saves them in MMBUF.
.var subUsed = Hashtable()
.var subDesigns = List().add(dHouses.get(0), dHouses.get(1), dHouses.get(2), dSubPark, dFriend, dSubBank, dSubCard)
.for (var d = 0; d < subDesigns.size(); d++) .for (var i = 0; i < BW * BH; i++) .eval subUsed.put("" + blocks.get(subDesigns.get(d)).get(i), true)
.var anywhere = List().add(WALLCH, WALL_SUB, ROADCH, SKID_V, SKID_H, SKID_U, SKID_D)   // (drawn at run time)
.for (var i = 0; i < anywhere.size(); i++) .eval subUsed.put("" + anywhere.get(i), true)
.var runS = 0
.var runL = 0
.var greetStart = -1
.for (var c = 1; c < CITY_CHARS && greetStart < 0; c++) {
    .if (subUsed.containsKey("" + c)) {
        .eval runL = 0
    } else {
        .if (runL == 0) .eval runS = c
        .eval runL = runL + 1
        .if (runL == 15) .eval greetStart = runS
    }
}
.errorif greetStart < 0, "no 15 city-only characters in a row for the greeting"
.const GREET_CH = greetStart
.var greetLetters = @"AYVINE!HOWUD'?"          // + 14: blank
.var greetFont = Hashtable()
.function gfont(c, r0, r1, r2, r3, r4, r5) { .eval greetFont.put(c, List().add(r0, r1, r2, r3, r4, r5)) }
.eval gfont("A", ".#.", "#.#", "#.#", "###", "#.#", "#.#")
.eval gfont("Y", "#.#", "#.#", ".#.", ".#.", ".#.", ".#.")
.eval gfont("V", "#.#", "#.#", "#.#", "#.#", "#.#", ".#.")
.eval gfont("I", "###", ".#.", ".#.", ".#.", ".#.", "###")
.eval gfont("N", "##.", "#.#", "#.#", "#.#", "#.#", "#.#")
.eval gfont("E", "###", "#..", "##.", "#..", "#..", "###")
.eval gfont("!", ".#.", ".#.", ".#.", ".#.", "...", ".#.")
.eval gfont("H", "#.#", "#.#", "###", "#.#", "#.#", "#.#")
.eval gfont("O", ".#.", "#.#", "#.#", "#.#", "#.#", ".#.")
.eval gfont("W", "#.#", "#.#", "#.#", "###", "###", "#.#")
.eval gfont("U", "#.#", "#.#", "#.#", "#.#", "#.#", "###")
.eval gfont("D", "##.", "#.#", "#.#", "#.#", "#.#", "##.")
.eval gfont(@"'", ".#.", ".#.", "...", "...", "...", "...")
.eval gfont("?", "##.", "..#", ".#.", ".#.", "...", ".#.")
.function gpix(c, x, y) {
    .if (x < 0 || x > 2 || y < 0 || y > 5) .return false
    .return greetFont.get(c).get(y).charAt(x) == "#"
}
.var greetGlyphs = List()                       // 7 rows a letter (the 8th is blank)
.for (var g = 0; g < greetLetters.size(); g++) {
    .var c = greetLetters.charAt(g)
    .for (var y = 0; y < 7; y++) {
        .var v = 0
        .for (var x = 0; x < 4; x++) {
            .var px = gpix(c, x, y) ? 2 : (gpix(c, x - 1, y - 1) ? 0 : 3)   // b, shadow, colour RAM (white)
            .eval v = v * 4 + px
        }
        .eval greetGlyphs.add(v)
    }
}
.function greetCode(c) {
    .for (var i = 0; i < greetLetters.size(); i++) .if (greetLetters.charAt(i) == c) .return GREET_CH + i
    .return GREET_CH + 14
}
.var greetT1 = @" AYY VINNIE!  "
.var greetT2 = @"HOW YOU DOIN'?"
.errorif greetT1.size() != 14 || greetT2.size() != 14, "the greeting lines are 14 characters"
.print "Greeting characters: " + GREET_CH + "-" + (GREET_CH + 14)
