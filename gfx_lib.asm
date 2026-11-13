// Boogie Bandit - build-time helpers shared by the graphics scripts:
// random numbers, the game's own fonts (no ROM font anywhere) and the
// RLE packer whose 6502 depacker is `unpack` in boogie.asm.

// ---------------------------------------------------------------- random
.var seed = 1977
.function rnd(n) {
    .eval seed = mod(seed * 75 + 74, 65537)
    .return mod(seed, n)
}

// ---------------------------------------------------------------- 4x7 font
// Chunky capitals and digits, 4 pixels wide. Used for the comic bubbles
// (scaled 2x2), the title logo (scaled up and slanted) and the sprite texts.
.var font4 = Hashtable()
.function glyph(c, r0, r1, r2, r3, r4, r5, r6) {
    .eval font4.put(c, List().add(r0, r1, r2, r3, r4, r5, r6))
    .return 0
}
.eval glyph("A", ".##.", "#..#", "#..#", "####", "#..#", "#..#", "#..#")
.eval glyph("B", "###.", "#..#", "#..#", "###.", "#..#", "#..#", "###.")
.eval glyph("C", ".##.", "#..#", "#...", "#...", "#...", "#..#", ".##.")
.eval glyph("D", "###.", "#..#", "#..#", "#..#", "#..#", "#..#", "###.")
.eval glyph("E", "####", "#...", "#...", "###.", "#...", "#...", "####")
.eval glyph("F", "####", "#...", "#...", "###.", "#...", "#...", "#...")
.eval glyph("G", ".##.", "#..#", "#...", "#.##", "#..#", "#..#", ".###")
.eval glyph("H", "#..#", "#..#", "#..#", "####", "#..#", "#..#", "#..#")
.eval glyph("I", "###.", ".#..", ".#..", ".#..", ".#..", ".#..", "###.")
.eval glyph("J", "..##", "...#", "...#", "...#", "#..#", "#..#", ".##.")
.eval glyph("K", "#..#", "#.#.", "##..", "##..", "#.#.", "#..#", "#..#")
.eval glyph("L", "#...", "#...", "#...", "#...", "#...", "#...", "####")
.eval glyph("M", "#..#", "####", "####", "#..#", "#..#", "#..#", "#..#")
.eval glyph("N", "#..#", "##.#", "##.#", "#.##", "#.##", "#..#", "#..#")
.eval glyph("O", ".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##.")
.eval glyph("P", "###.", "#..#", "#..#", "###.", "#...", "#...", "#...")
.eval glyph("R", "###.", "#..#", "#..#", "###.", "#.#.", "#..#", "#..#")
.eval glyph("S", ".###", "#...", "#...", ".##.", "...#", "...#", "###.")
.eval glyph("T", "###.", ".#..", ".#..", ".#..", ".#..", ".#..", ".#..")
.eval glyph("U", "#..#", "#..#", "#..#", "#..#", "#..#", "#..#", ".##.")
.eval glyph("W", "#..#", "#..#", "#..#", "#..#", "####", "####", "#..#")
.eval glyph("Y", "#..#", "#..#", ".##.", ".#..", ".#..", ".#..", ".#..")
.eval glyph("Z", "####", "...#", "..#.", ".#..", "#...", "#...", "####")
.eval glyph("!", ".#..", ".#..", ".#..", ".#..", ".#..", "....", ".#..")
.eval glyph("-", "....", "....", "....", "###.", "....", "....", "....")
.eval glyph(" ", "....", "....", "....", "....", "....", "....", "....")
.eval glyph("0", ".##.", "#..#", "#.##", "##.#", "#..#", "#..#", ".##.")
.eval glyph("1", ".#..", "##..", ".#..", ".#..", ".#..", ".#..", "###.")
.eval glyph("7", "####", "...#", "..#.", ".#..", ".#..", ".#..", ".#..")
.eval glyph("9", ".##.", "#..#", "#..#", ".###", "...#", "#..#", ".##.")
.function fontPix(c, x, y) {
    .if (x < 0 || x > 3 || y < 0 || y > 6) .return false
    .return font4.get(c).get(y).charAt(x) == "#"
}

// ---------------------------------------------------------------- 3x5 font
// Tiny HUD font (multicolor sprite pixels).
.var font3 = Hashtable()
.function glyph3(c, r0, r1, r2, r3, r4) {
    .eval font3.put(c, List().add(r0, r1, r2, r3, r4))
    .return 0
}
.eval glyph3("0", "###", "#.#", "#.#", "#.#", "###")
.eval glyph3("1", ".#.", "##.", ".#.", ".#.", "###")
.eval glyph3("2", "###", "..#", "###", "#..", "###")
.eval glyph3("3", "###", "..#", ".##", "..#", "###")
.eval glyph3("4", "#.#", "#.#", "###", "..#", "..#")
.eval glyph3("5", "###", "#..", "###", "..#", "###")
.eval glyph3("6", "###", "#..", "###", "#.#", "###")
.eval glyph3("7", "###", "..#", "..#", ".#.", ".#.")
.eval glyph3("8", "###", "#.#", "###", "#.#", "###")
.eval glyph3("9", "###", "#.#", "###", "..#", "###")
.eval glyph3("F", "###", "#..", "##.", "#..", "#..")
.eval glyph3("P", "##.", "#.#", "##.", "#..", "#..")
.eval glyph3("S", ".##", "#..", ".#.", "..#", "##.")
.eval glyph3("C", ".##", "#..", "#..", "#..", ".##")
.eval glyph3("O", ".#.", "#.#", "#.#", "#.#", ".#.")
.eval glyph3("R", "##.", "#.#", "##.", "#.#", "#.#")
.eval glyph3("E", "###", "#..", "##.", "#..", "###")
.eval glyph3(" ", "...", "...", "...", "...", "...")

// ---------------------------------------------------------------- RLE packer
// Control byte c: $00-$7f = c+1 literal bytes follow; $80-$fe = next byte
// repeated c-$7e times (2..128); $ff = end.
.function rlePack(src) {
    .var out = List()
    .var n = src.size()
    .var i = 0
    .while (i < n) {
        .var r = 1
        .while (i + r < n && r < 128 && src.get(i + r) == src.get(i)) .eval r = r + 1
        .if (r >= 3) {
            .eval out.add($80 + r - 2)
            .eval out.add(src.get(i))
            .eval i = i + r
        } else {
            .var j = i
            .var lit = List()
            .var stop = false
            .while (!stop && j < n && lit.size() < 128) {
                .if (j + 2 < n && src.get(j) == src.get(j + 1) && src.get(j) == src.get(j + 2)) {
                    .eval stop = true
                } else {
                    .eval lit.add(src.get(j))
                    .eval j = j + 1
                }
            }
            .eval out.add(lit.size() - 1)
            .for (var k = 0; k < lit.size(); k++) .eval out.add(lit.get(k))
            .eval i = j
        }
    }
    .eval out.add($ff)
    .return out
}
