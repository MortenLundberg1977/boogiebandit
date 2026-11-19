// =====================================================================
// The REU edition: Vinnie ponders which card to steal (build time)
// =====================================================================
// In a card shop the first three comic bubbles are thoughts instead: a white
// cloud over the shop with two lines of text and two small circles trailing
// down to the door. The text uses a small blocky font like the friend's
// greeting (3 x 6 letters, a grey drop shadow one pixel right and down).
// Its characters are borrowed for the 1.8 seconds of thinking from character
// codes that are not on the screen at that moment (the overlay in boogie.asm
// looks at the screen), so it works anywhere in the city.
// Glyph order: 0-9 the cloud's edges, 10-11 the trail circles, 12 blank,
// then the letters (only the ones the thoughts use).

// one multicolor character from 8 rows of 4 pixels: . asphalt, w light
// grey (not used: green in the suburb), b black, y colour RAM (white)
.function thChar(r0, r1, r2, r3, r4, r5, r6, r7) {
    .var rows = List().add(r0, r1, r2, r3, r4, r5, r6, r7)
    .var out = List()
    .for (var r = 0; r < 8; r++) {
        .var v = 0
        .for (var p = 0; p < 4; p++) {
            .var c = rows.get(r).charAt(p)
            .eval v = v * 4 + (c == "w" ? 1 : c == "b" ? 2 : c == "y" ? 3 : 0)
        }
        .eval out.add(v)
    }
    .return out
}
.var thCloud = List()
.eval thCloud.add(thChar("....", "..bb", ".byy", "byyy", "byyy", "byyy", "byyy", "byyy"))   // 0 top left
.eval thCloud.add(thChar("..bb", ".byy", "byyy", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy"))   // 1 top, a bump's left half
.eval thCloud.add(thChar("bb..", "yyb.", "yyyb", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy"))   // 2 ... its right half
.eval thCloud.add(thChar("....", "bb..", "yyb.", "yyyb", "yyyb", "yyyb", "yyyb", "yyyb"))   // 3 top right
.eval thCloud.add(thChar("byyy", "byyy", "byyy", "byyy", "byyy", "byyy", "byyy", ".byy"))   // 4 left
.eval thCloud.add(thChar("yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyyb", "yyb."))   // 5 right
.eval thCloud.add(thChar("byyy", "byyy", "byyy", "byyy", ".byy", "..bb", "....", "...."))   // 6 bottom left
.eval thCloud.add(thChar("yyyy", "yyyy", "yyyy", "yyyy", "byyy", ".byy", "..bb", "...."))   // 7 bottom, a bump's left half
.eval thCloud.add(thChar("yyyy", "yyyy", "yyyy", "yyyy", "yyyb", "yyb.", "bb..", "...."))   // 8 ... its right half
.eval thCloud.add(thChar("yyyb", "yyyb", "yyyb", "yyyb", "yyb.", "bb..", "....", "...."))   // 9 bottom right
.eval thCloud.add(thChar("....", ".bb.", "byyb", "byyb", "byyb", "byyb", ".bb.", "...."))   // 10 trail, the bigger circle
.eval thCloud.add(thChar("....", "....", "....", ".bb.", "byyb", ".bb.", "....", "...."))   // 11 trail, the small one
.eval thCloud.add(thChar("yyyy", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy", "yyyy"))   // 12 blank
.const TH_TL = 0
.const TH_TA = 1
.const TH_TB = 2
.const TH_TR = 3
.const TH_L = 4
.const TH_R = 5
.const TH_BL = 6
.const TH_BA = 7
.const TH_BB = 8
.const TH_BR = 9
.const TH_MED = 10
.const TH_SML = 11
.const TH_SP = 12

// the font: ^ spade, < heart, > diamond
.var thFont = Hashtable()
.function tfont(c, r0, r1, r2, r3, r4, r5) { .eval thFont.put(c, List().add(r0, r1, r2, r3, r4, r5)) }
.eval tfont("A", ".#.", "#.#", "#.#", "###", "#.#", "#.#")
.eval tfont("B", "##.", "#.#", "##.", "#.#", "#.#", "##.")
.eval tfont("C", ".##", "#..", "#..", "#..", "#..", ".##")
.eval tfont("D", "##.", "#.#", "#.#", "#.#", "#.#", "##.")
.eval tfont("E", "###", "#..", "##.", "#..", "#..", "###")
.eval tfont("F", "###", "#..", "##.", "#..", "#..", "#..")
.eval tfont("G", ".##", "#..", "#..", "#.#", "#.#", ".##")
.eval tfont("H", "#.#", "#.#", "###", "#.#", "#.#", "#.#")
.eval tfont("I", "###", ".#.", ".#.", ".#.", ".#.", "###")
.eval tfont("J", "..#", "..#", "..#", "..#", "#.#", ".#.")
.eval tfont("K", "#.#", "#.#", "##.", "#.#", "#.#", "#.#")
.eval tfont("L", "#..", "#..", "#..", "#..", "#..", "###")
.eval tfont("M", "#.#", "###", "###", "#.#", "#.#", "#.#")
.eval tfont("N", "##.", "#.#", "#.#", "#.#", "#.#", "#.#")
.eval tfont("O", ".#.", "#.#", "#.#", "#.#", "#.#", ".#.")
.eval tfont("P", "##.", "#.#", "#.#", "##.", "#..", "#..")
.eval tfont("Q", ".#.", "#.#", "#.#", "#.#", "##.", ".##")
.eval tfont("R", "##.", "#.#", "#.#", "##.", "#.#", "#.#")
.eval tfont("S", ".##", "#..", ".#.", "..#", "..#", "##.")
.eval tfont("T", "###", ".#.", ".#.", ".#.", ".#.", ".#.")
.eval tfont("U", "#.#", "#.#", "#.#", "#.#", "#.#", "###")
.eval tfont("V", "#.#", "#.#", "#.#", "#.#", "#.#", ".#.")
.eval tfont("W", "#.#", "#.#", "#.#", "###", "###", "#.#")
.eval tfont("Y", "#.#", "#.#", ".#.", ".#.", ".#.", ".#.")
.eval tfont("!", ".#.", ".#.", ".#.", ".#.", "...", ".#.")
.eval tfont("?", "##.", "..#", ".#.", ".#.", "...", ".#.")
.eval tfont(@"'", ".#.", ".#.", "...", "...", "...", "...")
.eval tfont(",", "...", "...", "...", "...", ".#.", "#..")
.eval tfont(".", "...", "...", "...", "...", "...", ".#.")
.eval tfont(":", "...", ".#.", "...", "...", ".#.", "...")
.eval tfont("^", ".#.", "###", "###", "###", ".#.", "###")
.eval tfont("<", "#.#", "###", "###", "###", ".#.", "...")
.eval tfont(">", ".#.", ".#.", "###", "###", ".#.", ".#.")

// the thoughts: 4 sets (one picked at random per robbery) of 3, each two
// lines of at most 14 characters (centred)
.var thTexts = List().add(
    "HMM... WHICH", "ONE, VINNIE?",
    "THE ACE OF ^?", "THE KING OF <?",
    "THE QUEEN OF", ">! SHE'S LUCKY",

    "SO MANY CARDS,", "SO LITTLE TIME",
    "A JACK OF >?", "NAH, TOO CHEAP",
    "THE WHOLE DECK", "AND SCRAM!",

    "MAMA ALWAYS", "SAID: ACE OF <",
    "...OR WAS IT", "THE ACE OF ^?",
    "FORGET IT.", "TAKE 'EM ALL!",

    "A BIRTHDAY", "CARD FOR MA?",
    "WITH A BIG <", "SHE'LL CRY!",
    "GRAB IT AND", "BOOGIE!")
.const TH_SETS = 4
.errorif thTexts.size() != TH_SETS * 6, "4 sets of 3 thoughts of 2 lines"

// the letters used, in order of first use
.var thLetters = ""
.for (var t = 0; t < thTexts.size(); t++) {
    .var s = thTexts.get(t)
    .errorif s.size() > 14, "a thought line is too long: " + s
    .for (var i = 0; i < s.size(); i++) {
        .var c = s.charAt(i)
        .if (c != " ") {
            .errorif !thFont.containsKey(c), "no thought glyph for " + c
            .var found = false
            .for (var g = 0; g < thLetters.size(); g++) .if (thLetters.charAt(g) == c) .eval found = true
            .if (!found) .eval thLetters = thLetters + c
        }
    }
}
.function tpix(c, x, y) {
    .if (x < 0 || x > 2 || y < 0 || y > 5) .return false
    .return thFont.get(c).get(y).charAt(x) == "#"
}
.var thinkGly = List()                          // TH_NB characters, 8 bytes each
.for (var g = 0; g < thCloud.size(); g++) .for (var r = 0; r < 8; r++) .eval thinkGly.add(thCloud.get(g).get(r))
.for (var g = 0; g < thLetters.size(); g++) {
    .var c = thLetters.charAt(g)
    .for (var y = 0; y < 8; y++) {
        .var v = 0
        .for (var x = 0; x < 4; x++) {
            .var px = tpix(c, x, y) ? 2 : (tpix(c, x - 1, y - 1) ? 0 : 3)   // b, shadow, white
            .eval v = v * 4 + px
        }
        .eval thinkGly.add(v)
    }
}
.const TH_NB = thCloud.size() + thLetters.size()
.function thIndex(c) {
    .if (c == " ") .return TH_SP
    .for (var g = 0; g < thLetters.size(); g++) .if (thLetters.charAt(g) == c) .return thCloud.size() + g
    .return TH_SP
}
.var thinkTxt = List()                          // 12 thoughts of 28 glyph numbers (+ 4: 32 apart)
.for (var t = 0; t < thTexts.size(); t++) {
    .var s = thTexts.get(t)
    .var pad = floor((14 - s.size()) / 2)
    .for (var i = 0; i < 14; i++) {
        .var j = i - pad
        .eval thinkTxt.add((j >= 0 && j < s.size()) ? thIndex(s.charAt(j)) : TH_SP)
    }
    .if (mod(t, 2) == 1) .for (var i = 0; i < 4; i++) .eval thinkTxt.add(0)
}
.print "Thought characters: " + TH_NB
