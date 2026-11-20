// =====================================================================
//  BOOGIE BANDIT - a top-down 1970s New York getaway game for the C64
//  6502 assembly for KickAssembler. Build with build.bat.
// =====================================================================
//
// Memory map (all RAM, KERNAL and BASIC banked out, $01 = $35):
//   $0200-$02ff  skid mark ring buffer        $0300-$03ff  music/sprite arrays
//   $0801-$7fff  program and packed data      $8000-$bfff  city map 128x128 chars
//   VIC bank 3:  $c000 screen A, $c400 screen B (double buffered),
//                $c800 sprites (HUD, bandit, marker, title text),
//                $d000 charset (under I/O), $d800 sprites (car, arrow; under I/O),
//                $e000 title bitmap (only on the title screen).

#import "version.asm"
#import "gfx_lib.asm"
#import "gfx_city.asm"
#import "gfx_sprites.asm"
#import "gfx_intro.asm"

// ---------------------------------------------------------------- constants
.const ROAD_COL = 12            // $d021 asphalt (grey)
.const WALK_COL = 15            // $d022 sidewalks (light grey)
.const LAWN_COL = 5             // $d022 in the suburb: grass (green)
.const GREEN_BASE = 55           // raster line of world y = cam_y (row 0 of the screen at fine y 0)
.const ROOF_COL = 0             // $d023 roofs, tyre marks (black)
.const HI_COL = 7               // color RAM: yellow (title, map; the city gets band_tab per block row)
.const COLRAM = $08 | HI_COL    // multicolor + yellow

.const SCR_A = $c000
.const SCR_B = $c400
.const SPRLO = $c800
.const CHARSET = $d000
#if REU
.const NEWS_OV = $c400              // the REU edition: the newspaper code runs in screen B
.const R_NEWS_OV = 0                // REU addresses: its code, the page
.const R_SCREEN = $0400
.const R_COLOUR = R_SCREEN + 1024
.const R_BADGE = R_COLOUR + 1024   // the title's REU badge: 40 bitmap bytes, 5 screen, 5 colour
.const R_TUNE2 = R_BADGE + 50      // the driving tunes' blocks (TUNE_LEN bytes each;
                                    // R_TUNE1 in the gap after the newspaper code,
                                    // R_TUNE0 stashed from the program at start);
                                    // then the thoughts' glyphs and texts
.const R_BITMAP = $8000             // the page's bitmap (packed in the program, unpacked at start)
.const R_TUNE0 = R_BITMAP + 8000    // "Getaway Groove", from the program
.const R_THINK = $a400              // the thinking overlay (its RAM image, 3 pages)
.const R_SWAP = R_THINK + $300      // what was in its place meanwhile
.const R_CSAVE = R_SWAP + $300      // the charset while it borrows characters
.const R_HID = R_CSAVE + $800       // a page of the hidden screen meanwhile
.const THINK_OV = $0400             // the overlay runs over COPSTORE (swapped out meanwhile)
.const THINK_STUB = $ff40           // its entry, after the bitmap (186 bytes up to the vectors)
.const REU_TITLE = $0100            // page 1 (under the stack): fetch the REU code,
.const REU_NEWS = $0103             // run its badge or newspaper part (rts without an REU);
                                    // REU_TUNE (a label in page 1): a new job, a new tune
#endif
.const SPRHI = $d800
.const BITMAP = $e000
.const COPSPR = $f800            // police car sprites 224-239 (after the B->A shift)
.const COPSTORE = $0400          // their copy, 12 sprites (the bitmap screens overwrite $f800)
.const GUARDSPR = $fb00           // the guard sprites 236-243 (copied from guard_spr)
.const SP_GUARD = 236             // + dir*2 + step
.const MUSSTORE = $0700          // the chase tune (music.asm), 256 bytes
.const TAIL_PAGES = 7            // the tables moved out of the program (see tail_src)
.const TEMP = $e000               // where they wait during start-up
.const BLOCKS = $8000            // the city block designs (512 bytes each), then
.const PRIV = BLOCKS + NBLOCKS * 512   // NPRIV private copies, then the grid
.const GRID = PRIV + NPRIV * 512        // (GW x GH: the page of each block)
.const MT_CB = GRID + 256         // map_at tables (see blockBytes)
.const MT_CY = MT_CB + 256
.const MT_RG = MT_CY + 256
.const MT_RH = MT_RG + 256
.const MT_RL = MT_RH + 256
.const DANCE_SRC = MT_RL + 256      // the 4 dancer sprites (copied to DANCE_SPR for the score page)
.const GRID_ORIG = DANCE_SRC + 256    // the city grid as built (GRID is reset from it every game)
.const MM_CODE = GRID_ORIG + GW * GH    // the city map screen: what each character shows as (mapCode)
.const WORD_GLYPHS = MM_CODE + 256  // the comic bubble glyphs (wordGlyphs) and their
.const GL_TL = WORD_GLYPHS + wordGlyphs.size()   // corner characters
.const GL_TR = GL_TL + glTL.size()
.const GL_BL = GL_TR + glTR.size()
.const GL_BR = GL_BL + glBL.size()
.const GREET_GLY = GL_BR + glBR.size()  // the greeting font: 14 letters, 7 rows each
.const DANCE_SPR = $c400            // (screen B, unused on the title pages): sprites 16-19
.const D018_A = $04             // screen $c000, chars $d000
.const D018_B = $14             // screen $c400, chars $d000
.const IRQ_LINE = 250

.const CAMX_MAX = 2048 - 313    // the world is 256 x 256 characters
.const CAMY_MAX = 2048 - 193

.const ST_DRIVE = 0
.const ST_WALK = 1
.const ST_ROB = 2
.const ST_MSG = 3                // a message bubble (BUSTED! ...), the game waits

.const MAXSPD = $0300           // 3.0 pixels a frame
.const THROW_SPEED = $0200      // hitting a cab this fast throws Vinnie out
.const FLY_FRAMES = 32
.const REVMAX = $0100
.const ACCEL = 6
.const BRAKE = 14
.const DRAG = 3
.const ROB_FRAMES = 200         // 4 seconds in a card shop
.const BANK_FRAMES = 150        // 3 seconds in a bank
.const BUBBLE_FRAMES = 30         // a bubble every 0.6 s
.const SFX_POW = 0
.const SFX_CRASH = 1
.const SFX_CHING = 2
.const SFX_DOOR = 3
.const SFX_STEP = 4
.const SFX_HONK = 5             // and 6: the second horn

.const NBANKS = bankDoorX.size()
// police, cabs, jobs (chase.asm)
.const NNPC = 5
.const NT_COP = 1
.const NT_CAB = 2
.const NT_OFF = 3                // a police officer on foot (slot 3), shooting
.const NT_LOST = 4               // a police car that lost the trail (new paint)
.const NT_BLOCK = 5              // a roadblock (slot 2)
.const NT_FOOT = 6               // a guard / shop owner running after the bandit (slot 3)
.const FOOT_DELAY = 100          // frames the guard stands in the door (seen, harmless)
.const FOOT_TIME = 200           // he gives up after 4 x this many frames (16 s)
.const FOOT_SPEED = 176          // 1/256 pixels a frame: 0.69, + 8 a job (the bandit does 1)
.const FOOT_MAX = 232            // 0.91
.const FOOT_REACH = 10           // closer than this on foot: BUSTED!
.const FOOT_WALL = 48            // steps along a wall before he tries straight again
.const CAB_SPEED = 96            // 1/64 pixels a frame: 1.5
.const BUS_SLOT = 3              // the cab in this slot is a city bus (slower, longer)
.const BUS_SPEED = 72            // 1.1
.const BUS_WAIT = 100            // 2 seconds at a stop
.const BUS_MAX = $0200           // hijacked, it does 2 pixels a frame (the car 3)
.const BUS_COL = 6               // its stripes: blue
.const BUS_Y = mod((BLK_Y0 + BUS_ROW) * 8 + 4 + 1024, 128)   // its stops: y mod 128 (gfx_city.asm)
.const COP_SPEED = 100           // 1.6, + 12 for each bank robbed (at most COP_MAX)
.const COP_MAX = 172             // 2.7 (the car does 3)
.const COP_ACCEL = 3             // police and cabs speed up by this a frame
.const SHOOT_JOBS = 2            // the police shoot from the second robbery on
.const BLOCK_JOBS = 3            // ... and set up roadblocks from the third
.const OUT_FRAMES = 100          // an officer stays out 2 seconds, two shots
.const SHOOT_CD = 200            // then nobody gets out for 4 seconds
.const BULLET_FRAMES = 40
.const PAINT_FRAMES = 50         // 1 second in the spray booth
.const SFX_SHOT = 7
.const SFX_SPRAY = 8
.const MSG_FRAMES = 100
.const W_BUSTED = 16             // message words (gfx_city.asm)
.const W_ESCAPED = 17
.const W_SLOW = 18
.const W_SAFE = 19
.const W_HOT = 20
.const W_COPS = 21
.const W_GREET = 22             // a blank bubble the greeting is written into
.const FRIEND = NBANKS            // door_xl/... index of the friend's driveway
.const GARAGE0 = NBANKS + 1       // door_xl/... index of the first paint garage
.const NGARAGE = garageX.size()
.const SPLIT_LINE = 80           // the HUD sprites end at line 76
.const SPLIT_MIN_Y = 88          // shared sprites only below the HUD row
.const JOB_TIME = $60            // seconds (BCD) for the first job
.const JOB_MIN = $30


// ---------------------------------------------------------------- zero page
.var zpNext = $02
.function zalloc(n) {
    .var a = zpNext
    .eval zpNext = zpNext + n
    .return a
}
.label zsrc = zalloc(2)
.label zdst = zalloc(2)
.label zp0 = zalloc(2)
.label zp1 = zalloc(2)
.label mzp = zalloc(2)
.label sfx_ptr = zalloc(2)
.label t0 = zalloc(1)
.label t1 = zalloc(1)
.label t2 = zalloc(1)
.label t3 = zalloc(1)
.label t4 = zalloc(1)
.label t5 = zalloc(1)
.label frame_ready = zalloc(1)
.label shown = zalloc(1)
.label fps_tick = zalloc(1)
.label fps_val = zalloc(1)
.label fps_shown = zalloc(1)
.label vbl = zalloc(1)
.label joy = zalloc(1)
.label joy_prev = zalloc(1)
.label joy_new = zalloc(1)
.label joy_ovr = zalloc(1)      // test hook: OR'ed into the joystick (1 up 2 down 4 left 8 right $10 fire)
.label keys_prev = zalloc(1)
.label debug_bar = zalloc(1)
.label music_on = zalloc(1)
.label state = zalloc(1)
.label rng = zalloc(1)
.label car_xf = zalloc(1)
.label car_xl = zalloc(1)
.label car_xh = zalloc(1)
.label car_yf = zalloc(1)
.label car_yl = zalloc(1)
.label car_yh = zalloc(1)
.label hdg_f = zalloc(1)
.label hdg = zalloc(1)
.label mang = zalloc(1)
.label spd_l = zalloc(1)
.label spd_h = zalloc(1)
.label vx_l = zalloc(1)
.label vx_h = zalloc(1)
.label vy_l = zalloc(1)
.label vy_h = zalloc(1)
.label burn = zalloc(1)
.label skid = zalloc(1)
.label bump = zalloc(1)
.label car_frame = zalloc(1)
.label man_xl = zalloc(1)
.label man_xh = zalloc(1)
.label man_yl = zalloc(1)
.label man_yh = zalloc(1)
.label man_dir = zalloc(1)
.label man_anim = zalloc(1)
.label bag = zalloc(1)
.label cam_xf = zalloc(1)
.label cam_xl = zalloc(1)
.label cam_xh = zalloc(1)
.label cam_yf = zalloc(1)
.label cam_yl = zalloc(1)
.label cam_yh = zalloc(1)
.label ncx = zalloc(1)
.label ncy = zalloc(1)
.label disp_cx = zalloc(1)
.label disp_cy = zalloc(1)
.label ddx = zalloc(1)
.label ddy = zalloc(1)
.label front = zalloc(1)
.label front_hi = zalloc(1)
.label back_hi = zalloc(1)
.label target = zalloc(1)
.label rob_l = zalloc(1)
.label rob_h = zalloc(1)
.label bub_cd = zalloc(1)
.label bub_n = zalloc(1)
.label bub_on = zalloc(1)
.label bub_x = zalloc(1)
.label bub_y = zalloc(1)
.label bub_w = zalloc(1)
.label bub_col = zalloc(1)
.label bub_word = zalloc(1)
.label score = zalloc(3)        // BCD, lowest byte first
.label score_dirty = zalloc(1)
.label sh_d018 = zalloc(1)
.label sh_d016 = zalloc(1)
.label sh_d011 = zalloc(1)
.label sh_msb = zalloc(1)
.label sh_en = zalloc(1)
.label px_l = zalloc(1)
.label px_h = zalloc(1)
.label py_l = zalloc(1)
.label py_h = zalloc(1)
.label mcol = zalloc(1)
.label mrow = zalloc(1)
.label bmask = zalloc(1)
.label bhw = zalloc(1)
.label bx_l = zalloc(1)
.label bx_h = zalloc(1)
.label by_l = zalloc(1)
.label by_h = zalloc(1)
.label m8 = zalloc(1)
.label m16 = zalloc(3)
.label prod = zalloc(3)
.label sgn = zalloc(1)
.label res_l = zalloc(1)
.label res_h = zalloc(1)
.label ring_pos = zalloc(1)
.label sfx_on = zalloc(1)
.label sfx_pos = zalloc(1)
.label m_tick = zalloc(1)
.label m_tmp = zalloc(1)
.label m_tmp2 = zalloc(1)
.label m_x = zalloc(1)
.label title_x = zalloc(2)
.label ax_l = zalloc(1)
.label ax_h = zalloc(1)
.label ay_l = zalloc(1)
.label ay_h = zalloc(1)
.label arrow_dir = zalloc(1)
.label perf = zalloc(1)          // main loop time of the last frame, in raster lines / 2
.label perf_max = zalloc(1)      // the worst so far (test hook; 155 = a whole frame)
.label bt_l = zalloc(1)
.label bt_h = zalloc(1)
.label bc0 = zalloc(1)
.label bc1 = zalloc(1)
.label br0 = zalloc(1)
.label br1 = zalloc(1)
.label in_game = zalloc(1)       // the IRQ runs the HUD / playfield sprite split
.label lv_msb = zalloc(1)        // sprite registers the IRQ hands to the VIC
.label lv_en = zalloc(1)
.label pstate = zalloc(1)        // state, or the one before a message
.label key_map = zalloc(1)       // SPACE was pressed: the city map
.label lives = zalloc(1)
.label wanted = zalloc(1)        // stars = police cars after the next job
.label chase = zalloc(1)
.label job_time = zalloc(1)      // BCD seconds left for this job
.label job_tick = zalloc(1)
.label job_start = zalloc(1)
.label hud_dirty = zalloc(1)     // 1 = timer, 2 = lives / stars
.label msg_t = zalloc(1)
.label msg_next = zalloc(1)
.label msg_prev = zalloc(1)
.label v1_own = zalloc(1)        // the game has taken SID voice 1 (siren)
.label v2_own = zalloc(1)        // ... voice 2 (engine)
.label ni = zalloc(1)
.label nsteps = zalloc(1)
.label nspd = zalloc(1)
.label vmask = zalloc(1)
.label ndx_l = zalloc(1)
.label ndx_h = zalloc(1)
.label ndy_l = zalloc(1)
.label ndy_h = zalloc(1)
.label nax_l = zalloc(1)
.label nax_h = zalloc(1)
.label nay_l = zalloc(1)
.label nay_h = zalloc(1)
.label tgt_xl = zalloc(1)
.label tgt_xh = zalloc(1)
.label tgt_yl = zalloc(1)
.label tgt_yh = zalloc(1)
.label car_hit = zalloc(1)
.label busted = zalloc(1)
.label reach = zalloc(1)        // how close the police must get
.label scrolled = zalloc(1)     // this frame shifted the screen
.label pending = zalloc(1)      // the first half of the next shift is done
.label pend_dx = zalloc(1)
.label pend_dy = zalloc(1)
.label last_xl = zalloc(1)
.label last_yl = zalloc(1)
.label sc_c = zalloc(1)
.label sc_r = zalloc(1)
.label n_cross = zalloc(1)      // test hooks: character crossings ...
.label n_hold = zalloc(1)       // ... and how many were not predicted
.label key_ovr = zalloc(1)
.label pcar = zalloc(6)          // car_xf..car_yh before this frame's move
.label title_t = zalloc(2)
.label page = zalloc(1)
.label bm_col = zalloc(1)
.label tx_c = zalloc(1)
.label tx_r = zalloc(1)
.label tx_i = zalloc(1)
.label pb_seen = zalloc(1)
.label bcd = zalloc(3)
.label hs_i = zalloc(1)
.label hs_pos = zalloc(1)
.label hs_cur = zalloc(1)
.label hs_rep = zalloc(1)
.label mb_x = zalloc(1)
.label mb_y = zalloc(1)
.label mb_w = zalloc(1)
.label mb_h = zalloc(1)
.label jobs = zalloc(1)          // banks robbed this game (at most 9): how tough the police are
.label ncops = zalloc(1)
.label odir = zalloc(1)
.label officer = zalloc(1)       // the police car whose officer is out ($ff: none)
.label shoot_cd = zalloc(1)
.label block_cd = zalloc(1)
.label bul_t = zalloc(1)         // a bullet in flight (frames left, 0 = none)
.label bul_xl = zalloc(1)
.label bul_xh = zalloc(1)
.label bul_yl = zalloc(1)
.label bul_yh = zalloc(1)
.label bul_dx = zalloc(1)
.label bul_dy = zalloc(1)
.label car_col = zalloc(1)       // the getaway car's paint
.label car_col_i = zalloc(1)
.label paint_t = zalloc(1)       // frames in the spray booth
.label sh_xexp = zalloc(1)       // x / y expanded shared sprites (the roadblock)
.label sh_yexp = zalloc(1)
.label lv_xexp = zalloc(1)
.label lv_yexp = zalloc(1)
.label have_car = zalloc(1)      // 0 after an arrest: the police took the car
.label is_bus = zalloc(1)        // 1: his vehicle is a hijacked city bus
.label loot = zalloc(1)          // the last job's loot, BCD hundreds
.label st_col = zalloc(1)        // a parked car: top left character, kind
.label st_row = zalloc(1)
.label st_kind = zalloc(1)       // ($ff: road, the car is gone)
.label st_scr = zalloc(1)        // put_car: also draw it on the screen
.label ts_n = zalloc(1)
.label ts_m = zalloc(1)
.label steal_pos = zalloc(1)
.label m_speed = zalloc(1)        // music: frames per 16th note now (faster in a chase)
.label vh = zalloc(1)             // npc_view: heading 0-15, curve step, old/new way
.label vk = zalloc(1)
.label va = zalloc(1)
.label vb = zalloc(1)
.label m_song = zalloc(1)         // music: 0 the tune, 1 the chase tune
.label sh_gline = zalloc(1)       // the suburb: raster line before its first row
.label lv_gline = zalloc(1)       // (0: not on screen), prepared / shown
.label ma_c = zalloc(1)           // map_at: column + 13, row + 5, the row (kept),
.label ma_r = zalloc(1)           // the grid index
.label ma_x = zalloc(1)
.label ma_g = zalloc(1)
.errorif zpNext > $100, "zero page full"
.errorif car_yh - car_xf != 5, "car_xf..car_yh must be in a row (save_car)"

// arrays in $0200-$03ff
// $0200-$02ff: the city map screen's row buffer (MMBUF, screens.asm)
.var bss = $0300
.function balloc(n) {
    .var a = bss
    .eval bss = bss + n
    .return a
}
// more working bytes at $0280-$02ff (the city map screen only uses $0200-$027f)
.var bss2 = $0280
.function b2alloc(n) {
    .var a = bss2
    .eval bss2 = bss2 + n
    .return a
}
.label m_ord = balloc(3)
.label m_steps = balloc(3)
.label m_ins = balloc(3)
.label m_pl = balloc(3)
.label m_ph = balloc(3)
.label m_note = balloc(3)
.label m_drum = balloc(3)
.label m_vib = balloc(3)
.label m_pwl = balloc(3)
.label m_pwh = balloc(3)
.label m_fl = balloc(3)
.label m_fh = balloc(3)
.label sid_sh = balloc(21)
.label sh_x = balloc(8)
.label sh_y = balloc(8)
.label sh_ptr = balloc(8)
.label tbuf = balloc(40)
.label sh_col = balloc(8)
.label lv_x = balloc(8)
.label lv_y = balloc(8)
.label lv_ptr = balloc(8)
.label lv_col = balloc(8)
.label n_type = balloc(5)         // police and cabs (chase.asm)
.label n_xl = balloc(5)
.label n_xh = balloc(5)
.label n_yl = balloc(5)
.label n_yh = balloc(5)
.label n_dir = balloc(5)
.label n_acc = balloc(5)
.label n_spd = balloc(5)
.label n_wait = balloc(5)          // cabs: frames blocked; police: frames the officer stays out
.label n_cur = balloc(5)           // speed now (speeds up to n_spd)
.label n_next = balloc(5)          // the way planned at the next crossing ($ff: none)
.label n_prev = balloc(5)          // the way before the last crossing
.label n_rot = balloc(5)           // U-turn steps still to show
.label foot_col = balloc(1)        // the guard in slot 3 (NT_FOOT): colour,
.label foot_slide = balloc(1)      // way round a wall (1 / $ff), steps (animation)
.label foot_anim = balloc(1)
.label foot_wall = balloc(1)       // steps still to follow a wall, and along which
.label foot_axis = balloc(1)       // axis (0: the wall blocks x, he slides in y)
.label hot = balloc(1)             // 1: the car is the getaway car of the last job
.label carry_l = balloc(1)         // loot not yet at the friend's house (BCD: hundreds,
.label carry_h = balloc(1)         // ten thousands)
.label level = balloc(1)           // 1, 2, ... (one more for each delivery)
.label safe_in = balloc(1)         // 1 while the car stands in the friend's driveway
.label paint_lock = balloc(1)      // 1 after a paint job until the car leaves the booth
.label arrow_mode = balloc(1)      // the arrow points to: 0 the next job, 1 the friend's house, 2 a paint garage
.label ma_v = b2alloc(1)            // map_wr: the character, column, row
.label ma_wc = b2alloc(1)
.label ma_wr = b2alloc(1)
.label priv_gi = balloc(NPRIV)     // the grid index each private block copy is for ($ff: free)
.label priv_next = balloc(1)       // the private copy to use next
.label bb_r = b2alloc(1)            // box_blocked: the row, the block column
.label bb_y = b2alloc(1)
.label ts_c = b2alloc(1)            // try_steal: the column looked at
.label mf_c = b2alloc(1)            // map_fill: column, row, index
.label mf_r = b2alloc(1)
.label mf_i = b2alloc(1)
.label dc_c = b2alloc(1)            // draw_col: column, row, rows left, y
.label dc_r = b2alloc(1)
.label dc_n = b2alloc(1)
.label dc_y = b2alloc(1)
.label dr_lo = b2alloc(1)           // draw_row: the screen row, where the block ends
.label dr_hi = b2alloc(1)
.label dr_end = b2alloc(1)
.label dc_k = b2alloc(1)
.label dance_flag = b2alloc(1)     // the score page's dancers are on
.label fly = b2alloc(1)             // thrown out of the car: frames of flight left
.label fly_n = b2alloc(1)           // (pixels left this frame on one axis)
.label fv = b2alloc(4)              // flight velocity x, y (8.8, signed)
.label fax = b2alloc(1)             // fractions of the position
.label fay = b2alloc(1)
.label greet_on = b2alloc(1)        // the greeting bubble is up (its characters borrowed)
.label oc_c = b2alloc(1)            // npc_choose / block_try: map cell, direction, slot
.label oc_r = b2alloc(1)
.label oc_d = b2alloc(1)
.label oc_x = b2alloc(1)
.label lv_cy = b2alloc(1)           // the city's colour bands: top row they are set for ($ff: redo)
.label band_w = b2alloc(1)          // (band_rows: the block row, rows left in it)
.label br_left = b2alloc(1)
.label bus_t = b2alloc(1)           // the bus: frames it still stands at its stop
.label bus_d = b2alloc(1)           // (place_npcs: the direction it is shown in)
.label rowc = b2alloc(25)           // colour RAM value of each screen row
.errorif bss2 > $0300, "the second array area is full"
.errorif bss > $0400, "arrays full"

// =====================================================================
BasicUpstart2(start)
* = $0810 "Code"

start:
    sei
    cld
    ldx #$ff
    txs
    lda #$35
    sta $01
#if REU
    jsr reu_init                    // (the REU edition: the extras into the REU)
#endif
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    lda #0
    sta $d01a
    sta $d015
    sta $d020
    sta $d021
    lda #$0b                        // screen off while setting up
    sta $d011
    lda $dd02                       // VIC bank 3 ($c000-$ffff)
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    sta $dd00

    // zero page variables
    lda #0
    ldx #zsrc
!:  sta $00,x
    inx
    cpx #zpNext
    bne !-
    lda #$a5
    sta rng

    // the tables for later (start-up data, maybe past $8000 where the map
    // goes) wait at TEMP until the packed map is free
    lda #<tail_src
    sta zsrc
    lda #>tail_src
    sta zsrc + 1
    lda #<TEMP
    sta zdst
    lda #>TEMP
    sta zdst + 1
    ldx #TAIL_PAGES
    jsr copy_pages

    // the police car's 16 directions to COPSTORE (the start-up data they
    // come from is overwritten by the map later)
    lda #<cop_rot_data
    sta zsrc
    lda #>cop_rot_data
    sta zsrc + 1
    lda #<COPSTORE
    sta zdst
    lda #>COPSTORE
    sta zdst + 1
    ldx #3
    jsr copy_pages
    lda #<mus_store_data            // and the chase tune
    sta zsrc
    lda #>mus_store_data
    sta zsrc + 1
    ldx #1
    jsr copy_pages

    // charset and car/arrow sprites go under the I/O area (packed, at the
    // end of the program: the map is unpacked over them afterwards)
    lda #$34
    sta $01
    lda #<charset_rle
    sta zsrc
    lda #>charset_rle
    sta zsrc + 1
    lda #<CHARSET
    sta zdst
    lda #>CHARSET
    sta zdst + 1
    jsr unpack
    lda #<sprhi_rle
    sta zsrc
    lda #>sprhi_rle
    sta zsrc + 1
    lda #<SPRHI
    sta zdst
    lda #>SPRHI
    sta zdst + 1
    jsr unpack
    lda #$35
    sta $01
    lda #<sprlo_rle
    sta zsrc
    lda #>sprlo_rle
    sta zsrc + 1
    lda #<SPRLO
    sta zdst
    lda #>SPRLO
    sta zdst + 1
    jsr unpack

    // the city map
    lda #<map_rle
    sta zsrc
    lda #>map_rle
    sta zsrc + 1
    lda #<BLOCKS
    sta zdst
    lda #>BLOCKS
    sta zdst + 1
    jsr unpack
    // the screen shift A->B goes where the packed map was
    lda #<shift_ab
    sta zdst
    lda #>shift_ab
    sta zdst + 1
    lda #<SCR_A
    sta t0
    lda #>SCR_A
    sta t1
    lda #<SCR_B
    sta t2
    lda #>SCR_B
    sta t3
    jsr gen_shift
    lda #<TEMP                      // and the tables after it
    sta zsrc
    lda #>TEMP
    sta zsrc + 1
    lda #<TAIL
    sta zdst
    lda #>TAIL
    sta zdst + 1
    ldx #TAIL_PAGES - 1             // (exactly: the title picture follows)
    jsr copy_pages
    ldy #0
!:  lda (zsrc),y
    sta (zdst),y
    iny
    cpy #<(tail_end - tail_start)
    bne !-


    jsr music_init
    lda #1
    sta music_on
    lda #50
    sta fps_tick

    lda #IRQ_LINE
    sta $d012
    lda #$01
    sta $d01a
    lda #$ff
    sta $d019
    cli
    jmp title

nmi:
    rti

// copy x pages from (zsrc) to (zdst)
copy_pages:
    ldy #0
!:  lda (zsrc),y
    sta (zdst),y
    iny
    bne !-
    inc zsrc + 1
    inc zdst + 1
    dex
    bne !-
    rts

// RLE depacker (format: see rlePack in gfx_lib.asm)
unpack:
    ldy #0
unp_loop:
    jsr unp_get
    cmp #$ff
    beq unp_done
    cmp #$80
    bcs unp_run
    tax
    inx
!:  jsr unp_get
    jsr unp_put
    dex
    bne !-
    beq unp_loop
unp_run:
    sec
    sbc #$7e
    tax
    jsr unp_get
!:  jsr unp_put
    dex
    bne !-
    beq unp_loop
unp_done:
    rts
unp_get:
    lda (zsrc),y
    inc zsrc
    bne !+
    inc zsrc + 1
!:  rts
unp_put:
    sta (zdst),y
    inc zdst
    bne !+
    inc zdst + 1
!:  rts

// ---------------------------------------------------------------- raster interrupt
// Once a frame in the lower border: hand the prepared frame to the VIC
// (screen buffer, fine scroll, sprites), count frames for the fps meter,
// play the music.
irq:
    pha
    txa
    pha
    tya
    pha
    cld
    lda #$ff
    sta $d019
    lda frame_ready
    bne !+
    jmp irq_noframe
!:  lda sh_d018
    sta $d018
    lda sh_d016
    sta $d016
    lda sh_d011
    sta $d011
    lda sh_gline
    sta lv_gline
    lda in_game
    bne !+
    jmp irq_taken
!:  jsr band_rows                   // scrolled a row: the colour bands follow
    // sprites 4-6 go to the VIC now; 0-3 and 7 wait for the split below
    // the HUD row (irq_split)
.for (var s = 0; s < 8; s++) {
    .if (s < 4 || s == 7) {
    lda sh_x + s
    sta lv_x + s
    lda sh_y + s
    sta lv_y + s
    lda sh_ptr + s
    sta lv_ptr + s
    }
    .if (s < 4 || s == 7) {
    lda sh_col + s
    sta lv_col + s
    }
}
    lda sh_msb
    sta lv_msb
    lda sh_en
    sta lv_en
    lda sh_xexp
    sta lv_xexp
    lda sh_yexp
    sta lv_yexp
    lda sh_col + 5
    sta $d02c
    lda sh_x + 4
    sta $d008
    lda sh_y + 4
    sta $d009
    lda sh_x + 5
    sta $d00a
    lda sh_y + 5
    sta $d00b
    lda sh_x + 6
    sta $d00c
    lda sh_y + 6
    sta $d00d
    lda sh_ptr + 4
    sta SCR_A + $3fc
    sta SCR_B + $3fc
    lda sh_ptr + 5
    sta SCR_A + $3fd
    sta SCR_B + $3fd
    lda sh_ptr + 6
    sta SCR_A + $3fe
    sta SCR_B + $3fe
    lda sh_col + 4
    sta $d02b
irq_taken:
    lda #0
    sta frame_ready
    inc shown
irq_noframe:
    lda in_game
    bne !+
    jmp irq_common
!:
    // the HUD row at the top: fps, timer, lives / stars, score
    lda #33
    sta $d000
    lda #<278
    sta $d002
    lda #<302
    sta $d004
    lda #61
    sta $d006
    lda #250
    sta $d00e
    lda #56
    sta $d001
    sta $d003
    sta $d005
    sta $d007
    sta $d00f
    lda #SP_FPS
    sta SCR_A + $3f8
    sta SCR_B + $3f8
    lda #SP_SC1
    sta SCR_A + $3f9
    sta SCR_B + $3f9
    lda #SP_SC2
    sta SCR_A + $3fa
    sta SCR_B + $3fa
    lda #SP_TIME
    sta SCR_A + $3fb
    sta SCR_B + $3fb
    lda #SP_LIVES
    sta SCR_A + $3ff
    sta SCR_B + $3ff
    lda #7
    sta $d027
    sta $d028
    sta $d029
    sta $d02a
    sta $d02e
    lda lv_msb
    and #%01110000
    ora #%00000110
    sta $d010
    lda lv_en
    and #%01110000
    ora #%10001111
    sta $d015
    lda #0                          // the HUD row is never expanded
    sta $d017
    sta $d01d
    lda #SPLIT_LINE
    sta $d012
    lda #<irq_split
    sta $fffe
    lda #>irq_split
    sta $ffff
irq_common:
    ldy #WALK_COL                   // sidewalks grey at the top of the screen
    lda lv_gline                    // (green when the suburb fills it from
    cmp #1                          // the top)
    bne !+
    ldy #LAWN_COL
!:  sty $d022
    inc vbl
    dec fps_tick
    bne !+
    lda #50                         // 50 raster frames = one PAL second
    sta fps_tick
    lda shown
    sta fps_val
    lda #0
    sta shown
!:  lda music_on
    beq !+
    jsr music_play
!:  jsr sfx_update
    pla
    tay
    pla
    tax
    pla
    rti

// Below the HUD row (line 80): sprites 0-3 and 7 become police cars, cabs
// and the arrow. Y positions first: a sprite may start at line 88.
irq_split:
    pha
    lda #$ff
    sta $d019
    lda in_game
    bne !+
    jmp is_done
!:
    lda lv_y + 0
    sta $d001
    lda lv_y + 1
    sta $d003
    lda lv_y + 2
    sta $d005
    lda lv_y + 3
    sta $d007
    lda lv_y + 7
    sta $d00f
    lda lv_x + 0
    sta $d000
    lda lv_x + 1
    sta $d002
    lda lv_x + 2
    sta $d004
    lda lv_x + 3
    sta $d006
    lda lv_x + 7
    sta $d00e
    lda lv_msb
    sta $d010
    lda lv_ptr + 0
    sta SCR_A + $3f8
    sta SCR_B + $3f8
    lda lv_ptr + 1
    sta SCR_A + $3f9
    sta SCR_B + $3f9
    lda lv_ptr + 2
    sta SCR_A + $3fa
    sta SCR_B + $3fa
    lda lv_ptr + 3
    sta SCR_A + $3fb
    sta SCR_B + $3fb
    lda lv_ptr + 7
    sta SCR_A + $3ff
    sta SCR_B + $3ff
    lda lv_col + 0
    sta $d027
    lda lv_col + 1
    sta $d028
    lda lv_col + 2
    sta $d029
    lda lv_col + 3                  // the arrow: its colour shows what it points to
    sta $d02a
    lda lv_col + 7
    sta $d02e
    lda lv_en
    sta $d015
    lda lv_xexp
    sta $d01d
    lda lv_yexp
    sta $d017
    // the suburb on screen: grass from its first row down (irq_green)
    lda lv_gline
    beq is_done
    cmp #SPLIT_LINE + 4             // (already: green right away)
    bcs !+
    lda #LAWN_COL
    sta $d022
    jmp is_done
!:  sta $d012
    lda #<irq_green
    sta $fffe
    lda #>irq_green
    sta $ffff
    pla
    rti
is_done:
    lda #IRQ_LINE
    sta $d012
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    pla
    rti

// The last raster line of the row above the suburb (no "w" pixels there):
// $d022 becomes grass green; the IRQ at line 250 sets it grey again.
irq_green:
    pha
    lda #LAWN_COL
    sta $d022
    lda #$ff
    sta $d019
    lda #IRQ_LINE
    sta $d012
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    pla
    rti

// ---------------------------------------------------------------- input
read_input:
    lda #$7f
    sta $dc00
    lda $dc00
    eor #$ff
    and #$1f
    ora joy_ovr
    sta joy
    lda joy_prev
    eor #$ff
    and joy
    sta joy_new
    lda joy
    sta joy_prev
    // keys: M = music on/off, D = raster time bar, A = what the arrow
    // points to
    lda #$ef
    sta $dc00
    lda $dc01
    eor #$ff
    and #$10
    sta t0
    lda #$fd
    sta $dc00
    lda $dc01
    eor #$ff
    and #$04
    lsr
    ora t0
    sta t0
    lda #$fb
    sta $dc00
    lda $dc01
    eor #$ff
    and #$04
    ora t0
    sta t0
    lda #$7f                        // SPACE = the city map
    sta $dc00
    lda $dc01
    eor #$ff
    and #$10
    asl
    ora t0
    ora key_ovr                     // test hook: $20 SPACE, $10 M, $04 D, $02 A
    sta t0
    lda keys_prev
    eor #$ff
    and t0
    tax
    lda t0
    sta keys_prev
    txa
    and #$20
    sta key_map
    txa
    and #$10
    beq !+
    lda music_on
    eor #1
    sta music_on
    bne !+
    jsr music_mute
!:  txa
    and #$04
    beq !+
    lda debug_bar
    eor #1
    sta debug_bar
!:  txa
    and #$02
    beq !+
    ldx arrow_mode                  // A: next job -> friend -> paint -> ...
    inx
    cpx #3
    bcc ri_mode
    ldx #0
ri_mode:
    stx arrow_mode
!:  rts

rng_next:
    lda rng
    asl
    bcc !+
    eor #$1d
!:  sta rng
    rts

// =====================================================================
// title screen
// =====================================================================
title:
    lda #0                          // the picture first
    jmp title_go
// after a game: game over / name entry, then the table first
game_over:
    ldx #$ff
    txs
    lda #0
    sta in_game
    sta frame_ready
    sta $d015
    jsr sound_off
    jsr wait_frame
    jsr hiscore_entry
    lda #1
title_go:
    sta page
    lda #0
    sta in_game
    sta $d015
    jsr show_page
    // sprites: 0-2 "PRESS FIRE" (hi-res, expanded), 3 a yellow cab driving by
    lda #SP_PRESS
    sta SCR_A + $3f8
    lda #SP_PRESS + 1
    sta SCR_A + $3f9
    lda #SP_PRESS + 2
    sta SCR_A + $3fa
    lda #SP_CAR + 4
    sta SCR_A + $3fb
    lda #1
    sta $d027
    sta $d028
    sta $d029
    sta $d026
    lda #7
    sta $d02a
    lda #0
    sta $d025
    sta $d01b
    lda #%00001000
    sta $d01c
    lda #%00000111
    sta $d017
    sta $d01d
    lda #112
    sta $d000
    lda #160
    sta $d002
    lda #208
    sta $d004
    lda #222                        // PRESS FIRE: 14 lines, clear of the credit (244)
    sta $d001
    sta $d003
    sta $d005
    lda #206
    sta $d007
    lda #0
    sta $d010
    sta title_x
    sta title_x + 1
    lda page                        // (the score page first: the dancers)
    beq title_release
    jsr dance_setup
title_release:
    jsr read_input
    lda joy
    and #$10
    bne title_release
title_loop:
    lda vbl
!:  cmp vbl
    beq !-
    lda dance_flag                  // the score page: dancers, no cab
    beq !+
    jsr dance_frame
    jmp tl_blink
    // the cab
!:  lda title_x
    clc
    adc #2
    sta title_x
    bcc !+
    inc title_x + 1
!:  lda title_x + 1
    beq !+
    lda title_x
    cmp #<370
    bcc !+
    lda #0
    sta title_x
    sta title_x + 1
!:  lda title_x
    sta $d006
    lda title_x + 1
    asl
    asl
    asl
    sta $d010
tl_blink:
    // blink "PRESS FIRE"
    lda vbl
    and #$20
    beq !+
    lda #%00000111
!:  ora #%00001000
    ldx dance_flag
    beq !+
    ora #%11111000                  // (and the dancers)
!:  sta $d015
    // picture 10 s, top bandits 5 s
    inc title_t
    bne !+
    inc title_t + 1
!:  ldx page
    lda title_t + 1
    cmp page_len,x
    bcc !+
    lda page
    eor #1
    sta page
    jsr show_page
!:  jsr read_input
    lda joy_new
    and #$10
    beq title_loop
    jmp game_start

page_len: .byte 2, 1
show_page:
    lda #0
    sta title_t
    sta title_t + 1
    lda page
    bne !+
    jsr dance_off
    jmp show_picture
!:  jsr show_scores
    jmp dance_setup

// ---------------------------------------------------------------- the dancers
// On the score page five dancers (sprites 3-7, x- and y-expanded) dance in a
// line under the table: the bandit, the guard, the officer, the shop owner
// and a cab driver, a move every 16 frames (arms up, point right, hands on
// hips, point left), neighbours mirrored, bouncing on the beat.
dance_x:    .byte 60, 116, 172, 228, <284
dance_col:  .byte 8, 5, 6, 4, 7
dance_seq:  .byte 0, 1, 2, 3
.const DANCE_Y = 188              // (hands below the table, feet above PRESS FIRE)
dance_setup:
    lda #232                        // PRESS FIRE a little lower
    sta $d001
    sta $d003
    sta $d005
    lda #<DANCE_SRC
    sta zsrc
    lda #>DANCE_SRC
    sta zsrc + 1
    lda #<DANCE_SPR
    sta zdst
    lda #>DANCE_SPR
    sta zdst + 1
    ldx #1
    jsr copy_pages
    ldx #4
!:  txa
    asl
    tay
    lda dance_x,x
    sta $d006,y
    lda #DANCE_Y
    sta $d007,y
    lda dance_col,x
    sta $d02a,x
    dex
    bpl !-
    lda #%10000000                  // the last one is right of x = 255
    sta $d010
    lda #11                         // hair and trousers dark grey (black
    sta $d025                       // does not show on the black page)
    lda #%11111000
    sta $d01c
    ora #%00000111
    sta $d017
    sta $d01d
    lda #1
    sta dance_flag
    jmp dance_frame
// back to the cab (the picture page)
dance_off:
    lda #222                        // PRESS FIRE where it was
    sta $d001
    sta $d003
    sta $d005
    lda #0
    sta dance_flag
    sta $d010
    lda #%00001000
    sta $d01c
    lda #%00000111
    sta $d017
    sta $d01d
    lda #SP_CAR + 4
    sta SCR_A + $3fb
    lda #7
    sta $d02a
    lda #206
    sta $d007
    rts
dance_frame:
    lda vbl                         // the move: every 16 frames
    lsr
    lsr
    lsr
    lsr
    sta t0
    ldx #4
!:  txa                             // neighbours mirrored (2 moves apart)
    and #1
    asl
    clc
    adc t0
    and #3
    tay
    lda dance_seq,y
    clc
    adc #DANCE_SPR / 64 & 255
    sta SCR_A + $3fb,x
    dex
    bpl !-
    lda vbl                         // a bounce on every move
    and #15
    cmp #4
    lda #DANCE_Y
    bcs !+
    sbc #2
!:  ldx #8
!:  sta $d007,x
    dex
    dex
    bpl !-
    rts

// =====================================================================
// game
// =====================================================================
game_start:
    lda #0
    sta $d015
    lda #$0b
    sta $d011
    jsr gen_shift_ba
    lda #0
    sta $d017
    sta $d01d
    sta $d01b
    sta $d025
    lda #$ff
    sta $d01c
    lda #1
    sta $d026
    lda #2                          // the getaway car: red, the marker green
    sta $d02c
    lda #5
    sta $d02d
    jsr city_colours

    lda #0                          // not flying from a crash
    sta greet_on
    sta fly
    lda #<START_X
    sta car_xl
    lda #>START_X
    sta car_xh
    lda #<START_Y
    sta car_yl
    lda #>START_Y
    sta car_yh
    lda #0
    sta car_xf
    sta car_yf
    sta hdg
    sta hdg_f
    sta mang
    sta spd_l
    sta spd_h
    sta vx_l
    sta vx_h
    sta vy_l
    sta vy_h
    sta burn
    sta state
    sta score
    sta score + 1
    sta score + 2
    sta target
    sta bub_on
    sta bag
    sta hot
    sta carry_l
    sta carry_h
    sta safe_in
    sta paint_lock
    sta arrow_mode
    sta ring_pos
    sta frame_ready
    sta wanted
    sta pending
    sta chase
    sta v1_own
    sta v2_own
    sta jobs
    sta bul_t
    sta shoot_cd
    sta block_cd
    sta paint_t
    sta car_col_i
    sta steal_pos
    sta st_scr                      // the cars stolen last game are back
    lda #1                          // level 1
    sta level
    lda #0
    jsr grid_reset                  // the city as built: stolen cars are back
    lda #1
    sta have_car
    sta st_scr
    lsr                             // (0) his own car, not a bus
    sta is_bus
    lda vbl                         // the first bank: from how long the
    eor rng                         // title was shown
    and #NBANKS - 1
    sta target
    lda #0
    ldx #NNPC - 1
!:  sta n_type,x
    sta n_cur,x
    dex
    bpl !-
    lda #$ff
    sta officer
    lda #2
    sta car_col                     // red
    lda #3
    sta lives
    sta hud_dirty
    lda #JOB_TIME
    sta job_start
    sta job_time
    lda #50
    sta job_tick
    lda #1
    sta score_dirty
    lda #$ff
    sta fps_shown

    // the arrow stays in the lower left corner; colours of the shared sprites
    lda #33
    sta sh_x + 3
    lda #224
    sta sh_y + 3
    lda #7
    ldx #7
!:  sta sh_col,x
    dex
    bpl !-
    lda #8
    sta sh_col + 4

    // two cabs in town
    jsr set_target
    ldx #3
    jsr spawn_cab
    ldx #4
    jsr spawn_cab

    // camera straight onto the car, draw the first screen into buffer A
    jsr camera_target
    lda t0
    sta cam_xl
    lda t1
    sta cam_xh
    lda t2
    sta cam_yl
    lda t3
    sta cam_yh
    lda #0
    sta cam_xf
    sta cam_yf
    jsr clamp_camera
    jsr cam_chars
    lda #$c0
    sta back_hi
    sta front_hi
    lda #0
    sta front
    jsr full_redraw
    lda ncx
    sta disp_cx
    lda ncy
    sta disp_cy
    lda #D018_A
    sta sh_d018
    jsr scroll_regs
    jsr place_sprites
    jsr hud_update
    lda #1
    sta in_game
    sta frame_ready

game_loop:
    lda frame_ready                 // wait until the raster IRQ took the last frame
    bne game_loop
    lda #0
    sta scrolled
    lda debug_bar
    beq !+
    lda #2
    sta $d020
!:  jsr read_input
    lda state
    cmp #ST_ROB
    bcs !+
    lda key_map                     // SPACE: the city map (driving or walking)
    beq !+
    jsr show_map
!:  lda state
    cmp #ST_DRIVE
    bne !+
    jsr save_car
    jsr do_drive
    jsr paint_check
gl_safe:
    jsr safe_check                  // (driving or walking)
    lda state                       // a message at the friend's house: the
    cmp #ST_MSG                     // picture stands still under the bubble
    bne gl_world
    jmp gl_sprites
!:  cmp #ST_WALK
    bne !+
    jsr do_walk
    jmp gl_safe
!:  cmp #ST_ROB
    bne !+
    jsr do_rob
    jmp gl_sprites
!:  jsr do_msg
    jmp gl_sprites
gl_world:
    lda state                       // police, cabs and the clock
    cmp #ST_ROB
    bcs gl_camera
    jsr npc_frame
    lda state
    cmp #ST_ROB
    bcs !+
    jsr job_frame
!:  lda state
    cmp #ST_MSG
    beq gl_sprites
gl_camera:
    jsr update_camera
    jsr scroll_prepare
gl_sprites:
    jsr place_sprites
    jsr hud_update
    jsr sound_frame
    jsr perf_sample
    lda debug_bar
    beq !+
    lda #0
    sta $d020
!:  lda #1
    sta frame_ready
    jmp game_loop

// the B->A screen shift lives at $e000 (where the title picture was), the
// police car's 16 directions at $f800 after it
gen_shift_ba:
    lda #<COPSTORE
    sta zsrc
    lda #>COPSTORE
    sta zsrc + 1
    lda #<COPSPR
    sta zdst
    lda #>COPSPR
    sta zdst + 1
    ldx #3
    jsr copy_pages
    lda #<guard_rle                 // and the guard and the bus after them (packed)
    sta zsrc
    lda #>guard_rle
    sta zsrc + 1
    lda #<GUARDSPR
    sta zdst
    lda #>GUARDSPR
    sta zdst + 1
    jsr unpack
    lda #<shift_ba
    sta zdst
    lda #>shift_ba
    sta zdst + 1
    lda #<SCR_B
    sta t0
    lda #>SCR_B
    sta t1
    lda #<SCR_A
    sta t2
    lda #>SCR_A
    sta t3
    jmp gen_shift

// the comic bubble words (their glyphs are in the city area: WORD_GLYPHS)
word_start: .fill wordStart.size(), wordStart.get(i)
word_len:   .fill wordLen.size(), wordLen.get(i)
// grid row offsets (the city grid as built is GRID_ORIG, after the bands);
// a row of wall for the edges of the world (both in one
// page: map_at's callers check the page)
gmul:       .fill GH, i * GW
// small tables in what would be padding before the wall rows
d018_tab:   .byte D018_A, D018_B
bit_tab:    .byte 1, 2, 4, 8, 16, 32, 64, 128
bounce_tab: .byte 20, 18, 17, 16, 16, 17, 18, 20
band_tab:   .fill bandCols.size(), $08 | bandCols.get(i)   // colour RAM per block row
oc_dr:      .byte 256 - 5, 0, 5, 0  // npc_choose: where to look from a crossing (N E S W)
oc_dc:      .byte 0, 8, 0, 256 - 8
// column a, row x: not zero if the character there blocks a car
blk_at:
    jsr map_at
    lda (zp0),y
    tay
    lda class_tab,y
    and #1
    rts
// t0/t1 = |speed|
abs_speed:
    lda spd_l
    sta t0
    lda spd_h
    sta t1
    bpl !+
    lda #0
    sec
    sbc t0
    sta t0
    lda #0
    sbc t1
    sta t1
!:  rts
// msg_next = 1 if that was the last life (chase.asm)
last_life:
    ldx #0
    lda lives
    bne !+
    inx
!:  stx msg_next
    rts
.align 64
wall_row:   .fill 32, WALLCH
wall_sub:   .fill 32, WALL_SUB
.errorif floor(wall_row / 256) != floor((wall_sub + 31) / 256), "the wall rows must share a page"
.errorif guardSpr.size() != 768, "the guard (8 sprites) and the bus (4)"

// the city palette. The "y" pixels (windows, cabs, signs) take their colour
// from colour RAM, set per screen row from the block row shown there
// (band_tab): the IRQ redoes the rows that changed when a new picture with
// another top row is shown (band_rows).
city_colours:
    lda #0
    sta $d020
    lda #ROAD_COL
    sta $d021
    lda #WALK_COL
    sta $d022
    lda #ROOF_COL
    sta $d023
    ldx #0
    lda #COLRAM
!:  sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne !-
    ldx #24
!:  sta rowc,x
    dex
    bpl !-
    lda #$ff                        // the next picture sets the bands
    sta lv_cy
    rts

// colour RAM rows 0-24 for top world row lv_cy (in the IRQ: only the rows
// whose band changed, one or two per row scrolled). World row w is in block
// row (w + 5) / 16.
band_rows:
    lda disp_cy                     // (the top row of the picture shown now)
    cmp lv_cy
    beq br_done
    sta lv_cy
    clc
    adc #5
    tay
    and #15                         // rows of this band after the top one
    eor #15
    sta br_left
    tya
    ror                             // the block row (9 bits: rows 251-255 are 16)
    lsr
    lsr
    lsr
    sta band_w
    ldx #0
br_band:
    ldy band_w
    lda band_tab,y
br_loop:
    cmp rowc,x
    beq br_next
    sta rowc,x
    ldy srow_lo,x
    sty br_st + 1
    pha
    lda srow_hi,x
    ora #$d8
    sta br_st + 2
    pla
    ldy #39
br_st:
    sta $d800,y
    dey
    bpl br_st
br_next:
    inx
    cpx #25
    beq br_done
    dec br_left
    bpl br_loop
    lda #15
    sta br_left
    inc band_w
    bne br_band
br_done:
    rts

// how long the main loop took this frame (raster lines since the IRQ, halved)
perf_sample:
    lda $d011
    bpl !+
    lda $d012
    clc
    adc #6
    lsr
    jmp ps_store
!:  lda $d012
    cmp #IRQ_LINE
    bcc !+
    sbc #IRQ_LINE
    lsr
    jmp ps_store
!:  lsr
    clc
    adc #31
ps_store:
    sta perf
    cmp perf_max
    bcc !+
    sta perf_max
!:  rts

// =====================================================================
// driving
// =====================================================================
do_drive:
    lda #0
    sta skid
    // fire: get out (only when nearly stopped)
    lda joy_new
    and #$10
    beq dd_steer
    jsr abs_speed
    lda t1
    bne dd_steer
    lda t0
    cmp #$60
    bcs dd_steer
    jsr try_exit
    bcc dd_steer
    rts
dd_steer:
    // turn rate = 1.5 x |speed|, at most 2.5 units a frame (256 = a circle)
    jsr abs_speed
    lda t1
    lsr
    sta t2
    lda t0
    ror
    clc
    adc t0
    sta t0
    lda t2
    adc t1
    sta t1
    cmp #2
    bcc !+
    bne dd_cap
    lda t0
    cmp #$80
    bcc !+
dd_cap:
    lda #2
    sta t1
    lda #$80
    sta t0
!:  lda spd_h                       // steering is reversed when backing up
    bpl !+
    lda joy
    and #$0c
    cmp #$04
    beq dd_right
    cmp #$08
    beq dd_left
    jmp dd_throttle
!:  lda joy
    and #$0c
    cmp #$04
    beq dd_left
    cmp #$08
    beq dd_right
    jmp dd_throttle
dd_left:
    lda hdg_f
    sec
    sbc t0
    sta hdg_f
    lda hdg
    sbc t1
    sta hdg
    jmp dd_throttle
dd_right:
    lda hdg_f
    clc
    adc t0
    sta hdg_f
    lda hdg
    adc t1
    sta hdg

dd_throttle:
    lda joy
    and #$01
    beq dd_noup
    // burnout: flooring it from (nearly) standstill
    lda joy_new
    and #$01
    beq !+
    lda spd_h
    bne !+
    lda spd_l
    cmp #$80
    bcs !+
    lda #45
    sta burn
!:  lda spd_h
    bpl dd_acc
    lda spd_l                       // backing up: brake
    clc
    adc #BRAKE
    sta spd_l
    lda spd_h
    adc #0
    sta spd_h
    jmp dd_drift
dd_acc:
    lda spd_l
    clc
    adc #ACCEL
    sta spd_l
    lda spd_h
    adc #0
    sta spd_h
    ldy is_bus                      // (a bus does 2 pixels a frame)
    cmp max_spd,y
    bcs !+
    jmp dd_drift
!:
    lda max_spd,y
    sta spd_h
    lda #<MAXSPD
    sta spd_l
    jmp dd_drift
max_spd:    .byte >MAXSPD, >BUS_MAX
dd_noup:
    lda #0
    sta burn
    lda joy
    and #$02
    beq dd_coast
    lda spd_h
    bmi dd_rev
    lda spd_l
    ora spd_h
    beq dd_rev
    lda spd_l                       // moving forward: brake
    sec
    sbc #BRAKE
    sta spd_l
    lda spd_h
    sbc #0
    sta spd_h
    bmi !+
    jmp dd_drift
!:
    lda #0
    sta spd_l
    sta spd_h
    jmp dd_drift
dd_rev:
    lda spd_l
    sec
    sbc #ACCEL / 2
    sta spd_l
    lda spd_h
    sbc #0
    sta spd_h
    cmp #>($10000 - REVMAX)
    bcc !+
    jmp dd_drift
!:
    lda #>($10000 - REVMAX)
    sta spd_h
    lda #<($10000 - REVMAX)
    sta spd_l
    jmp dd_drift
dd_coast:
    lda spd_h
    bmi dd_coastneg
    ora spd_l
    bne !+
    jmp dd_drift
!:
    lda spd_l
    sec
    sbc #DRAG
    sta spd_l
    lda spd_h
    sbc #0
    sta spd_h
    bmi !+
    jmp dd_drift
!:
    lda #0
    sta spd_l
    sta spd_h
    bne !+
    jmp dd_drift
!:
dd_coastneg:
    lda spd_l
    clc
    adc #DRAG
    sta spd_l
    lda spd_h
    adc #0
    sta spd_h
    bpl !+
    jmp dd_drift
!:
    lda #0
    sta spd_l
    sta spd_h

dd_drift:
    lda burn
    beq !+
    dec burn
    lda #1
    sta skid
    // the direction of travel follows the nose with limited grip
!:  jsr abs_speed
    ldx #10
    lda t1
    cmp #2
    bcc !+
    ldx #3
!:  stx t2                          // grip
    lda hdg
    sec
    sbc mang
    sta t3                          // signed difference
    bpl !+
    eor #$ff
    clc
    adc #1
!:  sta t4                          // |difference|
    cmp t2
    bcc dd_snap
    beq dd_snap
    lda t3
    bmi !+
    lda mang
    clc
    adc t2
    sta mang
    jmp dd_slide
!:  lda mang
    sec
    sbc t2
    sta mang
    jmp dd_slide
dd_snap:
    lda hdg
    sta mang
dd_slide:
    lda t4                          // sliding sideways at speed: rubber!
    cmp #14
    bcc dd_vel
    lda t1
    beq dd_vel
    lda #1
    sta skid
    lda spd_h                       // scrub off a little speed
    bmi dd_vel
    lda spd_l
    sec
    sbc #4
    sta spd_l
    lda spd_h
    sbc #0
    sta spd_h

dd_vel:
    ldx mang
    lda sin_tab,x
    jsr mul_speed
    lda res_l
    sta vx_l
    lda res_h
    sta vx_h
    ldx mang
    lda sin_tab + 64,x
    jsr mul_speed
    lda #0
    sec
    sbc res_l
    sta vy_l
    lda #0
    sbc res_h
    sta vy_h

    // move x, then y, each only if the car's box stays free
    lda #0
    sta bump
    lda #6
    sta bhw
    lda #1
    sta bmask
    lda car_xf
    clc
    adc vx_l
    sta t0
    lda vx_h
    and #$80
    beq !+
    lda #$ff
!:  sta t2
    lda car_xl
    adc vx_h
    sta bx_l
    lda car_xh
    adc t2
    sta bx_h
    lda car_yl
    sta by_l
    lda car_yh
    sta by_h
    jsr box_blocked
    bne !+
    lda t0
    sta car_xf
    lda bx_l
    sta car_xl
    lda bx_h
    sta car_xh
    jmp dd_movey
!:  lda #1                          // x blocked
    sta bump
dd_movey:
    lda car_yf
    clc
    adc vy_l
    sta t0
    lda vy_h
    and #$80
    beq !+
    lda #$ff
!:  sta t2
    lda car_yl
    adc vy_h
    sta by_l
    lda car_yh
    adc t2
    sta by_h
    lda car_xl
    sta bx_l
    lda car_xh
    sta bx_h
    jsr box_blocked
    bne !+
    lda t0
    sta car_yf
    lda by_l
    sta car_yl
    lda by_h
    sta car_yh
    jmp dd_bumped
!:  lda bump                        // y blocked
    ora #2
    sta bump
dd_bumped:
    lda bump
    bne !+
    jmp dd_frame
    // only one way blocked and it is not the way the car mainly goes: it
    // scrapes along the wall (a little slower) instead of bouncing off
!:  cmp #3
    beq dd_bounce
    jsr abs_vel                     // t0/t1 = |vx|, t2/t3 = |vy|
    lda t0
    cmp t2
    lda t1
    sbc t3                          // carry set: |vx| >= |vy|
    lda #0
    rol                             // 1: mainly sideways
    eor bump                        // x blocked (1) and mainly sideways (1),
    and #1                          // or y blocked (2) and mainly up/down (0)
    beq dd_bounce                   // = 0: head on
    lda spd_h                       // speed - speed / 32
    cmp #$80
    ror
    sta t1
    lda spd_l
    ror
    sta t0
    ldx #4
!:  lda t1
    cmp #$80
    ror t1
    ror t0
    dex
    bne !-
    lda spd_l
    sec
    sbc t0
    sta spd_l
    lda spd_h
    sbc t1
    sta spd_h
    jmp dd_frame
dd_bounce:
    jsr abs_speed                   // into a parked car this fast: Vinnie
    lda t1                          // goes through the windscreen
    cmp #>THROW_SPEED
    bcc dd_soft
    lda vx_h                        // (the character 4 frames ahead)
    asl
    asl
    sta t2
    clc
    adc car_xl
    sta px_l
    lda t2
    and #$80
    beq !+
    lda #$ff
!:  adc car_xh
    sta px_h
    lda vy_h
    asl
    asl
    sta t2
    clc
    adc car_yl
    sta py_l
    lda t2
    and #$80
    beq !+
    lda #$ff
!:  adc car_yh
    sta py_h
    jsr map_addr
    bcs dd_soft
    lda (zp0),y
    jsr park_find
    beq dd_soft
    jmp throw_out
dd_soft:
    jsr abs_speed                   // bounce back a little
    lda t1
    beq !+
    lda #SFX_CRASH
    jsr sfx_play
!:  lda spd_h
    cmp #$80
    ror spd_h
    ror spd_l
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
dd_frame:
    lda hdg
    clc
    adc #8
    lsr
    lsr
    lsr
    lsr
    sta car_frame
    jmp do_skids

// t0/t1 = |vx|, t2/t3 = |vy| (the car's velocity this frame)
abs_vel:
    lda vx_l
    sta t0
    lda vx_h
    sta t1
    bpl !+
    lda #0
    sec
    sbc t0
    sta t0
    lda #0
    sbc t1
    sta t1
!:  lda vy_l
    sta t2
    lda vy_h
    sta t3
    bpl !+
    lda #0
    sec
    sbc t2
    sta t2
    lda #0
    sbc t3
    sta t3
!:  rts

// res = speed * a / 128 (a = signed sine), signed 8.8 result.
// |speed| / 4 times |sine| with quarter-square tables, then / 32.
mul_speed:
    sta m8
    lda #0
    sta sgn
    lda m8
    bpl !+
    eor #$ff
    clc
    adc #1
    sta m8
    inc sgn
!:  lda spd_h
    bpl !+
    lda sgn
    eor #1
    sta sgn
!:  jsr abs_speed
    lda t0
    lsr
    lsr
    sta t2
    lda t1
    lsr
    ror
    ror
    and #$c0
    ora t2
    // a * m8 (shift and add): high byte in a, low in res_l
    sta res_l
    lda #0
    ldx #8
    lsr res_l
!:  bcc ms_add
    clc
    adc m8
ms_add:
    ror
    ror res_l
    dex
    bne !-
    ldx #5
!:  lsr
    ror res_l
    dex
    bne !-
    sta res_h
    lda sgn
    beq !+
    lda #0
    sec
    sbc res_l
    sta res_l
    lda #0
    sbc res_h
    sta res_h
!:  rts

// ---------------------------------------------------------------- the map
// The city is a grid of blocks (gfx_city.asm): world column c, row r is
// character (c + 13) & 31, (r + 5) & 15 of block GRID[((r + 5) >> 4) * GW +
// ((c + 13) >> 5)]; GRID holds the page of each block (BLOCKS + 512 x
// design, or a private copy at PRIV). The two characters at each edge of
// the world are wall.
//
// map_at: column a, row x -> (zp0),y is the map character (x is kept).
// Going on to y + 1 is the next column up to the block's edge (y = 31).
map_at:
    tay
    cpx #2
    bcc ma_wall
    cpx #254
    bcs ma_wall
    lda MT_CB,y                     // block column ($ff: the wall)
    bmi ma_wall
    clc
    adc MT_RG,x                     // + grid row
    sta ma_g
    lda MT_CY,y                     // the column in the block
    sta ma_c
    ldy ma_g
    lda GRID,y
    clc
    adc MT_RH,x
    sta zp0 + 1
    lda MT_RL,x
    sta zp0
    ldy ma_c
    rts
ma_wall:                            // a row of wall (green-free in the suburb)
    tya                             // (y = the column)
    pha
    ldy #<wall_row
    cpx #SUB_ROW
    bcc !+
    ldy #<wall_sub
!:  sty zp0
    lda #>wall_row
    sta zp0 + 1
    pla
    cmp #2                          // left edge: to column 2
    bcs !+
    adc #30
    tay
    rts
!:  cmp #254                        // right edge: to the end
    bcc !+
    and #31
    tay
    rts
!:  clc                             // top / bottom: block by block
    adc #-BLK_X0
    and #31
    tay
    rts

// map_addr: px/py (16-bit world pixels) -> mcol, mrow and (zp0),y = the
// map character. Carry set if outside the world.
map_addr:
    lda px_h
    cmp #8
    bcs !+
    lda py_h
    cmp #8
    bcs !+
    lda px_l
    sta mcol
    lda px_h
    lsr
    ror mcol
    lsr
    ror mcol
    lsr
    ror mcol
    lda py_l
    sta mrow
    lda py_h
    lsr
    ror mrow
    lsr
    ror mrow
    lsr
    ror mrow
    ldx mrow
    lda mcol
    jsr map_at
    clc
!:  rts

// map_wr: character ma_v at column a, row x into the map. The block designs
// are shared, so the block gets a private copy first (one of NPRIV, the
// oldest goes back to its design).
map_wr:
    sta ma_wc
    stx ma_wr
    jsr map_at
    lda zp0 + 1
    cmp #>PRIV
    bcs mw_put                      // already a private copy
    ldx priv_next
    lda priv_gi,x                   // that copy is taken: its block is the
    bmi !+                          // shared design again
    tay
    lda GRID_ORIG,y
    sta GRID,y
!:  ldy ma_g
    tya
    sta priv_gi,x
    lda GRID,y                      // copy the design (512 bytes)
    sta zsrc + 1
    txa
    asl
    clc
    adc #>PRIV
    sta zdst + 1
    sta GRID,y
    lda #0
    sta zsrc
    sta zdst
    ldx #2
    jsr copy_pages
    lda priv_next
    clc
    adc #1
    and #NPRIV - 1
    sta priv_next
    ldx ma_wr
    lda ma_wc
    jsr map_at
mw_put:
    lda ma_v
    sta (zp0),y
    rts

// the city as built (a new game): the grid back from GRID_ORIG, no
// private copies
grid_reset:
    ldx #GW * GH
!:  lda GRID_ORIG - 1,x
    sta GRID - 1,x
    dex
    bne !-
    lda #$ff
    ldx #NPRIV - 1
!:  sta priv_gi,x
    dex
    bpl !-
    lda #0
    sta priv_next
    rts
// box_blocked: box of half size bhw (at most 7) around (bx, by) against the
// class bits bmask. Returns A != 0 (Z clear) if blocked.
box_blocked:
    lda bx_l
    sec
    sbc bhw
    sta bt_l
    lda bx_h
    sbc #0
    jsr to_cell
    bcs bb_hit
    sta bc0
    lda bx_l
    clc
    adc bhw
    sta bt_l
    lda bx_h
    adc #0
    jsr to_cell
    bcs bb_hit
    sta bc1
    lda by_l
    sec
    sbc bhw
    sta bt_l
    lda by_h
    sbc #0
    jsr to_cell
    bcs bb_hit
    sta br0
    lda by_l
    clc
    adc bhw
    sta bt_l
    lda by_h
    adc #0
    jsr to_cell
    bcs bb_hit
    sta br1
    ldx br0
    jsr bb_row
    bne bb_hit
    ldx br1
    jsr bb_row
    bne bb_hit
    lda #0
    rts
bb_hit:
    lda #1
    rts
bb_row:                             // x = row: is column bc0 or bc1 blocked?
    stx bb_r
    lda bc0
    jsr map_at
    sty bb_y
    lda (zp0),y
    tax
    lda class_tab,x
    and bmask
    bne bb_ret
    lda bc1                         // bc1 in the same block: no new lookup
    sec
    sbc bc0
    clc
    adc bb_y
    cmp #32
    bcs !+
    tay
    lda (zp0),y
    jmp bb_cls
!:  ldx bb_r
    lda bc1
    jsr map_at
    lda (zp0),y
bb_cls:
    tax
    lda class_tab,x
    and bmask
bb_ret:
    rts
// a = high, bt_l = low byte of a world coordinate -> a = map cell, carry set if outside
to_cell:
    cmp #8
    bcs !+
    sta bt_h
    lda bt_l
    lsr bt_h
    ror
    lsr bt_h
    ror
    lsr bt_h
    ror
    clc
!:  rts

// put character a on the shown screen if map cell (mcol, mrow) is visible
// (and into the hidden one too when its first half is shifted already)
screen_cell:
    sta t4
    lda mcol
    sec
    sbc disp_cx
    sta sc_c
    lda mrow
    sec
    sbc disp_cy
    sta sc_r
    lda front_hi
    jsr sc_put
    lda pending
    beq sce_done
    lda sc_c
    sec
    sbc pend_dx
    sta sc_c
    lda sc_r
    sec
    sbc pend_dy
    sta sc_r
    lda front_hi
    eor #$04
sc_put:
    ldy sc_c
    cpy #40
    bcs sce_done
    ldx sc_r
    cpx #25
    bcs sce_done
    ora srow_hi,x
    sta zp1 + 1
    lda srow_lo,x
    sta zp1
    lda t4
    sta (zp1),y
sce_done:
    rts

// ---------------------------------------------------------------- skid marks
do_skids:
    lda skid
    bne !+
    rts
!:  ldx car_frame
    lda wheel_lx,x
    ldy wheel_ly,x
    jsr mark_wheel
    ldx car_frame
    lda wheel_rx,x
    ldy wheel_ry,x
mark_wheel:                         // a/y = signed offset from the car centre
    sty t2
    tax
    clc
    adc car_xl
    sta px_l
    txa
    and #$80
    beq !+
    lda #$ff
!:  adc car_xh
    sta px_h
    lda t2
    clc
    adc car_yl
    sta py_l
    lda t2
    and #$80
    beq !+
    lda #$ff
!:  adc car_yh
    sta py_h
    jsr map_addr
    bcs mw_done
    lda (zp0),y
    cmp #ROADCH                     // marks only on plain asphalt (on the
    bne mw_done                     // screen only: the blocks are shared,
    ldx car_frame                   // they go when they scroll away)
    lda skid_tab,x
    jsr screen_cell
mw_done:
    rts
// ---------------------------------------------------------------- on foot
try_exit:                           // carry set if the bandit got out
    ldx car_frame
    lda exit_dx,x
    ldy exit_dy,x
    jsr place_man
    bcs !+
    ldx car_frame
    lda #0
    sec
    sbc exit_dx,x
    pha
    lda #0
    sec
    sbc exit_dy,x
    tay
    pla
    jsr place_man
    bcs !+
    clc
    rts
!:  lda #0
    sta spd_l
    sta spd_h
    sta burn
    sta man_anim
    lda #2
    sta man_dir
    lda #ST_WALK
    sta state
    lda #SFX_DOOR
    jsr sfx_play
    sec
    rts

place_man:                          // a/y = offset from the car; carry set if free
    sty t2
    tax
    clc
    adc car_xl
    sta bx_l
    txa
    and #$80
    beq !+
    lda #$ff
!:  adc car_xh
    sta bx_h
    lda t2
    clc
    adc car_yl
    sta by_l
    lda t2
    and #$80
    beq !+
    lda #$ff
!:  adc car_yh
    sta by_h
    lda #3
    sta bhw
    lda #2
    sta bmask
    jsr box_blocked
    beq !+
    clc
    rts
!:  lda bx_l
    sta man_xl
    lda bx_h
    sta man_xh
    lda by_l
    sta man_yl
    lda by_h
    sta man_yh
    sec
    rts

do_walk:
    lda fly                         // still flying from a crash
    beq !+
    jmp fly_step
!:
    lda joy_new
    and #$10
    beq dw_move
    // fire next to the car: get in
    lda have_car
    beq dw_steal
    lda man_xl
    sec
    sbc car_xl
    sta t0
    lda man_xh
    sbc car_xh
    jsr near18
    bcc dw_steal
    lda man_yl
    sec
    sbc car_yl
    sta t0
    lda man_yh
    sbc car_yh
    jsr near18
    bcc dw_steal
    lda #ST_DRIVE
    sta state
    lda #SFX_DOOR
    jsr sfx_play
    rts
dw_steal:
    jsr try_bus                     // next to a bus at its stop: take it
    bcs dw_took
    jsr try_steal                   // or next to a parked car: steal it
    bcc dw_move
dw_took:
    rts
dw_move:
    lda #3
    sta bhw
    lda #2
    sta bmask
    lda #0
    sta t3                          // moved?
    lda joy
    and #$08
    beq !+
    lda #1
    sta man_dir
    lda #1
    jsr man_try_x
!:  lda joy
    and #$04
    beq !+
    lda #3
    sta man_dir
    lda #$ff
    jsr man_try_x
!:  lda joy
    and #$02
    beq !+
    lda #2
    sta man_dir
    lda #1
    jsr man_try_y
!:  lda joy
    and #$01
    beq !+
    lda #0
    sta man_dir
    lda #$ff
    jsr man_try_y
!:  lda t3
    beq !+
    inc man_anim
    lda man_anim                    // footsteps: one per step of the animation
    and #7
    bne !+
    lda sfx_on                      // (not over another effect)
    bne !+
    lda #SFX_STEP
    jsr sfx_play
    // at the bank door?
!:  ldx target
    lda man_xl
    sec
    sbc door_xl,x
    sta t0
    lda man_xh
    sbc door_xh,x
    sta t1
    lda t0
    clc
    adc #10
    sta t0
    lda t1
    adc #0
    bne dw_done
    lda t0
    cmp #20
    bcs dw_done
    lda man_yl
    sec
    sbc door_yl,x
    sta t0
    lda man_yh
    sbc door_yh,x
    sta t1
    lda t0
    clc
    adc #5
    sta t0
    lda t1
    adc #0
    bne dw_done
    lda t0
    cmp #11
    bcs dw_done
    jmp start_rob
dw_done:
    rts


// character a a part of a parked car? a = $80 + kind * 8 + row * 2 + column
// (its index in park_chars: kind * 6 + row * 2 + column), else 0
park_find:
    ldx #5 * 6 - 1
!:  cmp park_chars,x
    beq !+
    dex
    bpl !-
    lda #0
    rts
!:  ldy #$80 - 8                    // kind * 8 + $80 in y, the rest in a
    txa
    sec
!:  iny
    iny
    iny
    iny
    iny
    iny
    iny
    iny
    sbc #6
    bcs !-
    adc #6
    sty t2
    ora t2
    rts
// ---------------------------------------------------------------- car theft
// fire on foot with a parked car in the 3 x 3 characters around the bandit:
// he steals it (his own car, if any, is left for good). Carry set if he did.
try_steal:
    lda man_xl
    sta t3
    lda man_xh
    lsr
    ror t3
    lsr
    ror t3
    lsr
    ror t3
    dec t3                          // t3 = first column
    lda man_yl
    sta st_row
    lda man_yh
    lsr
    ror st_row
    lsr
    ror st_row
    lsr
    ror st_row
    dec st_row
    lda #3
    sta ts_n
ts_row:
    lda t3
    sta ts_c
    lda #3
    sta ts_m
ts_col:
    ldx st_row
    lda ts_c
    jsr map_at
    lda (zp0),y
    jsr park_find
    bne ts_found
    inc ts_c
    dec ts_m
    bne ts_col
    inc st_row
    dec ts_n
    bne ts_row
    clc
    rts
ts_found:                           // a = $80 + kind * 8 + row * 2 + column
    sta t1
    and #1
    sta t2
    lda ts_c
    sec
    sbc t2
    sta st_col
    lda t1
    lsr
    and #3
    sta t2
    lda st_row
    sec
    sbc t2
    sta st_row
    lda t1
    lsr
    lsr
    lsr
    and #7
    sta st_kind
    // it comes off the street (in a private copy of its block: it is back
    // next game, or when that copy is needed for another block)
    lda st_kind
    pha
    lda #$ff
    sta st_kind
    jsr put_car
    pla
    tax
    lda kind_col,x
    bpl !+                          // ($ff) a cab: the colour of its screen row
    lda st_row
    sec
    sbc disp_cy
    tax
    lda rowc,x
    and #7
!:  sta car_col
    // the car stands where the parked one was, facing north
    lda #0
    sta car_xh
    lda st_col                      // x = column * 8 + 8
    asl
    rol car_xh
    asl
    rol car_xh
    asl
    rol car_xh
    clc
    adc #8
    sta car_xl
    lda car_xh
    adc #0
    sta car_xh
    lda #0
    sta car_yh
    lda st_row                      // y = row * 8 + 10
    asl
    rol car_yh
    asl
    rol car_yh
    asl
    rol car_yh
    clc
    adc #10
    sta car_yl
    lda car_yh
    adc #0
    sta car_yh
    lda #0                          // a car, facing north
    sta is_bus
// (try_bus too: a = the heading) in it, standing
ts_take:
    sta hdg
    sta mang
    clc
    adc #8
    lsr
    lsr
    lsr
    lsr
    sta car_frame
    lda #0
    sta car_xf
    sta car_yf
    sta hdg_f
    sta spd_l
    sta spd_h
    sta vx_l
    sta vx_h
    sta vy_l
    sta vy_h
    sta burn
    sta paint_t
    jsr clean_car                   // not the getaway car
    lda #1
    sta have_car
    lda #ST_DRIVE
    sta state
    lda #SFX_DOOR
    jsr sfx_play
    jsr steal_seen                  // did the police see it?
    sec
    rts

// put parked car st_kind ($ff: road) at st_col/st_row into the map, and on
// the screen if st_scr
put_car:
    lda #0
    sta ts_n
pk_loop:
    lda ts_n
    lsr
    clc
    adc st_row
    sta mrow
    lda ts_n
    and #1
    clc
    adc st_col
    sta mcol
    lda #ROADCH
    ldx st_kind
    bmi !+
    lda kind6,x
    clc
    adc ts_n
    tax
    lda park_chars,x
!:  sta ma_v
    pha
    ldx mrow
    lda mcol
    jsr map_wr
    pla
    ldx st_scr
    beq !+
    jsr screen_cell
!:  inc ts_n
    lda ts_n
    cmp #6
    bne pk_loop
    rts
// carry set if the 16-bit difference (a = high, t0 = low) is within -17..17
near18:
    cmp #0
    bne n18_neg
    lda t0
    cmp #18
    bcs n18_no
    sec
    rts
n18_neg:
    cmp #$ff
    bne n18_no
    lda t0
    cmp #$ef
    bcc n18_no
    rts
n18_no:
    clc
    rts

man_try_x:                          // a = +1 / -1
    sta t2
    clc
    adc man_xl
    sta bx_l
    lda t2
    and #$80
    beq !+
    lda #$ff
!:  adc man_xh
    sta bx_h
    lda man_yl
    sta by_l
    lda man_yh
    sta by_h
    jsr man_box
    bne !+
    lda bx_l
    sta man_xl
    lda bx_h
    sta man_xh
    inc t3
!:  rts
man_try_y:
    sta t2
    clc
    adc man_yl
    sta by_l
    lda t2
    and #$80
    beq !+
    lda #$ff
!:  adc man_yh
    sta by_h
    lda man_xl
    sta bx_l
    lda man_xh
    sta bx_h
    jsr man_box
    bne !+
    lda by_l
    sta man_yl
    lda by_h
    sta man_yh
    inc t3
!:  rts

// =====================================================================
// the robbery
// =====================================================================
start_rob:
    lda #ST_ROB
    sta state
    ldx #<ROB_FRAMES                // (a card shop)
    ldy #>ROB_FRAMES
    lda target
    cmp #16
    bcs !+
    ldx #<BANK_FRAMES               // a bank: quicker
    ldy #>BANK_FRAMES
!:  stx rob_l
    sty rob_h
    lda #1
    sta bub_cd
    lda #0
    sta bub_n
    sta bag
    sta bul_t                       // a bullet in the air is gone
    lda rng
    eor vbl
    bne !+
    lda #1
!:  sta rng
    lda #SFX_DOOR
    jsr sfx_play
    rts

do_rob:
    dec bub_cd
    bne !+
    lda #BUBBLE_FRAMES
    sta bub_cd
#if REU
    jsr THINK_STUB                  // the REU edition: in a card shop Vinnie
    bcs !+                          // ponders first (carry: a thought, no bubble)
#endif
    jsr new_bubble
!:  lda rob_l
    bne !+
    dec rob_h
!:  dec rob_l
    lda rob_l
    ora rob_h
    beq end_rob
    rts
end_rob:
    jsr clear_bubble
    ldx target
    lda door_xl,x
    sta man_xl
    lda door_xh,x
    sta man_xh
    lda door_yl,x
    clc
    adc #4
    sta man_yl
    lda door_yh,x
    adc #0
    sta man_yh
    lda #2
    sta man_dir
    lda #1
    sta bag
    // the loot: a bank $1,000-$4,700, a card shop $200-$900 (BCD)
    lda target
    cmp #16                         // targets 16-31 are card shops
    bcc er_bank
    jsr rng_next
    and #$07
    clc
    adc #2
    bne er_loot                     // (always)
er_bank:
    jsr rng_next
    and #$03
    clc
    adc #1
    asl
    asl
    asl
    asl
    sta t0
    lda rng
    lsr
    lsr
    and #$07
    ora t0
er_loot:
    sta loot                        // carried until it is at the friend's
    sed                             // house (points only then)
    clc
    adc carry_l
    sta carry_l
    lda carry_h
    adc #0
    sta carry_h
    cld
    lda #1                          // the car outside is the getaway car now
    sta hot
    lda #SFX_CHING
    jsr sfx_play
    lda target
    clc
    adc #3
    and #NBANKS - 1
    sta target
    lda #ST_WALK
    sta state
    jsr job_done                    // time bonus, the next job, the police
    jmp guard_out                   // and a guard runs out after him

// a comic bubble near the bank door, different word and colour each time
new_bubble:
    jsr clear_bubble
    jsr rng_next
    and #15
    sta bub_word
    tax
    lda word_len,x
    asl
    clc
    adc #2
    sta bub_w
    lda bub_n
    and #3
    tax
    lda bubble_cols,x
    sta bub_col
    // door position on screen
    ldx target
    lda door_xl,x
    sta t0
    lda door_xh,x
    lsr
    ror t0
    lsr
    ror t0
    lsr
    ror t0
    lda t0
    sec
    sbc disp_cx
    sta t0                          // door column on screen
    lda door_yl,x
    sta t1
    lda door_yh,x
    lsr
    ror t1
    lsr
    ror t1
    lsr
    ror t1
    lda t1
    sec
    sbc disp_cy
    sta t1                          // door row on screen
    ldx bub_n
    lda bub_n
    cmp #5
    bcc !+
    ldx #4
!:  lda bub_w
    lsr
    sta t2
    lda t0
    sec
    sbc t2
    clc
    adc bubble_dx,x
    bpl !+
    lda #0
!:  sta bub_x
    lda #40
    sec
    sbc bub_w
    cmp bub_x
    bcs !+
    sta bub_x
!:  lda t1
    clc
    adc bubble_dy,x
    bpl !+
    lda #0
!:  cmp #21
    bcc !+
    lda #21
!:  sta bub_y
    inc bub_n
    lda #SFX_POW
    jsr sfx_play

// draw the bubble: bub_word, bub_w, bub_col, bub_x, bub_y
draw_bubble:
    // row 0: top edge with spikes
    ldx bub_w
    dex
    lda #B_TR
    sta tbuf,x
    dex
!:  lda #B_T
    sta tbuf,x
    txa
    and #3
    cmp #2
    bne nb_t
    lda #B_TS
    sta tbuf,x
nb_t:
    dex
    bne !-
    lda #B_TL
    sta tbuf
    lda #0
    jsr bubble_row
    // rows 1 and 2: letters
    lda #B_L
    sta tbuf
    ldx bub_w
    dex
    lda #B_R
    sta tbuf,x
    ldx bub_word
    lda word_start,x
    sta t2
    lda word_len,x
    sta t3
    ldy #1
!:  ldx t2
    lda WORD_GLYPHS,x
    tax
    lda GL_TL,x
    sta tbuf,y
    lda GL_TR,x
    sta tbuf + 1,y
    iny
    iny
    inc t2
    dec t3
    bne !-
    lda #1
    jsr bubble_row
    ldx bub_word
    lda word_start,x
    sta t2
    lda word_len,x
    sta t3
    ldy #1
!:  ldx t2
    lda WORD_GLYPHS,x
    tax
    lda GL_BL,x
    sta tbuf,y
    lda GL_BR,x
    sta tbuf + 1,y
    iny
    iny
    inc t2
    dec t3
    bne !-
    lda #2
    jsr bubble_row
    // row 3: bottom edge
    ldx bub_w
    dex
    lda #B_BR
    sta tbuf,x
    dex
!:  lda #B_B
    sta tbuf,x
    txa
    and #3
    cmp #0
    bne nb_b
    lda #B_BS
    sta tbuf,x
nb_b:
    dex
    bne !-
    lda #B_BL
    sta tbuf
    lda #3
    jsr bubble_row
    lda #1
    sta bub_on
    rts

// copy tbuf to bubble row a (screen and color RAM)
bubble_row:
    clc
    adc bub_y
    tax
    lda srow_lo,x
    clc
    adc bub_x
    sta zp1
    sta zp0
    lda srow_hi,x
    adc #0
    sta t2
    ora front_hi
    sta zp1 + 1
    lda t2
    ora #$d8
    sta zp0 + 1
    lda bub_col
    ora #$08
    sta t2
    ldy bub_w
    dey
!:  lda tbuf,y
    sta (zp1),y
    lda t2
    sta (zp0),y
    dey
    bpl !-
    rts

// put the city back where the bubble was
clear_bubble:
    lda bub_on
    bne !+
    rts
!:  lda #0
    sta bub_on
    sta t3
cb_row:
    lda bub_y
    clc
    adc t3
    tax
    lda srow_lo,x
    clc
    adc bub_x
    sta zp1
    sta zdst
    lda srow_hi,x
    adc #0
    sta t2
    ora front_hi
    sta zp1 + 1
    lda t2
    ora #$d8
    sta zdst + 1
    txa
    clc
    adc disp_cy
    tax
    lda disp_cx
    clc
    adc bub_x
    jsr map_fill                    // (row x, from column a)
    lda bub_y                       // the colour of that row's band
    clc
    adc t3
    tax
    lda rowc,x
    sta t2
    ldy bub_w
    dey
!:  lda tbuf,y
    sta (zp1),y
    lda t2
    sta (zdst),y
    dey
    bpl !-
    inc t3
    lda t3
    cmp #4
    bne cb_row
    rts

// =====================================================================
// camera and scrolling
// =====================================================================
// t0/t1, t2/t3 = where the camera wants to be (top left of the view)
camera_target:
    lda state
    cmp #ST_DRIVE
    bne ct_man
    lda car_xl
    sec
    sbc #152
    sta t0
    lda car_xh
    sbc #0
    sta t1
    lda car_yl
    sec
    sbc #96
    sta t2
    lda car_yh
    sbc #0
    sta t3
    // look ahead: velocity x 16
    lda vx_h
    sta t5
    lda vx_l
    sta t4
    ldx #4
!:  lda t5
    cmp #$80
    ror t5
    ror t4
    dex
    bne !-
    lda t4
    clc
    adc t0
    sta t0
    lda t5
    adc t1
    sta t1
    lda vy_h
    sta t5
    lda vy_l
    sta t4
    ldx #4
!:  lda t5
    cmp #$80
    ror t5
    ror t4
    dex
    bne !-
    lda t4
    clc
    adc t2
    sta t2
    lda t5
    adc t3
    sta t3
    rts
ct_man:
    lda man_xl
    sec
    sbc #152
    sta t0
    lda man_xh
    sbc #0
    sta t1
    lda man_yl
    sec
    sbc #(96 - 8)
    sta t2
    lda man_yh
    sbc #0
    sta t3
    rts

update_camera:
    lda cam_xl                      // for predict: how far it moves
    sta last_xl
    lda cam_yl
    sta last_yl
    jsr camera_target
    // cam += (target - cam) / 8, both axes, 16.8 fixed point
    lda #0
    sec
    sbc cam_xf
    sta t4
    lda t0
    sbc cam_xl
    sta t0
    lda t1
    sbc cam_xh
    sta t1
    ldx #3
!:  lda t1
    cmp #$80
    ror t1
    ror t0
    ror t4
    dex
    bne !-
    lda cam_xf
    clc
    adc t4
    sta cam_xf
    lda cam_xl
    adc t0
    sta cam_xl
    lda cam_xh
    adc t1
    sta cam_xh
    lda #0
    sec
    sbc cam_yf
    sta t4
    lda t2
    sbc cam_yl
    sta t2
    lda t3
    sbc cam_yh
    sta t3
    ldx #3
!:  lda t3
    cmp #$80
    ror t3
    ror t2
    ror t4
    dex
    bne !-
    lda cam_yf
    clc
    adc t4
    sta cam_yf
    lda cam_yl
    adc t2
    sta cam_yl
    lda cam_yh
    adc t3
    sta cam_yh
clamp_camera:
    lda cam_xh
    bpl !+
    lda #0
    sta cam_xh
    sta cam_xl
    sta cam_xf
!:  lda cam_xl
    cmp #<CAMX_MAX
    lda cam_xh
    sbc #>CAMX_MAX
    bcc !+
    lda #<CAMX_MAX
    sta cam_xl
    lda #>CAMX_MAX
    sta cam_xh
    lda #0
    sta cam_xf
!:  lda cam_yh
    bpl !+
    lda #0
    sta cam_yh
    sta cam_yl
    sta cam_yf
!:  lda cam_yl
    cmp #<CAMY_MAX
    lda cam_yh
    sbc #>CAMY_MAX
    bcc !+
    lda #<CAMY_MAX
    sta cam_yl
    lda #>CAMY_MAX
    sta cam_yh
    lda #0
    sta cam_yf
!:  rts

// ncx/ncy = camera position in characters
cam_chars:
    lda cam_xh
    sta t0
    lda cam_xl
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    sta ncx
    lda cam_yh
    sta t0
    lda cam_yl
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    sta ncy
    rts

scroll_regs:
    lda cam_xl
    and #7
    eor #$17                        // multicolor, 38 columns, xscroll = 7 - fine x
    sta sh_d016
    lda cam_yl
    and #7
    eor #$17                        // screen on, 24 rows, yscroll = 7 - fine y
    sta sh_d011
    // world y w is shown on raster line GREEN_BASE + w - cam_y: the suburb
    // (row SUB_ROW) starts at line GREEN_BASE + SUB_ROW * 8 - cam_y
    lda #<(GREEN_BASE + SUB_ROW * 8)
    sec
    sbc cam_yl
    tax
    lda #>(GREEN_BASE + SUB_ROW * 8)
    sbc cam_yh
    bmi sr_all                      // above the screen: all of it green
    bne sr_none                     // below the screen
    cpx #IRQ_LINE
    bcs sr_none
    cpx #GREEN_BASE + 1
    bcc sr_all
    dex                             // the line before it
    stx sh_gline
    rts
sr_all:
    lda #1                          // (1: green from the top)
    sta sh_gline
    rts
sr_none:
    lda #0
    sta sh_gline
    rts

// If the camera crossed a character boundary, build the next picture in the
// hidden buffer: shift the shown one by one character (any of 8 directions)
// and fetch the new edge column/row from the map. The IRQ swaps buffers.
scroll_prepare:
    jsr cam_chars
    lda ncx
    sec
    sbc disp_cx
    sta ddx
    lda ncy
    sec
    sbc disp_cy
    sta ddy
    ora ddx
    bne sp_cross
    jsr predict
    jmp scroll_regs
sp_cross:
    inc scrolled
    inc n_cross
    lda front_hi
    eor #$04
    sta back_hi
    // big jump (never while playing): draw everything
    lda ddx
    clc
    adc #1
    cmp #3
    bcs sp_full
    lda ddy
    clc
    adc #1
    cmp #3
    bcs sp_full
    // the first half of the shift done already (for this direction)?
    lda pending
    beq sp_hold
    lda ddx
    cmp pend_dx
    bne sp_hold
    lda ddy
    cmp pend_dy
    bne sp_hold
    lda ddx
    sta t0
    lda ddy
    sta t1
    jsr dd_offset
    jsr shift_half1
    lda #0
    sta pending
sp_edges:
    lda ddx
    beq sp_rows
    bmi !+
    lda #39
    jsr draw_col
    jmp sp_rows
!:  lda #0
    jsr draw_col
sp_rows:
    lda ddy
    beq sp_flip
    bmi !+
    lda #24
    jsr draw_row
    jmp sp_flip
!:  lda #0
    jsr draw_row
    jmp sp_flip
sp_full:
    lda #0
    sta pending
    jsr full_redraw
sp_flip:
    lda ncx
    sta disp_cx
    lda ncy
    sta disp_cy
    lda back_hi
    sta front_hi
    lda front
    eor #1
    sta front
    tax
    lda d018_tab,x
    sta sh_d018
    jmp scroll_regs
sp_hold:
    inc n_hold
    // not prepared: the camera stays on this side of the boundary for a
    // frame while the first half is shifted
    lda ddx
    sta pend_dx
    sta t0
    beq sp_hy
    bmi !+
    lda disp_cx                     // moving right: x = disp_cx * 8 + 7
    jsr times8
    ora #7
    sta cam_xl
    stx cam_xh
    lda #$ff
    sta cam_xf
    jmp sp_hy
!:  lda disp_cx                     // moving left: x = disp_cx * 8
    jsr times8
    sta cam_xl
    stx cam_xh
    lda #0
    sta cam_xf
sp_hy:
    lda ddy
    sta pend_dy
    sta t1
    beq sp_half
    bmi !+
    lda disp_cy
    jsr times8
    ora #7
    sta cam_yl
    stx cam_yh
    lda #$ff
    sta cam_yf
    jmp sp_half
!:  lda disp_cy
    jsr times8
    sta cam_yl
    stx cam_yh
    lda #0
    sta cam_yf
sp_half:
    jsr dd_offset
    jsr shift_half0
    lda #1
    sta pending
    jmp scroll_regs

// a (0-127) * 8 -> a (low), x (high)
times8:
    ldx #0
    stx t2
    asl
    rol t2
    asl
    rol t2
    asl
    rol t2
    ldx t2
    rts

// Where will the camera be next frame (it moves about as much as in this
// one)? If that is over a character boundary, shift the first half now.
predict:
    lda pending
    bne pr_done
    lda cam_xl
    sec
    sbc last_xl
    jsr pr_axis_x
    sta t0
    lda cam_yl
    sec
    sbc last_yl
    jsr pr_axis_y
    sta t1
    ora t0
    beq pr_done
    lda t0
    clc
    adc #1
    cmp #3
    bcs pr_done
    lda t1
    clc
    adc #1
    cmp #3
    bcs pr_done
    lda t0
    sta pend_dx
    lda t1
    sta pend_dy
    inc scrolled
    jsr dd_offset
    jsr shift_half0
    lda #1
    sta pending
pr_done:
    rts
// a = movement this frame -> a = predicted character step (x / y)
pr_axis_x:
    ldx #0
    cmp #$80
    bcc !+
    dex
!:  stx t3
    clc
    adc cam_xl
    sta t2
    lda cam_xh
    adc t3
    jsr pr_chars
    sec
    sbc disp_cx
    rts
pr_axis_y:
    ldx #0
    cmp #$80
    bcc !+
    dex
!:  stx t3
    clc
    adc cam_yl
    sta t2
    lda cam_yh
    adc t3
    jsr pr_chars
    sec
    sbc disp_cy
    rts
pr_chars:                           // (a:t2) / 8
    lsr
    ror t2
    lsr
    ror t2
    lsr
    ror t2
    lda t2
    rts

// x = 41 + t0 + 40 * t1 (t0, t1 = -1..1): the shift routine's offset
dd_offset:
    lda #41
    clc
    adc t0
    ldx t1
    beq !++
    bmi !+
    clc
    adc #40
    jmp !++
!:  sec
    sbc #40
!:  tax
    rts

// the generated shift in two halves (500 characters each), x = offset
.const HALF = 500 * 6
shift_half0:
    lda front
    bne !+
    lda #$60                        // rts in the middle for a moment
    sta shift_ab + HALF
    jsr shift_ab
    lda #$bd
    sta shift_ab + HALF
    rts
!:  lda #$60
    sta shift_ba + HALF
    jsr shift_ba
    lda #$bd
    sta shift_ba + HALF
    rts
shift_half1:
    lda front
    bne !+
    jmp shift_ab + HALF
!:  jmp shift_ba + HALF


full_redraw:
    lda #0
!:  pha
    jsr draw_row
    pla
    clc
    adc #1
    cmp #25
    bne !-
    rts

// draw screen row a of the back buffer from the map (camera ncx/ncy)
draw_row:
    tax
    lda srow_lo,x
    sta dr_lo
    lda srow_hi,x
    ora back_hi
    sta dr_hi
    txa
    clc
    adc ncy
    tax                             // the world row (map_at keeps it)
    lda ncx
    sta mf_c
    lda #0
    sta mf_i                        // screen columns done
dr_seg:
    lda mf_c
    jsr map_at
    sty dc_y
    lda dr_lo                       // zp1 = screen + done - y: the same y
    clc                             // for the block row and the screen
    adc mf_i
    sta zp1
    lda dr_hi
    adc #0
    sta zp1 + 1
    lda zp1
    sec
    sbc dc_y
    sta zp1
    bcs !+
    dec zp1 + 1
!:  lda #40                         // up to the block's edge or the end
    sec
    sbc mf_i
    clc
    adc dc_y
    cmp #32
    bcc !+
    lda #32
!:  sta dr_end
dr_loop:
    lda (zp0),y
    sta (zp1),y
    iny
    cpy dr_end
    bne dr_loop
    tya
    sec
    sbc dc_y
    clc
    adc mf_i
    sta mf_i
    cmp #40
    bcs !+
    clc
    adc ncx
    sta mf_c
    jmp dr_seg
!:  rts

// tbuf = the 40 map characters from column a of row x on (x is kept)
map_fill:
    sta mf_c
    lda #0
    sta mf_i
mf_seg:
    lda mf_c
    jsr map_at
    stx mf_r
    ldx mf_i
mf_loop:
    lda (zp0),y
    sta tbuf,x
    inx
    cpx #40
    beq mf_done
    iny
    cpy #32
    bne mf_loop
    txa                             // the next block
    sec
    sbc mf_i
    clc
    adc mf_c
    sta mf_c
    stx mf_i
    ldx mf_r
    jmp mf_seg
mf_done:
    ldx mf_r
    rts

// draw screen column a of the back buffer from the map: down one column of
// a block, 8 rows a run (one page), with the same y for block and screen
draw_col:
    sta t0
    clc
    adc ncx
    sta dc_c
    lda ncy
    sta dc_r
    lda t0
    sta dr_lo
    lda back_hi
    sta dr_hi
    lda #25
    sta dc_n
dc_seg:
    ldx dc_r
    lda dc_c
    jsr map_at
    sty dc_y
    lda dr_lo                       // zp1 = screen - y
    sec
    sbc dc_y
    sta zp1
    lda dr_hi
    sbc #0
    sta zp1 + 1
    lda zp0 + 1                     // rows in this run: to the page's end
    cmp #>wall_row                  // (the wall: one)
    bne !+
    lda #1
    bne dc_k1
!:  lda dc_r
    clc
    adc #-BLK_Y0
    and #7
    eor #7
    clc
    adc #1
dc_k1:
    cmp dc_n
    bcc !+
    lda dc_n
!:  sta dc_k
    tax
dc_loop:
    lda (zp0),y
    sta (zp1),y
    lda zp0
    clc
    adc #32
    sta zp0
    lda zp1
    clc
    adc #40
    sta zp1
    bcc !+
    inc zp1 + 1
!:  dex
    bne dc_loop
    lda zp1
    clc
    adc dc_y
    sta dr_lo
    lda zp1 + 1
    adc #0
    sta dr_hi
    lda dc_r
    clc
    adc dc_k
    sta dc_r
    lda dc_n
    sec
    sbc dc_k
    sta dc_n
    bne dc_seg
    rts

// The shift routines are generated at run time, fully unrolled:
// 1000 x "lda src - 41 + i,x / sta dst + i" (about 8,250 cycles), entered with
// x = 41 + offset. A->B lives where the packed map was (free once the map
// is unpacked), B->A where the title picture was.
.label shift_ab = map_rle
.label shift_ba = BITMAP
.label TAIL = map_rle + 6001        // free after start-up: the moved tables
// zdst = where, t0/t1 = source screen, t2/t3 = destination screen
gen_shift:
    lda t0
    sec
    sbc #41
    sta t0
    bcs !+
    dec t1
!:  lda #<1000
    sta t4
    lda #>1000
    sta t5
    ldy #0
gs_loop:
    lda #$bd                        // lda abs,x
    jsr unp_put
    lda t0
    jsr unp_put
    lda t1
    jsr unp_put
    lda #$8d                        // sta abs
    jsr unp_put
    lda t2
    jsr unp_put
    lda t3
    jsr unp_put
    inc t0
    bne !+
    inc t1
!:  inc t2
    bne !+
    inc t3
!:  lda t4
    bne !+
    dec t5
!:  dec t4
    lda t4
    ora t5
    bne gs_loop
    lda #$60                        // rts
    jmp unp_put

// =====================================================================
// sprites and HUD
// =====================================================================
// world position (px, py) -> sprite x of sprite X, with offsets t4 (x) / t5 (y).
// Carry set if on screen.
spr_pos:
    lda px_l
    sec
    sbc cam_xl
    sta t0
    lda px_h
    sbc cam_xh
    sta t1
    lda t0
    clc
    adc t4
    sta t0
    lda t1
    adc #0
    sta t1
    bmi sp_off
    cmp #2
    bcs sp_off
    cmp #1
    bne !+
    lda t0
    cmp #88                         // x < 344
    bcs sp_off
!:  lda py_l
    sec
    sbc cam_yl
    sta t2
    lda py_h
    sbc cam_yh
    sta t3
    lda t2
    clc
    adc t5
    sta t2
    lda t3
    adc #0
    bne sp_off
    lda t2
    cmp #252
    bcs sp_off
    sta sh_y,x
    lda t0
    sta sh_x,x
    lda bit_tab,x
    eor #$ff
    and sh_msb
    sta sh_msb
    lda t1
    beq !+
    lda bit_tab,x
    ora sh_msb
    sta sh_msb
!:  lda bit_tab,x
    ora sh_en
    sta sh_en
    sec
    rts
sp_off:
    clc
    rts


place_sprites:
    lda state                       // during a message: as before it
    cmp #ST_MSG
    bne !+
    lda msg_prev
!:  sta pstate
    lda #%00001000                  // the arrow is always there
    sta sh_en
    lda #0
    sta sh_msb
    sta sh_xexp
    sta sh_yexp
    // the car's paint (changes once, when the spray job is done)
    lda car_col
    sta sh_col + 5
    // the car (sprite 5), unless the police took it
    lda have_car
    beq ps_nocar
    lda car_xl
    sta px_l
    lda car_xh
    sta px_h
    lda car_yl
    sta py_l
    lda car_yh
    sta py_h
    lda #19
    sta t4
    lda #44
    sta t5
    lda is_bus                      // a hijacked bus: 4 directions, expanded
    beq ps_car
    lda car_frame
    clc
    adc #2
    lsr
    lsr
    and #3
    pha
    lsr
    bcc !+
    lda #7                          // east / west
    sta t4
    lda #$20
    sta sh_xexp
    bne ps_bus
!:  lda #33                         // north / south
    sta t5
    lda #$20
    sta sh_yexp
ps_bus:
    ldx #5
    jsr spr_pos
    pla
    clc
    adc #SP_BUS
    sta sh_ptr + 5
    jmp ps_nocar
ps_car:
    ldx #5
    jsr spr_pos
    lda car_frame
    clc
    adc #SP_CAR
    sta sh_ptr + 5
ps_nocar:
    // the bandit (sprite 4)
    lda pstate
    cmp #ST_WALK
    bne ps_marker
    lda #8
    sta sh_col + 4
    lda man_xl
    sta px_l
    lda man_xh
    sta px_h
    lda man_yl
    sta py_l
    lda man_yh
    sta py_h
    lda #19
    sta t4
    lda #37
    sta t5
    ldx #4
    jsr spr_pos
    lda man_dir
    asl
    sta t0
    lda man_anim
    lsr
    lsr
    lsr
    and #1
    ora t0
    ldx bag
    beq !+
    clc
    adc #8
!:  clc
    adc #SP_MAN
    sta sh_ptr + 4
ps_marker:
    // a police bullet in flight takes sprite 6 (a white dot)
    lda bul_t
    beq ps_mark
    lda bul_xl
    sta px_l
    lda bul_xh
    sta px_h
    lda bul_yl
    sta py_l
    lda bul_yh
    sta py_h
    lda #29
    sta t4
    lda #52
    sta t5
    ldx #6
    jsr spr_pos
    lda #SP_DOT
    sta sh_ptr + 6
    jmp ps_arrow
ps_mark:
    // the marker over the target bank (sprite 6), not during the robbery
    lda pstate
    cmp #ST_ROB
    beq ps_arrow
    jsr goal_idx
    lda door_xl,x
    sta px_l
    lda door_xh,x
    sta px_h
    lda door_yl,x
    sta py_l
    lda door_yh,x
    sta py_h
    lda vbl
    lsr
    lsr
    and #7
    tay
    lda bounce_tab,y
    sta t5
    lda #19
    sta t4
    ldx #6
    jsr spr_pos
    lda vbl
    lsr
    lsr
    lsr
    and #1
    clc
    adc #SP_MARK
    sta sh_ptr + 6
ps_arrow:
    // the arrow (sprite 3) points from the player to the next job, the
    // friend's house or a paint garage (arrow_mode; its colour says which)
    ldx arrow_mode
    lda arrow_cols,x
    sta sh_col + 3
    lda pstate
    cmp #ST_WALK
    bne !+
    lda man_xl
    sta px_l
    lda man_xh
    sta px_h
    lda man_yl
    sta py_l
    lda man_yh
    sta py_h
    jmp pa_go
!:  lda car_xl
    sta px_l
    lda car_xh
    sta px_h
    lda car_yl
    sta py_l
    lda car_yh
    sta py_h
pa_go:
    jsr goal_idx
    lda door_xl,x
    sec
    sbc px_l
    sta ax_l
    lda door_xh,x
    sbc px_h
    sta ax_h
    lda door_yl,x
    sec
    sbc py_l
    sta ay_l
    lda door_yh,x
    sbc py_h
    sta ay_h
    jsr direction16
    clc
    adc #SP_ARROW
    sta sh_ptr + 3
    jmp place_npcs


// a = direction 0-15 (0 = north, clockwise) of the vector (ax, ay)
direction16:
    lda #0
    sta t5                          // quadrant bits: 1 = dx<0, 2 = dy>=0
    lda ax_h
    bpl !+
    lda #1
    sta t5
    lda #0
    sec
    sbc ax_l
    sta ax_l
    lda #0
    sbc ax_h
    sta ax_h
!:  lda ay_h
    bmi !+
    lda t5
    ora #2
    sta t5
    jmp d16_abs
!:  lda #0
    sec
    sbc ay_l
    sta ay_l
    lda #0
    sbc ay_h
    sta ay_h
d16_abs:
    // s = 4 if 5|dy| < |dx|, 3 if 3|dy| < 2|dx|, 2 if 2|dy| < 3|dx|, 1 if |dy| < 5|dx|, else 0
    ldx #4
    lda ay_l
    ldy ay_h
    jsr times5
    jsr cmp_ax1
    bcc d16_quad
    dex
    lda ay_l
    ldy ay_h
    jsr times3
    sta t0
    sty t1
    lda ax_l
    asl
    sta t2
    lda ax_h
    rol
    sta t3
    jsr cmp_t01_t23
    bcc d16_quad
    dex
    lda ax_l
    ldy ax_h
    jsr times3
    sta t2
    sty t3
    lda ay_l
    asl
    sta t0
    lda ay_h
    rol
    sta t1
    jsr cmp_t01_t23
    bcc d16_quad
    dex
    lda ax_l
    ldy ax_h
    jsr times5
    sta t2
    sty t3
    lda ay_l
    sta t0
    lda ay_h
    sta t1
    jsr cmp_t01_t23
    bcc d16_quad
    dex
d16_quad:
    stx t0
    lda t5
    beq d16_ne
    cmp #2
    beq d16_se
    cmp #3
    beq d16_sw
    lda #16                         // NW
    sec
    sbc t0
    and #15
    rts
d16_ne:
    lda t0
    rts
d16_se:
    lda #8
    sec
    sbc t0
    rts
d16_sw:
    lda #8
    clc
    adc t0
    rts

// a/y (16-bit) * 5 -> a/y ; * 3 -> a/y (values stay below 5120)
times5:
    sta t0
    sty t1
    asl
    sta t2
    tya
    rol
    sta t3
    asl t2
    rol t3
    lda t2
    clc
    adc t0
    pha
    lda t3
    adc t1
    tay
    pla
    rts
times3:
    sta t0
    sty t1
    asl
    sta t2
    tya
    rol
    sta t3
    lda t2
    clc
    adc t0
    pha
    lda t3
    adc t1
    tay
    pla
    rts
// carry clear if (a/y) < ax
cmp_ax1:
    cmp ax_l
    tya
    sbc ax_h
    rts
// carry clear if t0/t1 < t2/t3
cmp_t01_t23:
    lda t0
    cmp t2
    lda t1
    sbc t3
    rts

hud_update:
    lda scrolled
    beq !+
    rts
!:  lda fps_val
    cmp fps_shown
    beq hu_score
    sta fps_shown
    ldx #0
!:  cmp #10
    bcc !+
    sbc #10
    inx
    jmp !-
!:  sta t3
    lda #<SPRLO
    sta zp1
    lda #>SPRLO
    sta zp1 + 1
    txa
    ldx #0
    jsr hud_digit
    lda t3
    ldx #1
    jsr hud_digit
hu_score:
    lda score_dirty
    beq hu_done
    lda #0
    sta score_dirty
    lda #<(SPRLO + 64)
    sta zp1
    lda #>(SPRLO + 64)
    sta zp1 + 1
    lda score + 2
    lsr
    lsr
    lsr
    lsr
    ldx #0
    jsr hud_digit
    lda score + 2
    and #15
    ldx #1
    jsr hud_digit
    lda score + 1
    lsr
    lsr
    lsr
    lsr
    ldx #2
    jsr hud_digit
    lda #<(SPRLO + 128)
    sta zp1
    lda score + 1
    and #15
    ldx #0
    jsr hud_digit
    lda score
    lsr
    lsr
    lsr
    lsr
    ldx #1
    jsr hud_digit
    lda score
    and #15
    ldx #2
    jsr hud_digit
hu_done:
    // job timer and lives / wanted stars
    lda hud_dirty
    bne !+
    rts
!:  lda #<(SPRLO + (SP_TIME - 32) * 64)
    sta zp1
    lda #>(SPRLO + (SP_TIME - 32) * 64)
    sta zp1 + 1
    lda hud_dirty
    and #1
    beq hu_lv
    lda job_time
    lsr
    lsr
    lsr
    lsr
    ldx #1
    jsr hud_digit
    lda job_time
    and #15
    ldx #2
    jsr hud_digit
hu_lv:
    lda hud_dirty
    and #2
    beq hu_clean
    lda #10
    ldx #0
    jsr hud_digit
    lda #<(SPRLO + (SP_LIVES - 32) * 64)
    sta zp1
    lda #>(SPRLO + (SP_LIVES - 32) * 64)
    sta zp1 + 1
    ldx #0
hu_life:
    lda #10                         // a heart per life left
    cpx lives
    bcs !+
    lda #11
!:  stx t5
    jsr hud_digit
    ldx t5
    lda #13                         // a star per police car to come
    cpx wanted
    bcs !+
    lda #12
!:  jsr hud_label
    ldx t5
    inx
    cpx #3
    bne hu_life
hu_clean:
    lda #0
    sta hud_dirty
    rts

// glyph a into cell x of the label row of the HUD sprite at (zp1)
hud_label:
    sta t0
    txa
    clc
    adc #21
    jmp hd_common
// digit a into cell x of the HUD sprite at (zp1)
hud_digit:
    sta t0
    txa
    clc
    adc #3                          // sprite row 1
hd_common:
    sta t1
    lda t0
    asl
    asl
    adc t0                          // glyph * 5
    tay
    lda #5
    sta t2
!:  lda digit_rows,y
    sty t0
    ldy t1
    sta (zp1),y
    ldy t0
    iny
    lda t1
    clc
    adc #3
    sta t1
    dec t2
    bne !-
    rts

#import "chase.asm"
#import "screens.asm"

// =====================================================================
#import "music.asm"

// =====================================================================
// tables and data
// =====================================================================


// the block designs (packed; unpacked to BLOCKS at start-up), then room
// for the A->B shift and the moved tables (TAIL) that go here afterwards
.var blockBytes = List()
.for (var b = 0; b < NBLOCKS; b++) .for (var i = 0; i < BW * BH; i++) .eval blockBytes.add(blocks.get(b).get(i))
// then room for the private copies and the grid (filled at run time), then
// the tables of map_at: per column the block column ($ff: wall) and the
// column in the block, per row the grid row offset, the page (0 / 1) and
// the offset in the page
.for (var i = 0; i < NPRIV * 512 + 256; i++) .eval blockBytes.add(0)
.for (var c = 0; c < 256; c++) .eval blockBytes.add((c < 2 || c >= 254) ? $ff : floor((c - BLK_X0) / 32))
.for (var c = 0; c < 256; c++) .eval blockBytes.add(mod(c - BLK_X0, 32))
.for (var r = 0; r < 256; r++) .eval blockBytes.add(floor((r - BLK_Y0) / 16) * GW)
.for (var r = 0; r < 256; r++) .eval blockBytes.add(mod(floor((r - BLK_Y0) / 8), 2))
.for (var r = 0; r < 256; r++) .eval blockBytes.add(mod(r - BLK_Y0, 8) * 32)
.for (var i = 0; i < danceSpr.size(); i++) .eval blockBytes.add(danceSpr.get(i))   // the dancers (DANCE_SRC)
.for (var i = 0; i < GW * GH; i++) .eval blockBytes.add((BLOCKS >> 8) + 2 * grid.get(i))   // GRID_ORIG
.for (var i = 0; i < 256; i++) .eval blockBytes.add(mapCode.get(i))   // MM_CODE
.for (var i = 0; i < wordGlyphs.size(); i++) .eval blockBytes.add(wordGlyphs.get(i))   // WORD_GLYPHS
.for (var i = 0; i < glTL.size(); i++) .eval blockBytes.add(glTL.get(i))
.for (var i = 0; i < glTR.size(); i++) .eval blockBytes.add(glTR.get(i))
.for (var i = 0; i < glBL.size(); i++) .eval blockBytes.add(glBL.get(i))
.for (var i = 0; i < glBR.size(); i++) .eval blockBytes.add(glBR.get(i))
.for (var i = 0; i < greetGlyphs.size(); i++) .eval blockBytes.add(greetGlyphs.get(i))   // GREET_GLY
.errorif GREET_GLY + greetGlyphs.size() > $c000, "the city area tables must end below $c000: " + toHexString(GREET_GLY + greetGlyphs.size())
.var mapPacked = rlePack(blockBytes)
.const MAP_AREA = max(mapPacked.size(), 6001 + TAIL_PAGES * 256)
map_rle:    .fill MAP_AREA, (i < mapPacked.size()) ? mapPacked.get(i) : 0
.var bmpPacked = rlePack(introBitmap)
intro_bitmap: .fill bmpPacked.size(), bmpPacked.get(i)
.var scrPacked = rlePack(introScreen)
intro_screen: .fill scrPacked.size(), scrPacked.get(i)
.var colPacked = rlePack(introColor)
intro_color: .fill colPacked.size(), colPacked.get(i)
program_end:

// only needed once at start-up (unpacked before the map goes to $8000, so
// this part may reach past $8000)
.var charsetBytes = List()
.for (var c = 0; c < 256; c++) .for (var b = 0; b < 8; b++) .eval charsetBytes.add((c < chars.size()) ? chars.get(c).get(b) : 0)
.var charsetPacked = rlePack(charsetBytes)
.var sprHiPacked = rlePack(sprHi)
.var sprLoPacked = rlePack(sprLo)
charset_rle: .fill charsetPacked.size(), charsetPacked.get(i)
sprhi_rle:  .fill sprHiPacked.size(), sprHiPacked.get(i)
sprlo_rle:  .fill sprLoPacked.size(), sprLoPacked.get(i)
cop_rot_data: .fill copRot.size(), copRot.get(i)
mus_store_data: .fill 256, (i < musStore.size()) ? musStore.get(i) : 0
// tables only used once the game runs: they travel in the start-up data
// (TAIL_SRC, via $e000) to TAIL, after the A->B shift where the packed map
// was (see start)
tail_src:
.pseudopc TAIL {
tail_start:
sin_tab:    .fill 256 + 64, (round(127 * sin(i * 2 * PI / 256)) + 256) & 255
srow_lo:    .fill 25, <(i * 40)
srow_hi:    .fill 25, >(i * 40)
class_tab:  .fill 256, (i < charClass.size()) ? charClass.get(i) : 0
skid_tab:   .fill 16, skidFor.get(mod(i, 8))
wheel_lx:   .fill 16, (wheelLX.get(i) + 256) & 255
wheel_ly:   .fill 16, (wheelLY.get(i) + 256) & 255
wheel_rx:   .fill 16, (wheelRX.get(i) + 256) & 255
wheel_ry:   .fill 16, (wheelRY.get(i) + 256) & 255
exit_dx:    .fill 16, (round(cos(i * PI / 8) * 15) + 256) & 255
exit_dy:    .fill 16, (round(sin(i * PI / 8) * 15) + 256) & 255
door_xl:    .fill goalX.size(), <goalX.get(i)
door_xh:    .fill goalX.size(), >goalX.get(i)
door_yl:    .fill goalY.size(), <goalY.get(i)
door_yh:    .fill goalY.size(), >goalY.get(i)
digit_rows: .fill digitRows.size(), digitRows.get(i)
bubble_cols: .byte 7, 1, 3, 5
bubble_dx:  .byte 256 - 6, 5, 256 - 2, 6, 0
bubble_dy:  .byte 256 - 8, 256 - 10, 256 - 12, 256 - 9, 256 - 11
// the guard sprites (8) and the bus (4, gfx_sprites.asm), unpacked to
// GUARDSPR by gen_shift_ba
.var guardPacked = rlePack(guardSpr)
guard_rle:  .fill guardPacked.size(), guardPacked.get(i)
park_chars: .fill 30, carKinds.get(floor(i / 6)).get(floor(mod(i, 6) / 2)).get(mod(i, 2))
kind6:      .byte 0, 6, 12, 18, 24
kind_col:   .byte $ff, 1, 0, 0, 15  // stolen cab ($ff: its band's colour), white car, black cars, grey car
tail_end:
}

.print "Tables moved out of the program: " + (tail_end - tail_start) + " bytes"

.errorif tail_end - tail_start > intro_bitmap - TAIL, "the moved tables do not fit after the A->B shift"
.errorif tail_end - tail_start <= (TAIL_PAGES - 1) * 256 || tail_end - tail_start > TAIL_PAGES * 256, "set TAIL_PAGES to " + ceil((tail_end - tail_start) / 256)
init_end:

.print "City: " + NBLOCKS + " block designs, packed " + mapPacked.size() + " bytes (area " + MAP_AREA + "), title: " + (bmpPacked.size() + scrPacked.size() + colPacked.size())
.print "Program ends at $" + toHexString(program_end) + ", start-up data at $" + toHexString(init_end)
.errorif program_end > BLOCKS, "program overlaps the city blocks at $8000"
.errorif init_end > $a000, "start-up data must end below $a000 (BASIC LOAD limit)"

// =====================================================================
// the REU edition (build with -define REU: build\boogie-reu.prg)
// =====================================================================
// The same game; the extras (the newspaper when Vinnie is busted) travel in
// the program file from $a000 (a LOAD may fill RAM up to $cfff) and are
// copied into the REU first thing at start (reu_init), before the city is
// unpacked over them. Without an REU the game runs as the standard one
// (reu_news is turned into an rts).
#if REU
#import "gfx_news.asm"
#import "gfx_think.asm"
.errorif init_end > $a000, "start-up data must end below $a000 in the REU edition too"
* = $a000 "REU extras"
extras:
news_ov_src:
.pseudopc NEWS_OV {
news_ov:
    jmp nv_main                     // + 0: the newspaper
nv_badge:                           // + 3: the title's REU badge
    lda #3 * 7 - 1
    sta nv_stop
    ldy #6 * 7 - 1
    jmp nv_get
nv_main:
    lda #0
    sta in_game
    sta $d015
    jsr sound_off
    lda #$0b
    sta $d011
    lda #$ff                        // bitmap, screen, colour RAM from the REU
    sta nv_stop
    ldy #3 * 7 - 1
    jsr nv_get
    jsr bm_show
    lda #1                          // white paper, a grey edge
    sta $d021
    lda #11
    sta $d020
!:  jsr wait_frame                 // until fire or SPACE
    jsr read_input
    lda joy_new
    and #$10
    ora key_map
    beq !-
    lda #0
    sta key_map                     // (SPACE must not open the city map too)
    sta $d020
    jmp sm_exit                     // back to the streets (as from the city map)
// REU -> C64: the blocks of nv_dma from index y down to nv_stop + 1 (with
// interrupts off: the IRQ's REU_TUNE uses the REU too)
nv_get:
    php
    sei
nv_get1:
    ldx #6
!:  lda nv_dma,y
    sta $df02,x
    dey
    dex
    bpl !-
    lda #$91
    sta $df01
    cpy nv_stop
    bne nv_get1
    plp
    rts
nv_stop: .byte 0
nv_dma: .word $d800, R_COLOUR       // (the last block is taken first)
        .byte 0
        .word 1000
        .word SCR_A, R_SCREEN
        .byte 0
        .word 1000
        .word $e000, R_BITMAP
        .byte 0
        .word 8000
        .word $d800 + 1, R_BADGE + 45   // the badge (row 0, columns 1-5)
        .byte 0
        .word 5
        .word SCR_A + 1, R_BADGE + 40
        .byte 0
        .word 5
        .word $e000 + 1 * 8, R_BADGE
        .byte 0
        .word 40
news_ov_end:
}
// "Hot Asphalt" in the gap up to the page
tune1_rec:
.fill TUNE_LEN, tuneB1.get(i)
.const R_TUNE1 = tune1_rec - extras
.errorif * > extras + R_SCREEN, "the newspaper code and the first tune are too long"
* = extras + R_SCREEN "REU extras: the newspaper"
.fill 1024, newsScreen.get(i)
.fill 1024, newsColour.get(i)
// the badge: "REU" in yellow on black, one row of 5 cells (01 black, 10 yellow)
.var badgeBits = List()
.for (var c = 0; c < 5; c++) .for (var r = 0; r < 8; r++) {
    .var v = 0
    .for (var p = 0; p < 4; p++) {
        .var x = c * 4 + p - 3
        .var on = false
        .if (x >= 0 && x < 15 && r < 7 && mod(x, 5) < 4) .eval on = fontPix("REU".charAt(floor(x / 5)), mod(x, 5), r)
        .eval v = v * 4 + (on ? 2 : 1)
    }
    .eval badgeBits.add(v)
}
.fill 40, badgeBits.get(i)
.fill 5, $07
.fill 5, 0
.errorif * != extras + R_TUNE2, "the REU extras' length is wrong"
// "Midnight Meter"
.fill TUNE_LEN, tuneB2.get(i)
// the thoughts in a card shop (gfx_think.asm): glyphs, texts
th_gly_rec:
.fill TH_NB * 8, thinkGly.get(i)
.const R_TGLY = th_gly_rec - extras
th_txt_rec:
.fill thinkTxt.size(), thinkTxt.get(i)
.const R_TTXT = th_txt_rec - extras
extras_end:
.errorif extras_end - extras > R_BITMAP, "the REU extras run into the bitmap's place"
// the newspaper's bitmap, packed (reu_init unpacks it to $e000 and stashes it)
.var newsPacked = rlePack(newsBitmap)
news_rle:   .fill newsPacked.size(), newsPacked.get(i)

// ---------------------------------------------------------------- thinking
// In a card shop the first three comic bubbles are Vinnie's thoughts (a
// white cloud, gfx_think.asm). do_rob calls THINK_STUB instead of
// new_bubble for them: it swaps this overlay into COPSTORE ($0400-$06ff,
// only read when the city comes back from a bitmap page) and back; the
// overlay's RAM image (its variables too) goes back into the REU each time.
// The glyphs borrow character codes that are not on the shown screen (the
// camera stands still during a robbery), their old shapes saved in the REU;
// at the 4th bubble the cloud goes and the characters come back, and the
// comic bubbles follow as in the standard edition. The game's random
// numbers stay the same (rng_next once a thought, as new_bubble).
.const TH_CODES = $0200             // MMBUF (free during a robbery): the borrowed codes,
.const TH_TXT = TH_CODES + TH_NB    // the text shown
.errorif TH_TXT + 28 > $0280, "MMBUF is too small for the thinking"
th_ov_src:
.pseudopc THINK_OV {
th_ov:
    lda bub_n
    cmp #3
    bcc th_think
    lda th_on                       // the 4th: the thinking is over
    cmp #1
    bne !+
    jsr th_clear                    // the cloud and the trail go,
    lda #$91                        // the charset comes back
    jsr th_cset
!:  lda #0
    sta th_on
    clc                             // (new_bubble as usual)
    bcc th_save
th_think:
    lda th_on
    beq th_first
    lsr                             // (2: not this time, no room: carry clear)
    bcc th_save
    jsr th_clear                    // the last thought goes
    jmp th_go
th_first:
    jsr clear_bubble
    jsr th_borrow
    bcc !+
    lda #2                          // too few free characters: no thinking
    sta th_on
    clc
    bcc th_save
!:  lda #1
    sta th_on
    lda vbl                         // one of the sets of thoughts
    and #TH_SETS - 1
    sta th_set
th_go:
    jsr rng_next                    // (as new_bubble)
    inc bub_n
    jsr th_draw
    sec
th_save:                            // the RAM image back into the REU
    php
    ldy #6
    jsr th_regset
    lda #$90
    jsr th_dma
    plp
    rts

// the cloud (bub_x/y/w are its) and the trail go
th_clear:
    jsr clear_bubble
    lda th_tx
    sta bub_x
    lda th_ty
    sta bub_y
    lda #2
    sta bub_w
    lda #1
    sta bub_on
    jmp clear_bubble

// TH_NB character codes that are not on the shown screen (carry clear), the
// shapes there saved in the REU and the glyphs put in; carry set: too few
th_borrow:
    lda #$90                        // the first page of the hidden screen (not
    jsr tb_hid                      // shown; the camera stands still) into the
    lda #0                          // REU: it is the table meanwhile (zp0)
    tay
!:  sta (zp0),y
    iny
    bne !-
    lda front_hi
    sta tb_s0 + 2
    clc
    adc #1
    sta tb_s1 + 2
    adc #1
    sta tb_s2 + 2
    adc #1
    sta tb_s3 + 2
    lda #1
    ldx #0
tb_scan:
tb_s0:
    ldy $c000,x
    sta (zp0),y
tb_s1:
    ldy $c100,x
    sta (zp0),y
tb_s2:
    ldy $c200,x
    sta (zp0),y
tb_s3:
    ldy $c300,x
    sta (zp0),y
    inx
    bne tb_scan
    ldx #0
    ldy #1                          // (not character 0)
!:  lda (zp0),y
    bne tb_next
    tya
    sta TH_CODES,x
    inx
    cpx #TH_NB
    beq tb_ok
tb_next:
    iny
    bne !-
    lda #$91                        // the page back
    jsr tb_hid
    sec
    rts
// a = REU command: the hidden screen's first page <-> R_HID (zp0 points at it)
tb_hid:
    pha
    lda #0
    sta zp0
    sta th_regs
    sta th_regs + 2
    sta th_regs + 4
    sta th_regs + 5
    lda #1
    sta th_regs + 6
    lda #>R_HID
    sta th_regs + 3
    lda front_hi
    eor #>(SCR_A ^ SCR_B)
    sta th_regs + 1
    sta zp0 + 1
    pla
    jmp th_dma
tb_ok:
    lda #$91                        // the page back
    jsr tb_hid
    lda #$90                        // the charset into the REU
    jsr th_cset
    lda #$91                        // the glyphs in
    ldx #<R_TGLY
    ldy #>R_TGLY
    jsr th_chars
    clc
    rts

// REU command a between the TH_NB borrowed characters (the charset under
// the I/O area) and REU address y/x on, 8 bytes each
th_chars:
    sta th_cmd
    stx th_regs + 2
    sty th_regs + 3
    lda #0
    sta th_regs + 4
    sta th_regs + 6
    lda #8
    sta th_regs + 5
    sta th_n
tc_loop:
    ldx th_n
    lda TH_CODES - 8,x
    ldy #>CHARSET / 8
    sty th_regs + 1
    asl
    rol th_regs + 1
    asl
    rol th_regs + 1
    asl
    rol th_regs + 1
    sta th_regs
    lda th_cmd
    jsr th_dma
    lda th_regs + 2
    clc
    adc #8
    sta th_regs + 2
    bcc !+
    inc th_regs + 3
!:  inc th_n
    lda th_n
    cmp #TH_NB + 8
    bne tc_loop
    rts

// a = REU command: the whole charset <-> R_CSAVE
th_cset:
    ldx #<CHARSET
    stx th_regs
    ldx #>CHARSET
    stx th_regs + 1
    ldx #<R_CSAVE
    stx th_regs + 2
    ldx #>R_CSAVE
    stx th_regs + 3
    ldx #0
    stx th_regs + 4
    stx th_regs + 5
    ldx #8
    stx th_regs + 6
    jmp th_dma
// th_regs = the 7 bytes of th_tabs up to y
th_regset:
    ldx #6
!:  lda th_tabs,y
    sta th_regs,x
    dey
    dex
    bpl !-
    rts
// REU command a ($90 stash, $91 fetch) with th_regs, the charset under the
// I/O area visible: the command waits for a write to $ff00 (bit 4 clear),
// done with the I/O area banked out
th_dma:
    php
    sei
    and #$ef
    tay
    ldx #6
!:  lda th_regs,x
    sta $df02,x
    dex
    bpl !-
    sty $df01
    lda #$34
    sta $01
    lda $ff00
    sta $ff00                       // (the transfer)
    lda #$35
    sta $01
    plp
    rts

// the thought (number th_set * 3 + bub_n - 1) over the door
th_draw:
    ldx target
    lda door_xl,x                   // the door's column on the screen
    sta t0
    lda door_xh,x
    jsr th_div8
    sbc disp_cx
    bpl !+
    lda #0
!:  cmp #39
    bcc !+
    lda #38
!:  sta th_tx                       // the trail starts there
    sec                             // the cloud: 16 wide, centred over it
    sbc #8
    bcs !+
    lda #0
!:  cmp #25
    bcc !+
    lda #24
!:  sta bub_x
    lda door_yl,x                   // ... and 9 rows above the door
    sta t0
    lda door_yh,x
    jsr th_div8
    sbc disp_cy
    sec
    sbc #9
    bcs !+
    lda #0
!:  cmp #19
    bcc !+
    lda #18
!:  sta bub_y
    clc
    adc #3
    sta th_ty                       // (the trail is in the 4 rows from there)
    lda #16
    sta bub_w
    lda #1                          // white
    sta bub_col
    sta bub_on
    // its text from the REU (32 bytes a thought)
    ldy #13
    jsr th_regset
    lda th_set
    asl
    adc th_set
    adc bub_n                       // (1-12: the table starts 32 bytes early)
    ldx #0
    stx th_n
    asl
    asl
    asl
    asl
    asl
    rol th_n
    adc th_regs + 2
    sta th_regs + 2
    lda th_n
    adc th_regs + 3
    sta th_regs + 3
    lda #$91
    jsr th_dma
    ldx #0                          // the top
    lda #0
    jsr th_edge
    ldx #0                          // the text
    lda #1
    jsr th_line
    ldx #14
    lda #2
    jsr th_line
    ldx #TH_BL - TH_TL              // the bottom
    lda #3
    jsr th_edge
    // the trail down to the door: a circle, a smaller one
    lda bub_x
    pha
    lda #1
    sta bub_w
    ldx th_tx
    inx
    stx bub_x
    lda TH_CODES + TH_MED
    sta tbuf
    lda #4
    jsr bubble_row
    dec bub_x
    lda TH_CODES + TH_SML
    sta tbuf
    lda #6
    jsr bubble_row
    pla
    sta bub_x
    lda #16
    sta bub_w
    rts
// a = (a t0) / 8 - nothing: the high byte in a, low in t0; returns the
// low byte of the result in a, carry set
th_div8:
    lsr
    ror t0
    lsr
    ror t0
    lsr
    ror t0
    lda t0
    sec
    rts
// a cloud edge into row a: x = 0 the top, TH_BL the bottom
th_edge:
    pha
    lda TH_CODES + TH_TL,x
    sta tbuf
    lda TH_CODES + TH_TR,x
    sta tbuf + 15
    ldy #13
!:  lda TH_CODES + TH_TB,x
    sta tbuf + 1,y
    lda TH_CODES + TH_TA,x
    sta tbuf,y
    dey
    dey
    bpl !-
    pla
    jmp bubble_row
// a line of text (TH_TXT from x) into row a
th_line:
    pha
    lda TH_CODES + TH_L
    sta tbuf
    lda TH_CODES + TH_R
    sta tbuf + 15
    ldy #0
!:  stx th_n
    lda TH_TXT,x
    tax
    lda TH_CODES,x
    sta tbuf + 1,y
    ldx th_n
    inx
    iny
    cpy #14
    bne !-
    pla
    jmp bubble_row

th_tabs:    .word THINK_OV, R_THINK     // + 6: the RAM image
            .byte 0
            .word $300
            .word TH_TXT, R_TTXT - 32   // + 13: a text
            .byte 0
            .word 28
th_regs:    .fill 7, 0
th_on:      .byte 0                 // 1 thinking, 2 not this robbery (no room)
th_set:     .byte 0
th_tx:      .byte 0
th_ty:      .byte 0
th_cmd:     .byte 0
th_n:       .byte 0
th_ov_end:
.errorif th_ov_end > THINK_OV + $300, "the thinking overlay is too long: " + toHexString(th_ov_end)
}
// THINK_STUB (copied after the bitmap by reu_init): in a card shop, for the
// first 4 bubbles, swap the overlay in, run it, swap it out. Carry set: it
// showed a thought (do_rob skips new_bubble).
ts_src:
.pseudopc THINK_STUB {
ts_main:
    lda target
    cmp #16
    bcc ts_no
    lda bub_n
    cmp #4
    bcs ts_no
    ldy #15                         // COPSTORE away
    jsr ts_dma
    ldy #7                          // the overlay in
    jsr ts_dma
    jsr th_ov
    php
    ldy #23                         // COPSTORE back
    jsr ts_dma
    plp
    rts
ts_no:
    clc
    rts
// REU DMA: the 7 registers ts_tab[y-7..y-1], command ts_tab[y]
ts_dma:
    php
    sei
    lda ts_tab,y
    pha
    dey
    ldx #6
!:  lda ts_tab,y
    sta $df02,x
    dey
    dex
    bpl !-
    pla
    sta $df01
    plp
    rts
ts_tab:     .word THINK_OV, R_THINK
            .byte 0
            .word $300
            .byte $91
            .word THINK_OV, R_SWAP
            .byte 0
            .word $300
            .byte $90
            .word THINK_OV, R_SWAP
            .byte 0
            .word $300
            .byte $91
ts_end:
}
.errorif ts_end > $fffa, "THINK_STUB runs into the vectors"
// page 1 (copied there by reu_init): fetch the REU code into screen B and
// run its badge (REU_TITLE) or newspaper (REU_NEWS) part; and REU_TUNE
p1_src:
.pseudopc REU_TITLE {
p1_title:
    lda #<(NEWS_OV + 3)
    .byte $2c                       // (bit: skips the next lda)
p1_news:
    lda #<NEWS_OV
    sta p1_jmp + 1
    php                             // (REU_TUNE in the IRQ uses the REU too)
    sei
    ldx #6
!:  lda p1_dma,x
    sta $df02,x
    dex
    bpl !-
    lda #$91
    sta $df01
    plp
p1_jmp:
    jmp NEWS_OV
// Called by music_play (in the IRQ at line 250) every frame: when there is
// a new job (target changed: after a robbery, TOO SLOW!, a new game), fetch
// one of the other two driving tunes (at random) over the tune block
// (TUNE_BLK in music.asm) and start it, unless the chase tune is playing
// (then the new one starts after the chase). The game's rng is not touched.
REU_TUNE:
    lda target
    cmp p1_last
    bne !+
    rts
!:  sta p1_last
    lda vbl                         // + 1 or + 2 (mod 3)
    and #1
    sec
    adc p1_cur
    cmp #3
    bcc !+
    sbc #3
!:  sta p1_cur
    tax
    lda p1_rlo,x
    sta p1_tdma + 2
    lda p1_rhi,x
    sta p1_tdma + 3
    ldx #6
!:  lda p1_tdma,x
    sta $df02,x
    dex
    bpl !-
    lda #$91
    sta $df01
    lda m_song
    bne !+
    jmp music_song                  // (song 0 from the top)
!:  rts
p1_dma:     .word NEWS_OV, R_NEWS_OV
            .byte 0
            .word R_SCREEN
p1_tdma:    .word TUNE_BLK, 0
            .byte 0
            .word TUNE_LEN
p1_rlo:     .byte <R_TUNE0, <R_TUNE1, <R_TUNE2
p1_rhi:     .byte >R_TUNE0, >R_TUNE1, >R_TUNE2
p1_last:    .byte $ff               // the target the tune was picked for
p1_cur:     .byte 0                 // the tune in the block
p1_end:
}
.errorif p1_news != REU_NEWS, "REU_NEWS must be p1_news"
.errorif p1_end - p1_title > 128, "the page 1 code is too long"
.print "Page 1 code: $0100-$" + toHexString(p1_end - 1)
// run once at start (before anything is unpacked over this): is there an
// REU? then the extras go into it
reu_init:
    lda #$a5                        // a byte there and back
    sta reu_tb
    lda #0
    sta $df0a
    ldx #6
!:  lda ri_test,x
    sta $df02,x
    dex
    bpl !-
    lda #$90                        // stash
    sta $df01
    lda #$5a
    sta reu_tb
    ldx #6
!:  lda ri_test,x
    sta $df02,x
    dex
    bpl !-
    lda #$91                        // fetch
    sta $df01
    lda reu_tb
    cmp #$a5
    bne ri_none
    lda #<news_rle                  // the newspaper's bitmap, unpacked
    sta zsrc
    lda #>news_rle
    sta zsrc + 1
    lda #<BITMAP
    sta zdst
    lda #>BITMAP
    sta zdst + 1
    jsr unpack
    ldy #27                         // the extras, the tune, the bitmap, the thinking
!:  ldx #6
!:  lda ri_all,y
    sta $df02,x
    dey
    dex
    bpl !-
    lda #$90
    sta $df01
    tya
    bpl !--
    ldx #p1_end - p1_title - 1     // the page 1 code
!:  lda p1_src,x
    sta REU_TITLE,x
    dex
    bpl !-
    ldx #ts_end - ts_main - 1      // the thinking's entry
!:  lda ts_src,x
    sta THINK_STUB,x
    dex
    bpl !-
    rts
ri_none:
    lda #$60                        // no REU: no badge, no newspaper, one tune,
    sta REU_TITLE                   // no thinking
    sta REU_NEWS
    sta REU_TUNE
    sta THINK_STUB + 1
    lda #$18                        // (clc: new_bubble as usual)
    sta THINK_STUB
    rts
reu_tb:     .byte 0
ri_test:    .word reu_tb, $fff0
            .byte 0
            .word 1
ri_all:     .word th_ov_src, R_THINK    // (the last block is stashed first)
            .byte 0
            .word th_ov_end - th_ov
            .word BITMAP, R_BITMAP
            .byte 0
            .word 8000
            .word TUNE_BLK, R_TUNE0
            .byte 0
            .word TUNE_LEN
            .word extras, 0
            .byte 0
            .word extras_end - extras
.errorif R_TUNE0 + TUNE_LEN > R_THINK, "Getaway Groove runs into the thinking overlay"
.errorif R_HID + $100 > $fff0, "the REU test byte is in the way"
.errorif * > $d000, "the REU extras must end below $d000: " + toHexString(*)
.print "REU extras: $a000-$" + toHexString(*)
#endif
