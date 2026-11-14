// Boogie Bandit - police, traffic, the job timer, lives, messages, engine
// and siren. Imported by boogie.asm.
//
// Police cars and cabs drive on the centre lines of the road grid: avenue
// centres at x = 128 + 256 k (k = 0-3), street centres at y = 68 + 128 j
// (j = 0-7). At every crossing (a "node") they pick a new direction: cabs
// at random, police towards the player. Five slots, shown with the hardware
// sprites in slot_spr; sprites 0-3 and 7 are shared with the HUD row at the
// top (the raster IRQ splits them at SPLIT_LINE).

slot_spr:   .byte 7, 0, 1, 2, 4
nc_not:     .byte %1110, %1101, %1011, %0111, $ff, $ff, $ff, $ff
cab_ox:     .byte $ff, 1, $ff, 1
cab_oy:     .byte $fe, $fe, 2, 2
cop_ox:     .byte $fe, 2, 2
cop_oy:     .byte 2, $fe, 2

// ---------------------------------------------------------------- per frame
// tgt = where the player is (the bandit on foot, else the car)
set_target:
    lda state
    cmp #ST_WALK
    bne !+
    lda man_xl
    sta tgt_xl
    lda man_xh
    sta tgt_xh
    lda man_yl
    sta tgt_yl
    lda man_yh
    sta tgt_yh
    rts
!:  lda car_xl
    sta tgt_xl
    lda car_xh
    sta tgt_xh
    lda car_yl
    sta tgt_yl
    lda car_yh
    sta tgt_yh
    rts

save_car:
    ldx #5
!:  lda car_xf,x
    sta pcar,x
    dex
    bpl !-
    rts

// move all cars, check crashes, arrests and the end of a chase
npc_frame:
    lda #0
    sta busted
    sta car_hit
    jsr set_target
    ldx #13
    lda state
    cmp #ST_WALK
    bne !+
    ldx #32
!:  stx reach
    ldx #NNPC - 1
nf_loop:
    lda n_type,x
    beq nf_next
    stx ni
    jsr npc_one
    lda busted
    beq !+
    jmp bust
!:  ldx ni
nf_next:
    dex
    bpl nf_loop
    lda car_hit
    beq !+
    jsr car_bounce
!:  jsr rng_next                    // now and then a cab honks somewhere
    bne !+                          // (1 in 255 frames, about every 5 s)
    jsr honk
!:  lda chase
    beq nf_done
    lda n_type
    ora n_type + 1
    ora n_type + 2
    bne nf_done
    // every police car lost: escaped! $500 bonus
    lda #0
    sta chase
    sed
    clc
    lda score + 1
    adc #$05
    sta score + 1
    lda score + 2
    adc #0
    sta score + 2
    cld
    lda #1
    sta score_dirty
    lda #0
    sta msg_next
    lda #W_ESCAPED
    ldx #5
    jmp show_msg
nf_done:
    rts

// one car, x = slot (kept)
npc_one:
    jsr npc_delta
    lda n_type,x
    cmp #NT_COP
    beq no_cop
    // a cab: too far away -> a new one near the player
    lda nax_h
    cmp #2
    bcs no_respawn
    lda nay_h
    cmp #2
    bcs no_respawn
    jsr npc_touch
    bcc no_move
    lda state                       // in the way: the cab waits; the car
    cmp #ST_DRIVE                   // bounces off if it drove into the cab
    bne nc_wait                     // (driving away is always allowed)
    jsr cab_closer
    bcc nc_wait
    lda #1
    sta car_hit
nc_wait:
    inc n_wait,x
    lda n_wait,x
    cmp #1                          // honk when it has to stop
    bne !+
    jsr honk
!:  lda n_wait,x                    // blocked for a second: turn around
    cmp #50
    bcc !+
    lda #0
    sta n_wait,x
    lda n_dir,x
    eor #2
    sta n_dir,x
!:  rts
no_respawn:
    jmp spawn_cab
no_cop:
    lda nax_h
    cmp #3
    bcs no_gone
    lda nay_h
    cmp #2
    bcs no_gone
    lda reach                       // arrested: car to car, or on foot nearby
    jsr npc_near
    bcc !+
    lda #1
    sta busted
    rts
!:  jsr cop_uturn
    jmp no_move
no_gone:
    lda #0                          // lost him
    sta n_type,x
    rts
no_move:
    lda #0                          // not blocked (any more)
    sta n_wait,x
    // whole pixels this frame: (acc + speed) / 64
    lda n_acc,x
    clc
    adc n_spd,x
    tay
    lda #0
    rol
    sta t1
    tya
    and #63
    sta n_acc,x
    tya
    asl
    rol t1
    asl
    rol t1
    lda t1
    beq nm_done
    sta nsteps
!:  jsr npc_step
    dec nsteps
    bne !-
nm_done:
    rts

// one pixel in the current direction; at a crossing choose the next one
npc_step:
    lda n_dir,x
    beq ns_n
    cmp #2
    beq ns_s
    bcc ns_e
    lda n_xl,x                      // west
    bne !+
    dec n_xh,x
!:  dec n_xl,x
    jmp ns_node
ns_e:
    inc n_xl,x
    bne ns_node
    inc n_xh,x
    jmp ns_node
ns_s:
    inc n_yl,x
    bne ns_node
    inc n_yh,x
    jmp ns_node
ns_n:
    lda n_yl,x
    bne !+
    dec n_yh,x
!:  dec n_yl,x
ns_node:
    lda n_xl,x
    cmp #$80
    bne !+
    lda n_yl,x
    and #$7f
    cmp #$44
    bne !+
    jmp npc_choose
!:  rts

// at a crossing: valid directions, then the cab's or the cop's choice
npc_choose:
    lda #$0f
    sta vmask
    lda n_yh,x                      // top street: not north
    bne !+
    lda n_yl,x
    cmp #$44
    bne !+
    lda vmask
    and #%1110
    sta vmask
!:  lda n_yh,x                      // bottom street: not south
    cmp #3
    bne !+
    lda n_yl,x
    cmp #$c4
    bne !+
    lda vmask
    and #%1011
    sta vmask
!:  lda n_xh,x                      // first avenue: not west
    bne !+
    lda vmask
    and #%0111
    sta vmask
!:  lda n_xh,x                      // last avenue: not east
    cmp #3
    bne !+
    lda vmask
    and #%1101
    sta vmask
!:  lda n_type,x
    cmp #NT_COP
    beq nc_cop
    lda n_dir,x                     // cabs don't turn around
    eor #2
    tay
    lda vmask
    and nc_not,y
    beq nc_rand
    sta vmask
nc_rand:
    jsr rng_next
    and #3
    tay
nc_try:
    lda vmask
    and bit_tab,y
    bne nc_set
    iny
    tya
    and #3
    tay
    jmp nc_try
nc_set:
    tya
    sta n_dir,x
    rts
nc_cop:
    // towards the player, along the longer distance first
    ldy #1
    lda ndx_h
    bpl !+
    ldy #3
!:  sty t2
    ldy #2
    lda ndy_h
    bpl !+
    ldy #0
!:  sty t3
    lda nax_l
    cmp nay_l
    lda nax_h
    sbc nay_h
    bcs !+
    lda t2
    ldy t3
    sta t3
    sty t2
!:  ldy t2
    lda vmask
    and bit_tab,y
    bne nc_set
    ldy t3
    lda vmask
    and bit_tab,y
    bne nc_set
    jmp nc_rand

// a police car turns around between crossings when the player is more than
// 16 pixels behind it, near its road
cop_uturn:
    lda n_dir,x
    and #1
    bne cu_horiz
    lda nax_h
    bne cu_no
    lda nax_l
    cmp #40
    bcs cu_no
    lda nay_h                       // at least 16 pixels away
    bne !+
    lda nay_l
    cmp #16
    bcc cu_no
!:  lda n_dir,x
    bne cu_s
    lda ndy_h                       // going north, player to the south
    bmi cu_no
    lda #2
    sta n_dir,x
    rts
cu_s:
    lda ndy_h
    bpl cu_no
    lda #0
    sta n_dir,x
    rts
cu_horiz:
    lda nay_h
    bne cu_no
    lda nay_l
    cmp #40
    bcs cu_no
    lda nax_h
    bne !+
    lda nax_l
    cmp #16
    bcc cu_no
!:  lda n_dir,x
    cmp #1
    bne cu_w
    lda ndx_h                       // going east, player to the west
    bpl cu_no
    lda #3
    sta n_dir,x
    rts
cu_w:
    lda ndx_h
    bmi cu_no
    lda #1
    sta n_dir,x
cu_no:
    rts

// nd = player - car, na = |nd| (a cab keeps to the right of its road)
npc_delta:
    lda #0
    sta t4
    sta t5
    lda n_type,x
    cmp #NT_CAB
    bne !+
    ldy n_dir,x
    lda lane_x,y
    sta t4
    lda lane_y,y
    sta t5
!:  ldy #0
    lda t4
    bpl !+
    dey
!:  sty t3
    lda tgt_xl
    sec
    sbc n_xl,x
    sta ndx_l
    lda tgt_xh
    sbc n_xh,x
    sta ndx_h
    lda ndx_l
    sec
    sbc t4
    sta ndx_l
    sta nax_l
    lda ndx_h
    sbc t3
    sta ndx_h
    sta nax_h
    bpl !+
    lda #0
    sec
    sbc ndx_l
    sta nax_l
    lda #0
    sbc ndx_h
    sta nax_h
!:  ldy #0
    lda t5
    bpl !+
    dey
!:  sty t3
    lda tgt_yl
    sec
    sbc n_yl,x
    sta ndy_l
    lda tgt_yh
    sbc n_yh,x
    sta ndy_h
    lda ndy_l
    sec
    sbc t5
    sta ndy_l
    sta nay_l
    lda ndy_h
    sbc t3
    sta ndy_h
    sta nay_h
    bpl !+
    lda #0
    sec
    sbc ndy_l
    sta nay_l
    lda #0
    sbc ndy_h
    sta nay_h
!:  rts
// cabs drive 6 pixels right of the centre line (north, east, south, west)
lane_x:     .byte 6, 0, $fa, 0, 0
lane_y:     .byte 0, 6, 0, $fa, 0

// carry set if the car touches the player (both distances below 13), or
// with npc_near below a
npc_touch:
    lda #13
npc_near:
    sta t0
    lda nax_h
    bne nt_no
    lda nax_l
    cmp t0
    bcs nt_no
    lda nay_h
    bne nt_no
    lda nay_l
    cmp t0
    bcs nt_no
    sec
    rts
nt_no:
    clc
    rts

// ---------------------------------------------------------------- spawning
// a = base, t4 = signed offset, t5 = highest node -> a (mirrored if outside)
node_off:
    sta t3
    clc
    adc t4
    cmp t5
    beq !+
    bcc !+
    lda t3
    sec
    sbc t4
    cmp t5
    beq !+
    bcc !+
    lda t3
!:  rts

// the street row (0-7) the player is nearest to
player_ny:
    lda tgt_yl
    asl
    lda tgt_yh
    rol
    rts

// put car x at node (t0 = avenue 0-3, t1 = street 0-7), then choose a way
npc_at_node:
    lda #$80
    sta n_xl,x
    lda t0
    sta n_xh,x
    lda t1
    lsr
    sta n_yh,x
    lda #$44
    bcc !+
    lda #$c4
!:  sta n_yl,x
    lda #0
    sta n_acc,x
    lda #4                          // no previous direction
    sta n_dir,x
    jsr npc_delta
    jmp npc_choose

// a cab two streets above or below the player, one avenue left or right
spawn_cab:
    jsr rng_next
    and #3
    tay
    lda cab_ox,y
    sta t4
    lda #3
    sta t5
    lda tgt_xh
    jsr node_off
    sta t0
    lda cab_oy,y
    sta t4
    lda #7
    sta t5
    jsr player_ny
    jsr node_off
    sta t1
    lda #NT_CAB
    sta n_type,x
    lda #CAB_SPEED
    sta n_spd,x
    jmp npc_at_node

// after a robbery: one police car per wanted star, a few blocks away
spawn_cops:
    jsr set_target
    lda #1
    sta chase
    lda wanted                      // speed = COP_SPEED + 12 x wanted
    asl
    asl
    sta t2
    asl
    clc
    adc t2
    adc #COP_SPEED
    sta nspd
    ldx #0
sc_loop:
    cpx wanted
    bcs sc_done
    lda cop_ox,x
    sta t4
    lda #3
    sta t5
    lda tgt_xh
    jsr node_off
    sta t0
    lda cop_oy,x
    sta t4
    lda #7
    sta t5
    jsr player_ny
    jsr node_off
    sta t1
    lda #NT_COP
    sta n_type,x
    lda nspd
    sta n_spd,x
    stx ni
    jsr npc_at_node
    ldx ni
    inx
    jmp sc_loop
sc_done:
    rts

cops_off:
    lda #0
    sta n_type
    sta n_type + 1
    sta n_type + 2
    sta chase
    rts

// carry set if the car's move this frame went towards the cab (x = slot;
// nd/na = player - cab now, both small while they touch)
cab_closer:
    lda car_xl                      // before the move: nd - movement
    sec
    sbc pcar + 1
    sta t0
    lda ndx_l
    sec
    sbc t0
    jsr abs8
    sta t1
    lda car_yl
    sec
    sbc pcar + 4
    sta t0
    lda ndy_l
    sec
    sbc t0
    jsr abs8
    clc
    adc t1
    sta t1
    lda nax_l                       // closer now than before?
    clc
    adc nay_l
    cmp t1
    bcc !+
    clc
    rts
!:  sec
    rts
abs8:
    cmp #$80
    bcc !+
    eor #$ff
    adc #0                          // carry is set: + 1
!:  rts

// a cab horn on the effects voice (one of two), if it is free; x is kept
honk:
    lda sfx_on
    bne !+
    txa
    pha
    lda rng
    and #1
    clc
    adc #SFX_HONK
    jsr sfx_play
    pla
    tax
!:  rts

// ran into a cab: back to where the car was, bounce off
car_bounce:
    ldx #5
!:  lda pcar,x
    sta car_xf,x
    dex
    bpl !-
    jsr abs_speed
    lda t1
    bne !+
    lda t0
    cmp #$60
    bcs !+
    jsr honk                        // a nudge: the cabbie honks
    jmp cb_soft
!:  lda #SFX_CRASH                  // a real bump
    jsr sfx_play
cb_soft:
    lda spd_h
    cmp #$80
    ror spd_h
    ror spd_l
    lda #0
    sec
    sbc spd_l
    sta spd_l
    lda #0
    sbc spd_h
    sta spd_h
    lda #0
    sta burn
    rts

// ---------------------------------------------------------------- arrests, timer
bust:
    jsr cops_off
    lda #0
    sta wanted
    dec lives
    lda hud_dirty
    ora #2
    sta hud_dirty
    jsr last_life
    lda #SFX_CRASH
    jsr sfx_play
    lda #W_BUSTED
    ldx #2
    jmp show_msg

// msg_next = 1 if that was the last life
last_life:
    ldx #0
    lda lives
    bne !+
    inx
!:  stx msg_next
    rts

// the job timer runs while driving and walking
job_frame:
    dec job_tick
    bne jf_done
    lda #50
    sta job_tick
    sed
    lda job_time
    sec
    sbc #1
    sta job_time
    cld
    lda hud_dirty
    ora #1
    sta hud_dirty
    lda job_time
    beq jf_slow
    cmp #$11                        // the last ten seconds tick
    bcs jf_done
    lda #SFX_DOOR
    jmp sfx_play
jf_slow:
    // too slow: that job is off, try the next bank
    lda target
    clc
    adc #3
    and #NBANKS - 1
    sta target
    lda job_start
    sta job_time
    dec lives
    lda hud_dirty
    ora #3
    sta hud_dirty
    jsr last_life
    lda #W_SLOW
    ldx #3
    jmp show_msg
jf_done:
    rts

// after a robbery: time bonus (10 x seconds left), less time for the next
// job, one more wanted star and the police
job_done:
    lda job_time
    asl
    asl
    asl
    asl
    sed
    clc
    adc score
    sta score
    lda job_time
    lsr
    lsr
    lsr
    lsr
    adc score + 1
    sta score + 1
    lda score + 2
    adc #0
    sta score + 2
    lda job_start
    sec
    sbc #3
    cld
    cmp #JOB_MIN
    bcs !+
    lda #JOB_MIN
!:  sta job_start
    sta job_time
    lda #50
    sta job_tick
    lda wanted
    cmp #3
    bcs !+
    inc wanted
!:  lda hud_dirty
    ora #3
    sta hud_dirty
    jmp spawn_cops

// ---------------------------------------------------------------- messages
// a big comic bubble in the middle of the screen; the game waits for it.
// a = word, x = colour
show_msg:
    sta bub_word
    stx bub_col
    jsr clear_bubble
    ldx bub_word
    lda word_len,x
    asl
    clc
    adc #2
    sta bub_w
    lda #40
    sec
    sbc bub_w
    lsr
    sta bub_x
    lda #9
    sta bub_y
    jsr draw_bubble
    lda state
    cmp #ST_MSG
    beq !+
    sta msg_prev
!:  lda #ST_MSG
    sta state
    lda #MSG_FRAMES
    sta msg_t
    rts

do_msg:
    dec msg_t
    bne !+
    jsr clear_bubble
    lda msg_next
    beq dm_on
    jmp game_over
dm_on:
    lda msg_prev
    sta state
!:  rts

// ---------------------------------------------------------------- sound
// engine on voice 2 while driving, siren on voice 1 during a chase; the
// music player leaves a voice alone while it is taken (v1_own / v2_own)
sound_frame:
    lda scrolled                    // not on the heavy frames
    beq !+
    rts
!:  lda state
    cmp #ST_DRIVE
    bne sf_engoff
    lda #1
    sta v2_own
    jsr abs_speed
    lda t0                          // f = $0400 + 3 x |speed| (+ revs)
    asl
    sta t2
    lda t1
    rol
    sta t3
    lda t2
    clc
    adc t0
    sta t2
    lda t3
    adc t1
    sta t3
    lda burn
    beq !+
    lda t3
    clc
    adc #3
    sta t3
!:  lda vbl                         // a little rumble
    and #3
    asl
    asl
    asl
    asl
    adc t2
    sta $d407
    lda t3
    adc #4
    sta $d408
    lda #0
    sta $d409
    sta $d40c
    lda #3
    sta $d40a
    lda #$90
    sta $d40d
    lda #$41
    sta $d40b
    jmp sf_siren
sf_engoff:
    lda v2_own
    beq sf_siren
    lda #$40
    sta $d40b
    lda #0
    sta v2_own
sf_siren:
    lda chase
    beq sf_siroff
    lda state
    cmp #ST_MSG
    beq sf_siroff
    lda #1
    sta v1_own
    lda vbl                         // a wail: up and down every 2.5 seconds
    and #$7f
    cmp #$40
    bcc !+
    eor #$7f
!:  sta t0
    lsr
    clc
    adc #$20
    sta $d401
    lda t0
    ror
    lda #0
    ror
    sta $d400
    lda #0
    sta $d405
    lda #$a0
    sta $d406
    lda #$11
    sta $d404
    rts
sf_siroff:
    lda v1_own
    beq !+
    lda #$10
    sta $d404
    lda #0
    sta v1_own
!:  rts

sound_off:
    lda #0
    sta $d404
    sta $d40b
    sta v1_own
    sta v2_own
    rts

// ---------------------------------------------------------------- sprites
// police and cabs into the sprite shadows (after the player's sprites)
place_npcs:
    ldx #NNPC - 1
pn_loop:
    stx ni
    lda n_type,x
    beq pn_skip
    cpx #4                          // slot 4 shares sprite 4 with the bandit
    bne pn_show
    lda pstate
    cmp #ST_DRIVE
    beq pn_show
pn_skip:
    jmp pn_next
pn_show:
    lda n_xl,x
    sta px_l
    lda n_xh,x
    sta px_h
    lda n_yl,x
    sta py_l
    lda n_yh,x
    sta py_h
    lda n_type,x                    // cabs: in their lane
    cmp #NT_CAB
    bne pn_pos
    ldy n_dir,x
    lda lane_x,y
    ldy #px_l
    jsr add_lane
    ldy n_dir,x
    lda lane_y,y
    ldy #py_l
    jsr add_lane
pn_pos:
    lda #19
    sta t4
    lda #44
    sta t5
    ldx ni
    lda slot_spr,x
    tax
    jsr spr_pos
    bcc pn_skip
    lda sh_y,x
    cmp #SPLIT_MIN_Y
    bcs pn_ok
    lda bit_tab,x                   // under the HUD row: hidden
    eor #$ff
    and sh_en
    sta sh_en
    jmp pn_next
pn_ok:
    ldy ni
    lda n_type,y
    cmp #NT_COP
    bne pn_cab
    lda n_dir,y
    clc
    adc #SP_COP
    sta sh_ptr,x
    ldy #6
    lda vbl
    and #8
    beq !+
    ldy #2
!:  tya
    sta sh_col,x
    jmp pn_next
pn_cab:
    lda n_dir,y
    asl
    asl
    adc #SP_CAR
    sta sh_ptr,x
    lda #7
    sta sh_col,x
pn_next:
    ldx ni
    dex
    bmi !+
    jmp pn_loop
!:  rts

// add signed a to the 16-bit zero page value at y
add_lane:
    cmp #0
    beq al_done
    bmi al_neg
    clc
    adc $00,y
    sta $00,y
    bcc al_done
    lda $01,y
    adc #0
    sta $01,y
    rts
al_neg:
    clc
    adc $00,y
    sta $00,y
    bcs al_done
    lda $01,y
    sbc #0
    sta $01,y
al_done:
    rts
