// Boogie Bandit - a small SID player and an original funk/disco tune
// ("Getaway Groove", A minor, 125 BPM). Plus sound effects on voice 3.
//
// Patterns are written as text, one token per 16th step:
//   A2 C#3 ...   note (octave digit last)     .  hold the previous note/rest
//   -            rest                         K S H h  kick, snare, open/closed hat
// Every pattern is one bar (16 steps). The player writes a register shadow
// and copies it to the SID once a frame; while a sound effect runs, voice 3
// is left to the effect.

.const SPEED = 6                                // frames per 16th note

// ---------------------------------------------------------------- instruments
.const I_BASS = 0
.const I_LEAD = 1
.const I_STAB = 2
.const I_KICK = 3
.const I_SNARE = 4
.const I_HATO = 5
.const I_HATC = 6
//                        bass  lead  stab  kick  snare hat-o hat-c
.var insWave = List().add($41, $21, $41, $11, $41, $81, $81)
.var insAD = List().add($0a, $25, $06, $08, $09, $06, $02)
.var insSR = List().add($80, $a6, $00, $00, $00, $00, $00)
.var insPW = List().add($0500, $0800, $0700, $0800, $0800, $0800, $0800)
.var insVib = List().add(0, 1, 0, 0, 0, 0, 0)
.var insPWM = List().add(8, 0, 24, 0, 0, 0, 0)
.var insGateOff = List().add(1, 1, 1, 0, 0, 0, 0)
.var drumTab = List()
.var insDrum = List().add(0, 0, 0, 0, 0, 0, 0)
.function drum(ins, bytes) {
    .eval insDrum.set(ins, drumTab.size() + 1)
    .for (var i = 0; i < bytes.size(); i++) .eval drumTab.add(bytes.get(i))
    .return 0
}
.eval drum(I_KICK, List().add($81, $0a, $11, $0c, $11, $08, $11, $06, $11, $05, $11, $04, $10, $04, 0))
.eval drum(I_SNARE, List().add($41, $0a, $81, $42, $81, $3e, $81, $3a, $81, $36, $81, $32, $80, $30, 0))
.eval drum(I_HATO, List().add($81, $70, $81, $70, $81, $70, $81, $70, $81, $70, $80, $70, 0))
.eval drum(I_HATC, List().add($81, $7c, $81, $7c, $80, $7c, 0))

// ---------------------------------------------------------------- pattern compiler
.function tokens(s) {
    .var out = List()
    .var cur = ""
    .for (var i = 0; i < s.size(); i++) {
        .var c = s.charAt(i)
        .if (c == " ") {
            .if (cur.size() > 0) {
                .eval out.add(cur)
                .eval cur = ""
            }
        } else {
            .eval cur = cur + c
        }
    }
    .if (cur.size() > 0) .eval out.add(cur)
    .return out
}
.var noteNames = List().add("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
.var digits = "0123456789"
.function noteNum(t) {
    .var name = t.substring(0, t.size() - 1)
    .var oct = -1
    .for (var d = 0; d < 10; d++) .if (digits.charAt(d) == t.charAt(t.size() - 1)) .eval oct = d
    .var semi = -1
    .for (var n = 0; n < 12; n++) .if (noteNames.get(n) == name) .eval semi = n
    .errorif oct < 0 || semi < 0, "bad note " + t
    .return oct * 12 + semi
}
.var patterns = List()
.var patNames = Hashtable()
.function pat(name, ins, s) {
    .var toks = tokens(s)
    .errorif toks.size() != 16, "pattern " + name + " has " + toks.size() + " steps"
    .var ev = List()                            // [instrument, note or $60, steps]
    .for (var i = 0; i < toks.size(); i++) {
        .var t = toks.get(i)
        .if (t == ".") {
            .if (ev.size() > 0) {
                .var last = ev.get(ev.size() - 1)
                .eval last.set(2, last.get(2) + 1)
            } else {
                .eval ev.add(List().add(ins, $60, 1))
            }
        } else {
            .var e = List().add(ins, -1, 1)
            .if (t == "-") .eval e.set(1, $60)
            .if (t == "K") .eval e.set(0, I_KICK)
            .if (t == "S") .eval e.set(0, I_SNARE)
            .if (t == "H") .eval e.set(0, I_HATO)
            .if (t == "h") .eval e.set(0, I_HATC)
            .if (t == "K" || t == "S" || t == "H" || t == "h") .eval e.set(1, $30)
            .if (e.get(1) == -1) .eval e.set(1, noteNum(t))
            .eval ev.add(e)
        }
    }
    .var bytes = List()
    .var cur = -1
    .for (var i = 0; i < ev.size(); i++) {
        .var e = ev.get(i)
        .if (e.get(0) != cur) {
            .eval bytes.add($80 + e.get(0))
            .eval cur = e.get(0)
        }
        .eval bytes.add(e.get(1))
        .eval bytes.add(e.get(2))
    }
    .eval bytes.add($ff)
    .eval patNames.put(name, patterns.size())
    .eval patterns.add(bytes)
    .return 0
}

// ---------------------------------------------------------------- the tune
// bass: disco octaves with funky pickups
.eval pat("bA", I_BASS, "A1 - A2 - A1 A2 - G2 A1 - A2 - C3 A2 G2 E2")
.eval pat("bF", I_BASS, "F1 - F2 - F1 F2 - E2 F1 - F2 - A2 F2 E2 C2")
.eval pat("bG", I_BASS, "G1 - G2 - G1 G2 - F2 G1 - G2 - B2 G2 F2 D2")
.eval pat("bE", I_BASS, "E1 - E2 - E1 E2 - D2 E1 - E2 - G#2 E2 D2 B1")
.eval pat("bD", I_BASS, "D2 - D3 - D2 D3 - C3 D2 - D3 - F3 D3 C3 A2")
// drums
.eval pat("dI", I_KICK, "K - h - S - h - K - h - S - h h")
.eval pat("dA", I_KICK, "K h H h S h H K K h H h S h H h")
.eval pat("dB", I_KICK, "K h H h S h H K K h S h S S S S")
// lead: the hook (brass)
.eval pat("R", I_LEAD, "- . . . . . . . . . . . . . . .")
.eval pat("L1", I_LEAD, "E4 - E4 G4 - A4 . . C5 . A4 G4 - E4 . .")
.eval pat("L2", I_LEAD, "D4 - D4 E4 - G4 . E4 . . D4 C4 - A3 . .")
.eval pat("L3", I_LEAD, "C4 - C4 F4 - A4 . . C5 . A4 F4 - C4 . .")
.eval pat("L4", I_LEAD, "B3 - B3 E4 - G#4 . . B4 . . A4 G#4 F4 E4 .")
// stabs: call and response, then the chase climb
.eval pat("S1", I_STAB, "D5 - - D5 - - C5 - D5 - - F5 - D5 - -")
.eval pat("S2", I_STAB, "E5 - - E5 - - D5 - C5 - - A4 - - - -")
.eval pat("S3", I_STAB, "D5 - - D5 - - C5 - D5 - - F5 - G5 - -")
.eval pat("S4", I_LEAD, "E5 . . . F5 . . . F#5 . . . G#5 . B5 .")
// long brass over the descending chords
.eval pat("C1", I_LEAD, "A4 . . . . . C5 . B4 . A4 . G4 . A4 .")
.eval pat("C2", I_LEAD, "G4 . . . . . B4 . A4 . G4 . F4 . G4 .")
.eval pat("C3", I_LEAD, "F4 . . . . . A4 . G4 . F4 . E4 . F4 .")
.eval pat("C4", I_LEAD, "E4 . . . G#4 . . . B4 . . . D5 . C5 B4")

.function order(names, loopTo) {
    .var out = List()
    .var t = tokens(names)
    .for (var i = 0; i < t.size(); i++) .eval out.add(patNames.get(t.get(i)))
    .eval out.add($fe)
    .eval out.add(loopTo)
    .return out
}
.var ord1 = order("bA bA  bA bA bF bE  bA bA bF bE  bD bA bD bE  bA bG bF bE", 2)
.var ord2 = order("R R    L1 L2 L3 L4  L1 L2 L3 L4  S1 S2 S3 S4  C1 C2 C3 C4", 2)
.var ord3 = order("dI dI  dA dA dA dB  dA dA dA dB  dA dA dA dB  dA dA dA dB", 2)

// ---------------------------------------------------------------- player code
music_init:
    ldx #2
!:  lda #0
    sta m_ord,x
    sta m_drum,x
    sta m_vib,x
    lda #1
    sta m_steps,x
    jsr m_load_pattern
    dex
    bpl !-
    lda #SPEED - 1
    sta m_tick
    ldx #20
    lda #0
!:  sta sid_sh,x
    sta $d400,x
    dex
    bpl !-
    lda #$0f
    sta $d418
    rts

// silence all voices (music off)
music_mute:
    lda #0
    ldx v1_own
    bne !+
    sta $d404
!:  ldx v2_own
    bne !+
    sta $d40b
!:
    lda sfx_on
    bne !+
    lda #0
    sta $d412
!:  rts

m_load_pattern:                     // x = voice: next pattern from the order list
    lda ord_lo,x
    sta mzp
    lda ord_hi,x
    sta mzp + 1
    ldy m_ord,x
    lda (mzp),y
    cmp #$fe
    bne !+
    iny
    lda (mzp),y
    sta m_ord,x
    tay
    lda (mzp),y
!:  tay
    lda pat_lo,y
    sta m_pl,x
    lda pat_hi,y
    sta m_ph,x
    inc m_ord,x
    rts

music_play:
    inc m_tick
    lda m_tick
    cmp #SPEED
    bne !+
    lda #0
    sta m_tick
!:  ldx #2
m_voice:
    lda m_tick
    bne m_gatecheck
    dec m_steps,x
    bne m_fx
    jsr m_event
    jmp m_fx
m_gatecheck:
    cmp #SPEED - 1
    bne m_fx
    lda m_steps,x
    cmp #1
    bne m_fx
    ldy m_ins,x
    lda ins_goff,y
    beq m_fx
    ldy sidoff,x
    lda sid_sh + 4,y
    and #$fe
    sta sid_sh + 4,y
m_fx:
    jsr m_effects
    dex
    bpl m_voice
    lda v1_own                      // copy the shadow to the SID, except
    bne !+                          // voices the game took (siren, engine)
    ldx #6
m_copy1:
    lda sid_sh,x
    sta $d400,x
    dex
    bpl m_copy1
!:  lda v2_own
    bne !+
    ldx #6
m_copy2:
    lda sid_sh + 7,x
    sta $d407,x
    dex
    bpl m_copy2
!:
    lda sfx_on
    bne !+
    ldx #6
m_copy3:
    lda sid_sh + 14,x
    sta $d40e,x
    dex
    bpl m_copy3
!:  rts

m_event:                            // read the next event of voice x
    lda m_pl,x
    sta mzp
    lda m_ph,x
    sta mzp + 1
    ldy #0
m_read:
    lda (mzp),y
    cmp #$ff
    bne !+
    jsr m_load_pattern
    lda m_pl,x
    sta mzp
    lda m_ph,x
    sta mzp + 1
    ldy #0
    jmp m_read
!:  iny
    cmp #$80
    bcc !+
    and #$7f
    sta m_ins,x
    jmp m_read
!:  sta m_tmp                       // note or $60 (rest)
    lda (mzp),y
    sta m_steps,x
    iny
    tya
    clc
    adc mzp
    sta m_pl,x
    lda mzp + 1
    adc #0
    sta m_ph,x
    lda m_tmp
    cmp #$60
    bne m_noteon
    lda #0
    sta m_drum,x
    ldy sidoff,x
    lda sid_sh + 4,y
    and #$fe
    sta sid_sh + 4,y
    rts
m_noteon:
    sta m_note,x
    ldy m_ins,x
    lda ins_drum,y
    sta m_drum,x
    lda ins_pwl,y
    sta m_pwl,x
    lda ins_pwh,y
    sta m_pwh,x
    lda #0
    sta m_vib,x
    lda ins_ad,y
    sta m_tmp
    lda ins_sr,y
    sta m_tmp2
    lda ins_wave,y
    ora #1
    ldy sidoff,x
    sta sid_sh + 4,y
    lda m_tmp
    sta sid_sh + 5,y
    lda m_tmp2
    sta sid_sh + 6,y
    lda m_pwl,x
    sta sid_sh + 2,y
    lda m_pwh,x
    sta sid_sh + 3,y
    stx m_x
    lda m_note,x
    tax
    lda freq_lo,x
    sta sid_sh + 0,y
    sta m_tmp
    lda freq_hi,x
    sta sid_sh + 1,y
    ldx m_x
    sta m_fh,x
    lda m_tmp
    sta m_fl,x
    rts

m_effects:                          // per-frame effects of voice x
    lda m_drum,x
    beq m_nodrum
    tay
    lda drumtab - 1,y
    beq m_drumend
    sta m_tmp
    lda drumtab,y
    ldy sidoff,x
    sta sid_sh + 1,y
    lda #0
    sta sid_sh + 0,y
    lda m_tmp
    sta sid_sh + 4,y
    inc m_drum,x
    inc m_drum,x
    rts
m_drumend:
    sta m_drum,x
    rts
m_nodrum:
    ldy m_ins,x
    lda ins_vib,y
    beq m_novib
    inc m_vib,x
    lda m_vib,x
    cmp #12
    bcc m_novib
    and #7
    tay
    lda m_fl,x
    clc
    adc vib_lo,y
    sta m_tmp
    lda m_fh,x
    adc vib_hi,y
    ldy sidoff,x
    sta sid_sh + 1,y
    lda m_tmp
    sta sid_sh + 0,y
    ldy m_ins,x
m_novib:
    lda ins_pwm,y
    beq m_nopwm
    clc
    adc m_pwl,x
    sta m_pwl,x
    lda m_pwh,x
    adc #0
    and #$0f
    sta m_pwh,x
    ldy sidoff,x
    sta sid_sh + 3,y
    lda m_pwl,x
    sta sid_sh + 2,y
m_nopwm:
    rts

// ---------------------------------------------------------------- sound effects (voice 3)
// sfx data: AD, SR, then (control, frequency high) pairs, 0 = end
sfx_play:                           // a = effect number
    tax
    lda sfx_lo,x
    sta sfx_ptr
    lda sfx_hi,x
    sta sfx_ptr + 1
    lda #0
    sta $d412
    ldy #0
    lda (sfx_ptr),y
    sta $d413
    iny
    lda (sfx_ptr),y
    sta $d414
    lda #2
    sta sfx_pos
    lda #1
    sta sfx_on
    rts
sfx_update:
    lda sfx_on
    beq !+
    ldy sfx_pos
    lda (sfx_ptr),y
    beq sfx_end
    sta $d412
    iny
    lda (sfx_ptr),y
    sta $d40f
    lda #0
    sta $d40e
    iny
    sty sfx_pos
!:  rts
sfx_end:
    sta $d412
    sta sfx_on
    rts

sfx_lo: .byte <sfx_pow, <sfx_crash, <sfx_ching, <sfx_door, <sfx_step
sfx_hi: .byte >sfx_pow, >sfx_crash, >sfx_ching, >sfx_door, >sfx_step
sfx_pow:   .byte $09, $00, $81, $40, $81, $30, $81, $24, $81, $1c, $81, $14, $81, $10, $81, $0c, $81, $08, $80, $08, 0
sfx_crash: .byte $0c, $00, $81, $10, $81, $10, $81, $0e, $81, $0c, $81, $0a, $81, $09, $81, $08, $81, $07, $80, $07, 0
sfx_ching: .byte $09, $00, $41, $40, $41, $40, $41, $40, $41, $56, $41, $56, $41, $56, $41, $56, $41, $56, $41, $56, $40, $56, 0
sfx_door:  .byte $05, $00, $81, $20, $81, $18, $80, $18, 0
sfx_step:  .byte $00, $a2, $81, $18, $81, $14, $81, $10, $80, $0c, 0    // a heel tap (noise, held 3 frames, short tail)

// ---------------------------------------------------------------- player data
sidoff: .byte 0, 7, 14
ord_lo: .byte <ord1_data, <ord2_data, <ord3_data
ord_hi: .byte >ord1_data, >ord2_data, >ord3_data
ord1_data: .fill ord1.size(), ord1.get(i)
ord2_data: .fill ord2.size(), ord2.get(i)
ord3_data: .fill ord3.size(), ord3.get(i)
ins_wave: .fill insWave.size(), insWave.get(i)
ins_ad:   .fill insAD.size(), insAD.get(i)
ins_sr:   .fill insSR.size(), insSR.get(i)
ins_pwl:  .fill insPW.size(), <insPW.get(i)
ins_pwh:  .fill insPW.size(), >insPW.get(i)
ins_vib:  .fill insVib.size(), insVib.get(i)
ins_pwm:  .fill insPWM.size(), insPWM.get(i)
ins_goff: .fill insGateOff.size(), insGateOff.get(i)
ins_drum: .fill insDrum.size(), insDrum.get(i)
drumtab:  .fill drumTab.size(), drumTab.get(i)
.var vibOfs = List().add(0, 40, 80, 40, 0, -40, -80, -40)
vib_lo: .fill 8, <(vibOfs.get(i) + 65536)
vib_hi: .fill 8, >(vibOfs.get(i) + 65536)
.function freqReg(n) { .return min(65535, round(440 * pow(2, (n - 57) / 12) * 16777216 / 985248)) }
freq_lo: .fill 96, <freqReg(i)
freq_hi: .fill 96, >freqReg(i)
.var patOffs = List()
.var patAll = List()
.for (var p = 0; p < patterns.size(); p++) {
    .eval patOffs.add(patAll.size())
    .for (var i = 0; i < patterns.get(p).size(); i++) .eval patAll.add(patterns.get(p).get(i))
}
pat_data: .fill patAll.size(), patAll.get(i)
pat_lo: .fill patterns.size(), <(pat_data + patOffs.get(i))
pat_hi: .fill patterns.size(), >(pat_data + patOffs.get(i))
