// Boogie Bandit - police, traffic, the job timer, lives, messages, engine
// and siren. Imported by boogie.asm.
//
// Police cars and cabs drive on the centre lines of the road grid: avenue
// centres at x = 128 + 256 k (k = 0-3), street centres at y = 68 + 128 j
// (j = 0-7). At every crossing (a "node") they pick a new direction: cabs
// at random, police towards the player. Five slots, shown with the hardware
// sprites in slot_spr; sprites 0-3 and 7 are shared with the HUD row at the
// top (the raster IRQ splits them at SPLIT_LINE).
//
// Slots 0-2 are police (NT_COP chasing, NT_LOST after a new paint job,
// NT_BLOCK a roadblock, only in slot 2), slots 3-4 cabs. While a police car
// has stopped and its officer is out shooting, slot 3 is the officer
// (NT_OFF); its cab comes back when he gets in again.
//
// How tough the police are depends on `jobs`, the banks robbed this game:
// they get faster with every job, shoot from SHOOT_JOBS on and set up
// roadblocks from BLOCK_JOBS on. The first chase is one slow car.

slot_spr:   .byte 7, 0, 1, 2, 4
nc_not:     .byte %1110, %1101, %1011, %0111, $ff, $ff, $ff, $ff
cab_ox:     .byte $ff, 1, $ff, 1
cab_oy:     .byte $fe, $fe, 2, 2
cop_ox:     .byte $fe, 2, 2
cop_oy:     .byte 2, $fe, 2
paint_cols: .byte 2, 5, 14, 4, 8, 10
.const NPAINT = 6

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
    lda shoot_cd
    beq !+
    dec shoot_cd
!:  lda block_cd
    beq !+
    dec block_cd
!:  jsr set_target
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
    jsr bullet_frame
    lda busted
    beq !+
    jmp bust
!:  lda car_hit
    beq !+
    jsr car_bounce
!:  jsr rng_next                    // now and then a cab honks somewhere
    bne !+                          // (1 in 255 frames, about every 5 s)
    jsr honk
!:  lda chase
    beq nf_done
    jsr block_try
    ldx #2                          // any police car still on the trail?
!:  lda n_type,x
    cmp #NT_COP
    beq nf_done
    dex
    bpl !-
    // every police car lost: escaped! $500 bonus
    jsr chase_over
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

// the chase is over: the roadblock goes, the officer gets in, no bullets
chase_over:
    lda #0
    sta chase
    sta bul_t
    lda n_type + 2
    cmp #NT_BLOCK
    bne !+
    lda #0
    sta n_type + 2
!:  lda officer
    bmi !+
    jmp officer_in
!:  rts

// one car, x = slot (kept, or in ni)
npc_one:
    jsr npc_delta
    lda n_type,x
    cmp #NT_COP
    bne !+
    jmp no_cop
!:  cmp #NT_OFF
    bne !+
    jsr npc_touch                   // the officer grabs a bandit who comes close
    bcc no_rts
    lda #1
    sta busted
no_rts:
    rts
!:  cmp #NT_BLOCK
    bne !+
    jmp nb_block
!:
    // a cab (or a police car that lost the trail): too far away -> a new
    // cab near the player (the police car just goes)
    lda nax_h
    cmp #2
    bcs no_respawn
    lda nay_h
    cmp #2
    bcs no_respawn
    jsr npc_touch
    bcs !+
    jmp no_move
!:  lda state                       // in the way: the cab waits; the car
    cmp #ST_DRIVE                   // bounces off if it drove into the cab
    bne nc_wait                     // (driving away is always allowed)
    jsr cab_closer
    bcc nc_wait
    lda #1
    sta car_hit
nc_wait:
    lda #0
    sta n_cur,x
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
    lda n_type,x
    cmp #NT_CAB
    beq !+
    lda #0
    sta n_type,x
    rts
!:  jmp spawn_cab
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
!:  lda n_wait,x                    // stopped, the officer is out
    beq !+
    jmp cop_out
!:  jsr cop_stop                    // or stop now and get out
    bcc !+
    rts
!:  lda n_dir,x                     // a U-turn starts from standstill
    sta odir
    jsr cop_uturn
    lda n_dir,x
    cmp odir
    beq no_move
    lda #0
    sta n_cur,x
    jmp no_move
no_gone:
    cpx officer                     // lost him (the officer gets in first)
    bne !+
    jsr officer_in
    ldx ni
!:  lda #0
    sta n_type,x
    rts
no_move:
    lda #0                          // not blocked (any more)
    sta n_wait,x
    lda n_cur,x                     // speed up to the cruising speed
    cmp n_spd,x
    bcs !+
    adc #COP_ACCEL
    cmp n_spd,x
    bcc !++
!:  lda n_spd,x
!:  sta n_cur,x
    // whole pixels this frame: (acc + speed) / 64
    clc
    adc n_acc,x
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
    tya                             // a turn: slow down for the corner
    cmp n_dir,x
    beq nc_keep
    sta n_dir,x
    lda n_cur,x
    lsr
    sta n_cur,x
nc_keep:
    rts
nc_cop:
    // keep going straight while that still leads to the player (more than
    // half a block to go that way): fewer turns, no zigzag
    ldy n_dir,x
    cpy #4
    bcs nc_pick
    lda vmask
    and bit_tab,y
    beq nc_pick
    tya
    and #1
    bne nk_h
    lda nay_h
    bne !+
    lda nay_l
    cmp #64
    bcc nc_pick
!:  lda ndy_h
    cpy #0
    bne !+
    cmp #$80                        // north: the player is above
    bcs nc_keep
    bcc nc_pick
!:  cmp #$80                        // south: below
    bcc nc_keep
    bcs nc_pick
nk_h:
    lda nax_h
    bne !+
    lda nax_l
    cmp #128
    bcc nc_pick
!:  lda ndx_h
    cpy #1
    bne !+
    cmp #$80                        // east: to the right
    bcc nc_keep
    bcs nc_pick
!:  cmp #$80                        // west: to the left
    bcs nc_keep
nc_pick:
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
    bne nc_set2
    ldy t3
    lda vmask
    and bit_tab,y
    bne nc_set2
    jmp nc_rand
nc_set2:
    jmp nc_set

// a police car turns around between crossings when the player is more than
// 48 pixels behind it, near its road
cop_uturn:
    lda n_dir,x
    and #1
    bne cu_horiz
    lda nax_h
    bne cu_no
    lda nax_l
    cmp #40
    bcs cu_no
    lda nay_h                       // at least 48 pixels away
    bne !+
    lda nay_l
    cmp #48
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
    cmp #48
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

// the direction 0-3 (N E S W) from the car in x to the player (longer axis)
face_dir:
    lda nax_l
    cmp nay_l
    lda nax_h
    sbc nay_h
    bcc fd_v
    lda #1
    ldy ndx_h
    bpl !+
    lda #3
!:  rts
fd_v:
    lda #2
    ldy ndy_h
    bpl !+
    lda #0
!:  rts

// ---------------------------------------------------------------- shooting
// a police car near the player stops and the officer gets out (carry set):
// from SHOOT_JOBS on, one at a time, both on screen, not too close
cs_no:
    clc
    rts
cop_stop:
    lda jobs
    cmp #SHOOT_JOBS
    bcc cs_no
    lda officer
    bpl cs_no
    lda shoot_cd
    bne cs_no
    lda nax_h
    ora nay_h
    bne cs_no
    lda nax_l
    cmp #120
    bcs cs_no
    lda nay_l
    cmp #90
    bcs cs_no
    lda nax_l                       // at least 32 pixels away
    cmp #32
    bcs !+
    lda nay_l
    cmp #32
    bcc cs_no
!:  ldy slot_spr,x                  // the police car was on screen
    lda bit_tab,y
    and sh_en
    beq cs_no
    lda n_type + 3                  // and slot 3's cab was not (its sprite
    beq !+                          // becomes the officer)
    lda sh_en
    and #%00000100
    bne cs_no
!:  stx officer
    lda #OUT_FRAMES
    sta n_wait,x
    lda #0
    sta n_cur,x
    lda n_xl,x
    sta n_xl + 3
    lda n_xh,x
    sta n_xh + 3
    lda n_yl,x
    sta n_yl + 3
    lda n_yh,x
    sta n_yh + 3
    lda #NT_OFF
    sta n_type + 3
    lda #0
    sta n_wait + 3
    // beside the car, on the player's side
    lda n_dir,x
    and #1
    bne cs_h
    lda #14
    ldy ndx_h
    bpl !+
    lda #256 - 14
!:  jsr add_ox
    jmp cs_face
cs_h:
    lda #14
    ldy ndy_h
    bpl !+
    lda #256 - 14
!:  jsr add_oy
cs_face:
    jsr face_dir
    sta n_dir + 3
    lda #SFX_DOOR
    jsr sfx_play
    ldx ni
    sec
    rts

// signed a added to the officer's x / y
add_ox:
    ldy #0
    cmp #$80
    bcc !+
    dey
!:  clc
    adc n_xl + 3
    sta n_xl + 3
    tya
    adc n_xh + 3
    sta n_xh + 3
    rts
add_oy:
    ldy #0
    cmp #$80
    bcc !+
    dey
!:  clc
    adc n_yl + 3
    sta n_yl + 3
    tya
    adc n_yh + 3
    sta n_yh + 3
    rts

// the police car x has stopped: the officer turns to the player, shoots
// twice and gets back in
cop_out:
    dec n_wait,x
    bne !+
    jmp officer_in
!:  ldx #3
    jsr npc_delta
    jsr face_dir
    sta n_dir + 3
    ldx ni
    lda n_wait,x
    cmp #OUT_FRAMES - 25
    beq fire_bullet
    cmp #OUT_FRAMES - 60
    beq fire_bullet
    rts

// a bullet from the officer towards the player (nd from npc_delta of slot
// 3): one of 8 directions, 3 pixels a frame (2 + 2 diagonally)
fire_bullet:
    lda bul_t
    beq !+
    rts
!:  lda n_xl + 3
    sta bul_xl
    lda n_xh + 3
    sta bul_xh
    lda n_yl + 3
    sec
    sbc #4                          // from the hand, not the feet
    sta bul_yl
    lda n_yh + 3
    sbc #0
    sta bul_yh
    lda #0
    sta bul_dx
    sta bul_dy
    lda nax_l                       // sideways if 2 |dx| >= |dy|
    asl
    sta t0
    lda nax_h
    rol
    sta t1
    lda t0
    cmp nay_l
    lda t1
    sbc nay_h
    bcc !++
    lda #1
    ldy ndx_h
    bpl !+
    lda #$ff
!:  sta bul_dx
!:  lda nay_l                       // up or down if 2 |dy| >= |dx|
    asl
    sta t0
    lda nay_h
    rol
    sta t1
    lda t0
    cmp nax_l
    lda t1
    sbc nax_h
    bcc !++
    lda #1
    ldy ndy_h
    bpl !+
    lda #$ff
!:  sta bul_dy
!:  lda #3
    ldy bul_dx
    beq !+
    ldy bul_dy
    beq !+
    lda #2
!:  sta t0
    lda bul_dx
    jsr fb_scale
    sta bul_dx
    lda bul_dy
    jsr fb_scale
    sta bul_dy
    lda #BULLET_FRAMES
    sta bul_t
    lda #SFX_SHOT
    jmp sfx_play
fb_scale:                           // -1/0/1 -> -t0/0/t0
    beq !+
    bmi fs_neg
    lda t0
!:  rts
fs_neg:
    lda #0
    sec
    sbc t0
    rts

// the officer gets back in, his cab comes back later; x is not kept
officer_in:
    ldx officer
    lda #0
    sta n_wait,x
    sta n_cur,x
    lda #$ff
    sta officer
    lda #SHOOT_CD
    sta shoot_cd
    ldx #3
    jmp spawn_cab

// a bullet in flight: move it, stop it at a building, hit the player?
bullet_frame:
    lda bul_t
    bne !+
    rts
!:  dec bul_t
    bne !+
    rts
!:  lda bul_dx
    ldy #0
    cmp #$80
    bcc !+
    dey
!:  clc
    adc bul_xl
    sta bul_xl
    tya
    adc bul_xh
    sta bul_xh
    lda bul_dy
    ldy #0
    cmp #$80
    bcc !+
    dey
!:  clc
    adc bul_yl
    sta bul_yl
    tya
    adc bul_yh
    sta bul_yh
    cmp #4                          // off the map
    bcs bf_kill
    lda bul_xh
    cmp #4
    bcs bf_kill
    // the map character under it: a building stops it
    lda bul_yl
    sta t0
    lda bul_yh
    lsr
    ror t0
    lsr
    ror t0
    lsr
    ror t0
    ldx t0
    lda mrow_lo,x
    sta zp0
    lda mrow_hi,x
    sta zp0 + 1
    lda bul_xl
    sta t0
    lda bul_xh
    lsr
    ror t0
    lsr
    ror t0
    lsr
    ror t0
    ldy t0
    lda (zp0),y
    tax
    lda class_tab,x
    and #1
    bne bf_kill
    // the player?
    lda #8
    sta t1
    lda tgt_xl
    sec
    sbc bul_xl
    sta t0
    lda tgt_xh
    sbc bul_xh
    jsr small16
    bcc bf_done
    lda #9
    sta t1
    lda tgt_yl
    sec
    sbc bul_yl
    sta t0
    lda tgt_yh
    sbc bul_yh
    jsr small16
    bcc bf_done
    lda #1
    sta busted
bf_kill:
    lda #0
    sta bul_t
bf_done:
    rts

// carry set if the signed 16-bit value a:t0 is between -t1 and t1
small16:
    cmp #0
    bne !+
    lda t0
    cmp t1
    bcs s16_no
    sec
    rts
!:  cmp #$ff
    bne s16_no
    lda #0
    sec
    sbc t0
    cmp t1
    bcs s16_no
    sec
    rts
s16_no:
    clc
    rts

// ---------------------------------------------------------------- roadblocks
// from BLOCK_JOBS on, during a chase: a police car parked across the road
// (slot 2) a couple of blocks ahead of the car, out of sight. It arrests a
// car that drives into it; there is just room on the sidewalk to squeeze by.
bt_no:
    rts
block_try:
    lda jobs
    cmp #BLOCK_JOBS
    bcc bt_no
    lda n_type + 2
    bne bt_no
    lda block_cd
    bne bt_no
    lda state
    cmp #ST_DRIVE
    bne bt_no
    lda #50                         // no spot now: try again in a second
    sta block_cd
    lda vx_h                        // which way is the car going?
    jsr abs8
    sta t0
    lda vy_h
    jsr abs8
    sta t1
    cmp t0
    bcs bt_vert
    lda t0                          // east or west: across the street,
    beq bt_no                       // midway between two avenues
    lda vx_h
    bmi !+
    lda tgt_xh
    clc
    adc #2
    cmp #4
    bcs bt_no
    bcc bt_hset
!:  lda tgt_xh
    sec
    sbc #1
    beq bt_no
    bcc bt_no
bt_hset:
    sta n_xh + 2
    lda #0
    sta n_xl + 2
    sta n_dir + 2                   // facing north, stretched up and down
    jsr player_ny
    lsr
    sta n_yh + 2
    lda #$44
    bcc !+
    lda #$c4
!:  sta n_yl + 2
    jmp bt_set
bt_vert:
    lda t1                          // north or south: across the avenue,
    beq bt_no                       // midway between two streets
    jsr player_ny
    ldy vy_h
    bmi !+
    clc
    adc #2
    cmp #7
    bcs bt_no
    bcc bt_vset
!:  sec
    sbc #3
    bcc bt_no
bt_vset:
    tay                             // y = 132 + 128 m
    clc
    adc #1
    lsr
    sta n_yh + 2
    tya
    and #1
    beq !+
    lda #$04
    bne !++
!:  lda #$84
!:  sta n_yl + 2
    lda tgt_xh
    sta n_xh + 2
    lda #$80
    sta n_xl + 2
    lda #1                          // facing east, stretched sideways
    sta n_dir + 2
bt_set:
    lda #NT_BLOCK
    sta n_type + 2
    rts

// a roadblock (x = slot 2): far behind -> gone; touched -> busted
nb_block:
    lda nax_h
    cmp #2
    bcs nb_gone
    lda nay_h
    cmp #2
    bcs nb_gone
    ora nax_h
    bne nb_ok
    lda n_dir,x
    beq nb_v
    lda nax_l                       // across an avenue: 40 wide, 12 high
    cmp #26
    bcs nb_ok
    lda nay_l
    cmp #14
    bcs nb_ok
    bcc nb_bust
nb_v:
    lda nax_l                       // across a street: 12 wide, 40 high
    cmp #14
    bcs nb_ok
    lda nay_l
    cmp #26
    bcs nb_ok
nb_bust:
    lda #1
    sta busted
nb_ok:
    rts
nb_gone:
    lda #0
    sta n_type,x
    lda #100
    sta block_cd
    rts

// ---------------------------------------------------------------- paint garages
// standing still in a spray booth during a chase: the car gets a new colour
// for $300 and every police car loses the trail
paint_check:
    lda state
    cmp #ST_DRIVE
    bne pc_out
    lda chase
    beq pc_out
    lda car_yl                      // the map character under the car, 6
    sec                             // pixels above its middle (the booths
    sbc #6                          // open to the south: nose in is enough)
    sta t0
    lda car_yh
    sbc #0
    lsr
    ror t0
    lsr
    ror t0
    lsr
    ror t0
    ldx t0
    lda mrow_lo,x
    sta zp0
    lda mrow_hi,x
    sta zp0 + 1
    lda car_xl
    sta t0
    lda car_xh
    lsr
    ror t0
    lsr
    ror t0
    lsr
    ror t0
    ldy t0
    lda (zp0),y
    tax
    lda class_tab,x
    and #CL_PAINT
    beq pc_out
    jsr abs_speed                   // nearly stopped
    lda t1
    bne pc_rts
    lda t0
    cmp #$40
    bcs pc_rts
    inc paint_t
    lda paint_t
    and #15
    cmp #1
    bne !+
    lda #SFX_SPRAY
    jsr sfx_play
!:  lda paint_t
    cmp #PAINT_FRAMES
    bcc pc_rts
    jsr new_paint
pc_out:
    lda #0
    sta paint_t
pc_rts:
    rts

new_paint:
    ldx car_col_i
    inx
    cpx #NPAINT
    bcc !+
    ldx #0
!:  stx car_col_i
    lda paint_cols,x
    sta car_col
    sed                             // $300 for the paint job
    sec
    lda score + 1
    sbc #$03
    sta score + 1
    lda score + 2
    sbc #0
    sta score + 2
    cld
    bcs !+
    lda #0
    sta score
    sta score + 1
    sta score + 2
!:  lda #1
    sta score_dirty
    lda #SFX_CHING
    jsr sfx_play
    // the police look for a red car...
lose_cops:
    ldx #2
!:  lda n_type,x
    cmp #NT_COP
    bne !+
    lda #NT_LOST
    sta n_type,x
    lda #0
    sta n_wait,x
!:  dex
    bpl !--
    rts                             // (npc_frame ends the chase: escaped!)

// a car stolen during a chase: police very near the bandit (about 120
// pixels) saw it and stay after him, otherwise every one loses the trail
.const SEE_DIST = 120
steal_seen:
    lda chase
    beq sn_rts
    ldx #2
sn_loop:
    lda n_type,x
    cmp #NT_COP
    bne sn_next
    lda #SEE_DIST
    sta t1
    lda n_xl,x
    sec
    sbc man_xl
    sta t0
    lda n_xh,x
    sbc man_xh
    jsr small16
    bcc sn_next
    lda n_yl,x
    sec
    sbc man_yl
    sta t0
    lda n_yh,x
    sbc man_yh
    jsr small16
    bcs sn_rts                      // seen
sn_next:
    dex
    bpl sn_loop
    jmp lose_cops
sn_rts:
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
    sta n_cur,x
    sta n_wait,x
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

// after a robbery: one police car per wanted star, a few blocks away;
// faster with every bank robbed, at most two once there are roadblocks
spawn_cops:
    jsr cops_off
    jsr set_target
    lda #1
    sta chase
    lda jobs                        // speed = COP_SPEED + 12 x jobs
    asl
    asl
    sta t2
    asl
    clc
    adc t2
    adc #COP_SPEED
    cmp #COP_MAX
    bcc !+
    lda #COP_MAX
!:  sta nspd
    lda wanted
    ldx jobs
    cpx #BLOCK_JOBS
    bcc !+
    cmp #3
    bcc !+
    lda #2
!:  sta ncops
    ldx #0
sc_loop:
    cpx ncops
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
    lda #20                         // the first roadblock after a moment
    sta block_cd
    rts

// all police gone (busted, a new chase)
cops_off:
    lda officer
    bmi !+
    jsr officer_in
!:  lda #0
    sta n_type
    sta n_type + 1
    sta n_type + 2
    sta chase
    sta bul_t
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
    jsr impound
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

// arrested: the police take the car (he goes on on foot from where he was)
// and the loot of the last job
impound:
    lda state
    cmp #ST_DRIVE
    bne !+
    lda car_xl
    sta man_xl
    lda car_xh
    sta man_xh
    lda car_yl
    sta man_yl
    lda car_yh
    sta man_yh
    lda #2
    sta man_dir
!:  lda #0
    sta have_car
    sta man_anim
    sta spd_l
    sta spd_h
    sta burn
    sta paint_t
    lda #ST_WALK
    sta state
    lda bag
    beq im_rts
    lda #0
    sta bag
    sed
    sec
    lda score + 1
    sbc loot
    sta score + 1
    lda score + 2
    sbc #0
    sta score + 2
    cld
    bcs !+
    lda #0
    sta score
    sta score + 1
    sta score + 2
!:  lda #1
    sta score_dirty
im_rts:
    rts

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
!:  lda jobs
    cmp #9
    bcs !+
    inc jobs
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
// police, officer and cabs into the sprite shadows (after the player's)
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
    lda #19
    sta t4
    lda #44
    sta t5
    lda n_type,x
    cmp #NT_CAB                     // cabs: in their lane
    bne pn_off
    ldy n_dir,x
    lda lane_x,y
    ldy #px_l
    jsr add_lane
    ldx ni
    ldy n_dir,x
    lda lane_y,y
    ldy #py_l
    jsr add_lane
    jmp pn_pos
pn_off:
    cmp #NT_OFF                     // the officer: a man sprite
    bne pn_blk
    lda #37
    sta t5
    bne pn_pos
pn_blk:
    cmp #NT_BLOCK                   // a roadblock is stretched across
    bne pn_pos
    lda n_dir,x
    beq !+
    lda #7
    sta t4
    bne pn_pos
!:  lda #33
    sta t5
pn_pos:
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
    cmp #NT_CAB
    beq pn_cab
    cmp #NT_OFF
    beq pn_man
    lda n_dir,y                     // police car, lights flashing
    clc
    adc #SP_COP
    sta sh_ptr,x
    lda n_type,y
    cmp #NT_BLOCK
    bne pn_light
    lda n_dir,y
    php
    lda bit_tab,x
    plp
    beq !+
    ora sh_xexp
    sta sh_xexp
    jmp pn_light
!:  ora sh_yexp
    sta sh_yexp
pn_light:
    ldy #6
    lda vbl
    and #8
    beq !+
    ldy #2
!:  tya
    sta sh_col,x
    jmp pn_next
pn_man:
    lda n_dir,y
    asl
    adc #SP_MAN
    sta sh_ptr,x
    lda #6
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
