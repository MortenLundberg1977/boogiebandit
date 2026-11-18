// Boogie Bandit - bitmap screens: text in the game's own 4x7 font, the
// title pages (picture / top bandits), game over with name entry, and the
// city map. Imported by boogie.asm. All of them use the multicolor bitmap at
// $e000 with its colours in screen A ($c000); the B->A screen shift that
// normally lives at $e000 is generated again when the city comes back.

// ---------------------------------------------------------------- the font
.var fontOrder = @" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-.$\""
.function glyphOf(c) {
    .for (var i = 0; i < fontOrder.size(); i++) .if (fontOrder.charAt(i) == c) .return i
    .error "no glyph for '" + c + "'"
}
.const G_DIGIT = 27
.const G_DOLLAR = 40
.var fntBytes = List()
.for (var g = 0; g < fontOrder.size(); g++) {
    .for (var y = 0; y < 8; y++) {
        .var v = 0
        .for (var x = 0; x < 4; x++) .eval v = v * 2 + ((y < 7 && fontPix(fontOrder.charAt(g), x, y)) ? 1 : 0)
        .eval fntBytes.add(v)
    }
}

// print a text: column, row, colour (1, 2 or 3 = the bitmap colour codes)
.macro Print(col, row, colour, s) {
    lda #<str
    sta zsrc
    lda #>str
    sta zsrc + 1
    lda #colour
    sta bm_col
    ldx #col
    ldy #row
    jsr bm_text
    jmp over
str: .fill s.size(), glyphOf(s.charAt(i))
    .byte $ff
over:
}

// glyph a at column x, row y in colour bm_col (x and y are kept)
bm_glyph:
    sta t3
    stx tx_c
    sty tx_r
    lda bmrow_lo,y
    sta zp1
    lda bmrow_hi,y
    sta zp1 + 1
    txa
    asl
    asl
    asl
    bcc !+
    inc zp1 + 1
!:  clc
    adc zp1
    sta zp1
    bcc !+
    inc zp1 + 1
!:  ldx t3
    lda fnt_lo,x
    sta zp0
    lda fnt_hi,x
    sta zp0 + 1
    ldy #7
bg_loop:
    lda (zp0),y
    tax
    lda exp_tab,x
    ldx bm_col
    cpx #1
    beq bg_st
    cpx #2
    beq bg_2
    sta t4
    asl
    ora t4
    jmp bg_st
bg_2:
    asl
bg_st:
    sta (zp1),y
    dey
    bpl bg_loop
    ldx tx_c
    ldy tx_r
    rts

// text at (zsrc), $ff at the end, from column x, row y
bm_text:
    lda #0
    sta tx_i
bt_loop:
    sty t5
    ldy tx_i
    lda (zsrc),y
    ldy t5
    cmp #$ff
    beq bt_done
    jsr bm_glyph
    inx
    inc tx_i
    jmp bt_loop
bt_done:
    rts

// six BCD digits from bcd (lowest byte first) at column x, row y; leading
// zeros left blank
print_bcd:
    lda #0
    sta pb_seen
    lda bcd + 2
    jsr pb_two
    lda bcd + 1
    jsr pb_two
    lda bcd
    lsr
    lsr
    lsr
    lsr
    jsr pb_dig
    lda #1
    sta pb_seen
    lda bcd
    and #15
    jmp pb_dig
pb_two:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr pb_dig
    pla
    and #15
pb_dig:
    cmp #0
    bne pd_num
    lda pb_seen
    beq pd_out                      // a = 0 = space
    lda #0
pd_num:
    pha
    lda #1
    sta pb_seen
    pla
    clc
    adc #G_DIGIT
pd_out:
    jsr bm_glyph
    inx
    rts

// ---------------------------------------------------------------- pages
// screen off, empty bitmap, colours: 01 yellow, 10 orange, 11 white
page_blank:
    lda #$0b
    sta $d011
    lda #<BITMAP
    sta zp0
    lda #>BITMAP
    sta zp0 + 1
    lda #0
    tay
    ldx #31                         // $e000-$feff
!:  sta (zp0),y
    iny
    bne !-
    inc zp0 + 1
    dex
    bne !-
!:  sta (zp0),y                     // $ff00-$ff3f (the vectors stay)
    iny
    cpy #$40
    bne !-
    ldx #0
!:  lda #$78
    sta SCR_A,x
    sta SCR_A + $100,x
    sta SCR_A + $200,x
    sta SCR_A + $2e8,x
    lda #1
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $dae8,x
    inx
    bne !-
    rts

bm_show:
    lda #$08                        // bitmap $e000, screen $c000
    sta $d018
    lda #$18
    sta $d016
    lda #0
    sta $d020
    sta $d021
    lda #$3b
    sta $d011
    rts

// the title picture
show_picture:
    lda #$0b
    sta $d011
    lda #<intro_bitmap
    sta zsrc
    lda #>intro_bitmap
    sta zsrc + 1
    lda #<BITMAP
    sta zdst
    lda #>BITMAP
    sta zdst + 1
    jsr unpack
    lda #<intro_screen
    sta zsrc
    lda #>intro_screen
    sta zsrc + 1
    lda #<SCR_A
    sta zdst
    lda #>SCR_A
    sta zdst + 1
    jsr unpack
    lda #<intro_color
    sta zsrc
    lda #>intro_color
    sta zsrc + 1
    lda #<$d800
    sta zdst
    lda #>$d800
    sta zdst + 1
    jsr unpack
    jmp bm_show

// the high score page
show_scores:
    jsr page_blank
    Print(13, 2, 2, "BOOGIE BANDIT")
    Print(3, 3, 3, @"STARRING VINNIE \"BOOGIE\" MARCHETTI")
    Print(14, 5, 1, "TOP BANDITS")
    lda #0
    sta hs_i
ss_loop:
    lda hs_i
    asl
    adc #8
    tay
    lda #1
    sta bm_col
    lda hs_i
    clc
    adc #G_DIGIT + 1
    ldx #11
    jsr bm_glyph
    lda #3
    sta bm_col
    ldx hs_i
    lda x3_tab,x
    sta t2
    ldx #14
!:  stx t5
    ldx t2
    lda hs_names,x
    ldx t5
    jsr bm_glyph
    inc t2
    inx
    cpx #17
    bne !-
    lda #2
    sta bm_col
    lda #G_DOLLAR
    ldx #20
    jsr bm_glyph
    lda #3
    sta bm_col
    ldx hs_i
    lda hs_s0,x
    sta bcd
    lda hs_s1,x
    sta bcd + 1
    lda hs_s2,x
    sta bcd + 2
    ldx #21
    jsr print_bcd
    inc hs_i
    lda hs_i
    cmp #5
    bne ss_loop
    jmp bm_show

// ---------------------------------------------------------------- high scores
// a = place (0-4) the score gets, or $ff
hs_find:
    ldx #0
hf_loop:
    lda score + 2
    cmp hs_s2,x
    bcc hf_next
    bne hf_found
    lda score + 1
    cmp hs_s1,x
    bcc hf_next
    bne hf_found
    lda score
    cmp hs_s0,x
    beq hf_next
    bcs hf_found
hf_next:
    inx
    cpx #5
    bne hf_loop
    lda #$ff
    rts
hf_found:
    txa
    rts

// make room at hs_pos and put the score there with the name "AAA"
hs_insert:
    ldx #4
hi_loop:
    cpx hs_pos
    beq hi_put
    lda hs_s0 - 1,x
    sta hs_s0,x
    lda hs_s1 - 1,x
    sta hs_s1,x
    lda hs_s2 - 1,x
    sta hs_s2,x
    ldy x3_tab,x
    lda hs_names - 3,y
    sta hs_names,y
    lda hs_names - 2,y
    sta hs_names + 1,y
    lda hs_names - 1,y
    sta hs_names + 2,y
    dex
    jmp hi_loop
hi_put:
    lda score
    sta hs_s0,x
    lda score + 1
    sta hs_s1,x
    lda score + 2
    sta hs_s2,x
    ldy x3_tab,x
    lda #1
    sta hs_names,y
    sta hs_names + 1,y
    sta hs_names + 2,y
    rts

// game over: the score, and a name for the table if it made it
hiscore_entry:
    jsr page_blank
    Print(15, 4, 2, "GAME OVER")
    Print(12, 7, 1, "SCORE")
    lda #2
    sta bm_col
    lda #G_DOLLAR
    ldx #18
    ldy #7
    jsr bm_glyph
    lda score
    sta bcd
    lda score + 1
    sta bcd + 1
    lda score + 2
    sta bcd + 2
    lda #3
    sta bm_col
    ldx #19
    ldy #7
    jsr print_bcd
    jsr hs_find
    sta hs_pos
    bpl he_new
    jsr bm_show
    lda #0                          // not in the table: a few seconds
    sta hs_i
!:  jsr wait_frame
    jsr read_input
    lda joy_new
    and #$10
    bne !+
    dec hs_i
    bne !-
    lda hs_i
!:  rts
he_new:
    jsr hs_insert
    Print(12, 11, 2, "NEW HIGH SCORE!")
    Print(12, 13, 1, "ENTER YOUR NAME")
    Print(11, 20, 1, "JOYSTICK AND FIRE")
    jsr bm_show
    lda #0
    sta hs_cur
    sta hs_rep
he_loop:
    jsr wait_frame
    jsr read_input
    ldx hs_pos
    lda x3_tab,x
    clc
    adc hs_cur
    tax                             // x = the letter being chosen
    lda joy
    and #$03
    beq he_fire
    lda joy_new
    and #$03
    beq !+
    lda #14                         // first press, then repeat
    sta hs_rep
    jmp he_change
!:  dec hs_rep
    bne he_fire
    lda #4
    sta hs_rep
he_change:
    lda joy
    and #$01
    beq he_down
    inc hs_names,x
    lda hs_names,x
    cmp #27
    bcc he_fire
    lda #0
    sta hs_names,x
    jmp he_fire
he_down:
    dec hs_names,x
    bpl he_fire
    lda #26
    sta hs_names,x
he_fire:
    lda joy_new
    and #$10
    beq he_draw
    lda #SFX_DOOR
    jsr sfx_play
    inc hs_cur
    lda hs_cur
    cmp #3
    bne he_draw
    rts
he_draw:
    ldx hs_pos
    lda x3_tab,x
    sta t2
    lda #0
    sta hs_i
!:  ldx #3                          // the letter being chosen blinks
    lda hs_i
    cmp hs_cur
    bne he_col
    lda vbl
    and #8
    beq he_col
    ldx #1
he_col:
    stx bm_col
    lda hs_i
    asl
    adc #18
    tax
    ldy t2
    lda hs_names,y
    ldy #16
    jsr bm_glyph
    inc t2
    inc hs_i
    lda hs_i
    cmp #3
    bne !-
    jmp he_loop

wait_frame:
    lda vbl
!:  cmp vbl
    beq !-
    rts

x3_tab: .byte 0, 3, 6, 9, 12
// the table: names as glyph numbers, scores as BCD (lowest byte first)
hs_names:   .fill 15, glyphOf("DEESALVICJOEACE".charAt(i))
hs_s0:      .byte $00, $00, $00, $00, $00
hs_s1:      .byte $00, $50, $00, $50, $25
hs_s2:      .byte $02, $01, $01, $00, $00

// ---------------------------------------------------------------- the city map
// 128 x 128 map characters -> 64 x 128 multicolor pixels (two characters
// per pixel across, one per pixel row) in character columns 12-27, rows
// 2-17: roads light grey, buildings dark grey, banks yellow. Dots for the
// player, the police and the cabs, a ring around the next bank.
show_map:
    lda #0
    sta in_game
    sta $d015
    jsr sound_off
    lda #$0b
    sta $d011
    ldx #0                          // all black
    lda #0
!:  sta SCR_A,x
    sta SCR_A + $100,x
    sta SCR_A + $200,x
    sta SCR_A + $2e8,x
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $dae8,x
    inx
    bne !-
    ldx #39                         // text rows 0 and 20
!:  lda #$71
    sta SCR_A,x
    sta SCR_A + 800,x
    dex
    bpl !-
    lda #0
    sta t0
sm_crow:                            // the map cells
    lda t0
    clc
    adc #2
    tax
    lda srow_lo,x
    clc
    adc #12
    sta zp0
    lda srow_hi,x
    adc #>SCR_A
    sta zp0 + 1
    lda srow_lo,x
    clc
    adc #12
    sta zp1
    lda srow_hi,x
    adc #$d8
    sta zp1 + 1
    ldy #15
!:  lda #$fb
    sta (zp0),y
    lda #7
    sta (zp1),y
    dey
    bpl !-
    inc t0
    lda t0
    cmp #16
    bne sm_crow
    lda #0                          // clear the text rows of the bitmap
    jsr mm_clear_row
    lda #20
    jsr mm_clear_row
    jsr mm_render
    jsr mm_banks
    Print(16, 0, 1, "CITY MAP")
    Print(15, 20, 2, "PRESS FIRE")
    // sprites: hi-res dots
    lda #0
    sta $d01c
    sta $d017
    sta $d01d
    sta $d010
    lda #SP_RING
    sta SCR_A + $3f9
    lda #SP_DOT
    ldx #7
!:  cpx #1
    beq !+
    sta SCR_A + $3f8,x
!:  dex
    bpl !--
    lda #5
    sta $d028
    lda #7
    sta $d02c
    sta $d02d
    // the player
    jsr set_target
    lda tgt_xl
    sta px_l
    lda tgt_xh
    sta px_h
    lda tgt_yl
    sta py_l
    lda tgt_yh
    sta py_h
    ldx #0
    lda #1
    sta t4
    jsr mm_spr
    // the next bank
    jsr goal_idx
    lda door_xl,x
    sta px_l
    lda door_xh,x
    sta px_h
    lda door_yl,x
    sec
    sbc #32
    sta py_l
    lda door_yh,x
    sbc #0
    sta py_h
    ldx #1
    lda #3
    sta t4
    jsr mm_spr
    // police and cabs: sprites 2-6
    ldx #0
sm_npc:
    stx ni
    lda n_type,x
    beq sm_next
    lda n_xl,x
    sta px_l
    lda n_xh,x
    sta px_h
    lda n_yl,x
    sta py_l
    lda n_yh,x
    sta py_h
    lda ni
    clc
    adc #2
    tax
    lda #1
    sta t4
    jsr mm_spr
sm_next:
    ldx ni
    inx
    cpx #NNPC
    bne sm_npc
    jsr bm_show
sm_loop:
    jsr wait_frame
    lda vbl                         // the player blinks, the police flash
    and #8
    beq !+
    lda #1
!:  sta $d027
    ldy #6
    lda vbl
    and #8
    beq !+
    ldy #2
!:  sty $d029
    sty $d02a
    sty $d02b
    jsr read_input
    lda joy_new
    and #$10
    bne sm_exit
    lda key_map
    beq sm_loop
sm_exit:
    // back to the streets
    lda #$0b
    sta $d011
    lda #0
    sta $d015
    jsr gen_shift_ba
    jsr city_colours
    lda front_hi
    sta back_hi
    jsr full_redraw
    lda #0
    sta pending
    lda #2                          // the car red, the marker green again
    sta $d02c
    lda #5
    sta $d02d
    lda #$ff
    sta $d01c
    lda sh_d018
    sta $d018
    lda sh_d016
    sta $d016
    lda sh_d011
    sta $d011
    lda #1
    sta in_game
    rts

// sprite x on the map at world position px/py, minus t4
mm_spr:
    lda px_h
    sta t0
    lda px_l
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    lsr                             // (2 characters a pixel)
    clc
    adc #24 + 96
    sec
    sbc t4
    pha
    txa
    asl
    tay
    pla
    sta $d000,y
    lda py_h
    sta t0
    lda py_l
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    lsr
    clc
    adc #50 + 16
    sec
    sbc t4
    sta $d001,y
    lda bit_tab,x
    ora $d015
    sta $d015
    rts

// clear text row a of the bitmap (320 bytes)
mm_clear_row:
    tay
    lda bmrow_lo,y
    sta zp1
    lda bmrow_hi,y
    sta zp1 + 1
    lda #0
    tay
!:  sta (zp1),y
    iny
    bne !-
    inc zp1 + 1
    ldy #63
!:  sta (zp1),y
    dey
    bpl !-
    rts

// the map screen samples the city: MMBUF[0, 2, ... 126] = the characters
// of columns 0, 4, ... 252 of world row x; zp0 = MMBUF
.const MMBUF = $0200
mm_sample:
    lda #0
    sta mf_c
    sta mf_i
ms_seg:
    lda mf_c
    jsr map_at
ms_loop:
    lda (zp0),y
    sty dc_y
    ldy mf_i
    sta MMBUF,y
    iny
    iny
    sty mf_i
    bmi ms_done
    lda mf_c
    clc
    adc #4
    sta mf_c
    lda dc_y
    clc
    adc #4
    tay
    cpy #32
    bcc ms_loop
    bcs ms_seg
ms_done:
    lda #<MMBUF
    sta zp0
    lda #>MMBUF
    sta zp0 + 1
    rts

mm_render:
    lda #0
    sta t5                          // map row
mr_row:
    lda t5                          // world row 2 x t5, every 4th column
    asl
    tax
    jsr mm_sample
    lda t5
    lsr
    lsr
    lsr
    clc
    adc #2
    tay
    lda bmrow_lo,y
    clc
    adc #96
    sta zp1
    lda bmrow_hi,y
    adc #0
    sta zp1 + 1
    lda t5
    and #7
    clc
    adc zp1
    sta zp1
    bcc !+
    inc zp1 + 1
!:  lda #0
    sta t1
mr_byte:
    ldy t1
    lda (zp0),y
    tax
    lda MM_CODE,x
    asl
    asl
    sta t0
    iny
    iny
    lda (zp0),y
    tax
    lda MM_CODE,x
    ora t0
    asl
    asl
    sta t0
    iny
    iny
    lda (zp0),y
    tax
    lda MM_CODE,x
    ora t0
    asl
    asl
    sta t0
    iny
    iny
    lda (zp0),y
    tax
    lda MM_CODE,x
    ora t0
    ldy t1
    sta (zp1),y
    tya
    clc
    adc #8
    sta t1
    bpl mr_byte
    inc t5
    bpl mr_row
    rts

// paint the banks yellow: 5 x 8 pixels over each door
mm_banks:
    ldx #NBANKS - 1
mb_loop:
    stx t2
    lda door_xh,x
    sta t0
    lda door_xl,x
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    lsr
    lsr                             // (the map: 4 columns a pixel)
    sec
    sbc #1
    sta mb_x
    lda door_yh,x
    sta t0
    lda door_yl,x
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    lsr                             // (2 rows a pixel)
    sec
    sbc #4
    sta mb_y
    lda #4
    sta mb_h
mb_rows:
    lda #3
    sta mb_w
    lda mb_x
    sta t0
mb_cols:
    lda mb_y
    sta t1
    jsr mm_setpx
    inc t0
    dec mb_w
    bne mb_cols
    inc mb_y
    dec mb_h
    bne mb_rows
    ldx t2
    dex
    bpl mb_loop
    rts

// map pixel t0 (0-63), t1 (0-127) := yellow
mm_setpx:
    lda t1
    lsr
    lsr
    lsr
    clc
    adc #2
    tay
    lda bmrow_lo,y
    sta zp1
    lda bmrow_hi,y
    sta zp1 + 1
    lda t0
    lsr
    lsr
    asl
    asl
    asl
    adc #96
    clc
    adc zp1
    sta zp1
    bcc !+
    inc zp1 + 1
!:  lda t1
    and #7
    tay
    lda t0
    and #3
    tax
    lda (zp1),y
    ora px_mask,x
    sta (zp1),y
    rts

px_mask:    .byte $c0, $30, $0c, $03
exp_tab:    .fill 16, ((i >> 3) & 1) * $40 + ((i >> 2) & 1) * $10 + ((i >> 1) & 1) * $04 + (i & 1)
bmrow_lo:   .fill 25, <(BITMAP + i * 320)
bmrow_hi:   .fill 25, >(BITMAP + i * 320)
fnt_data:   .fill fntBytes.size(), fntBytes.get(i)
fnt_lo:     .fill fontOrder.size(), <(fnt_data + i * 8)
fnt_hi:     .fill fontOrder.size(), >(fnt_data + i * 8)

