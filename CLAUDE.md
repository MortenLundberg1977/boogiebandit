# Boogie Bandit — project brief for Claude

Boogie Bandit is an original top-down getaway game for the Commodore 64 in
6502 assembly (KickAssembler), set in New York, 1977. The owner works in VS
Code on Windows (`C:\c64-starter\boogiebandit`, `KickAss.jar` in the parent
folder), builds with `build.bat`, tests in VICE and plays on a real PAL C64
from an SD card. Sister projects: `..\kramster`, `..\drivinggame` (Soul Drive).

Owner's wishes: original name, art and music (nothing from existing games or
cartoons), smooth 50 fps on a real PAL C64, no ROM font anywhere (all text uses
the game's own fonts in `gfx_lib.asm`), black tyre marks.

## Gameplay

Drive the red sedan through a scrolling 128 x 128 character city to the bank
the arrow (lower left) points at; a green marker bounces over its door. Fire
(when nearly stopped) gets out; walk into the door: a 6.7 second robbery with
comic bubbles (KAPOW!, BLAM!, ...), five per robbery, random word and colour.
The bandit comes out with a loot bag ($1,000-$4,700; 10 x the seconds left
on the job timer go to the score at once), the next bank is chosen (target + 3
of 16), one more wanted
star lights up (at most 3) and that many police cars come after him. Fire next
to the car gets back in. Lose every police car (they give up 2-3 screens
away): ESCAPED!, $500. Touched by one (car to car, or within 32 pixels on
foot): BUSTED!, a life gone, the stars reset.

The loot is only carried (`carry_l`/`carry_h`, BCD hundreds / ten thousands)
until it reaches the friend's house; BUSTED! loses all of it. The car outside
a robbery becomes the getaway car (`hot` = 1); a stolen car is clean (`hot` =
0). The friend's house is in the suburb (lot (0, 7), `FRIEND_LOT_X/Y` in
gfx_city.asm): a yellow roof (yellow on the city map) and a driveway down to
the street (characters of class `CL_SAFE` = 16). Stop in the driveway with
loot (`safe_check` in chase.asm, once each time in): during a chase "LOSE THE
COPS!", in the getaway car "HOT CAR!", else "SAFE! LEVEL UP!": the loot goes
to the score plus $1,000 x `level`, `level` + 1, the wanted stars go, the
police start gentle again (`jobs` = (level - 1) / 2, at most 6) and the job
timer is 2 s shorter a level (at least `JOB_MIN`). Several robberies per trip
are allowed (the police get tougher with each, as below). While loot is
carried and the car is not hot, the arrow, the bouncing marker and the ring
on the city map point to the friend's driveway (`goal_idx`; `door_xl/...`
entry `FRIEND` = 16), else to the next job.

The police get tougher with every bank robbed (`jobs`, at most 9, reset at
the friend's house):
speed 1.75 pixels a frame on the first chase, +0.19 per job, at most 2.7 (the
car does 3). From the 2nd robbery on a police car near the player (on screen,
32-120 pixels away) stops and the officer gets out (blue, slot 3 / sprite 2,
the cab there goes away while he is out), turns to the player and fires two
shots (8 directions, 3 pixels a frame, stopped by buildings; a hit is
BUSTED!), then gets back in; 4 seconds before anyone gets out again. From the
3rd robbery on there is a roadblock (slot 2, so at most 2 chasing cars): a
police car parked across the road 2-3 blocks ahead of where the car is going,
stretched with sprite expansion to cover the whole road; driving into it is
BUSTED!, the sidewalk just leaves room to squeeze by. Police cars speed up
gently, slow down for corners, stop for a U-turn, and keep going straight
while that still leads to the player (no zigzag).

Three paint garages (yellow PAINT sign, an open spray booth facing the street
below; small yellow marks on the city map): stop in the booth during a chase
and after 1 second of spraying the car has a new colour (once, no flashing;
at random from `paint_cols`, never the colour it has: `new_paint`), costs $300, and
every police car loses the trail (`NT_LOST`: they drive on at random and
leave), so ESCAPED! (+$500). The job timer starts at 60
seconds and gets 3 seconds shorter per job (at least 30); run out: TOO SLOW!,
a life gone, next bank.

Guards on foot: after every robbery (`guard_out`, end of `end_rob`) a guard
runs out of the door after the bandit, `NT_FOOT` in slot 3 (sprite 2, the cab
there goes; not while an officer is out, and no officer gets out while he
runs). Green at a bank, the purple owner at a card shop (24 slower). He comes
out with him and stands in the doorway behind him, facing him, for
`FOOT_DELAY` (2 s; he can not grab anyone then, the door sound when he starts),
then runs at `FOOT_SPEED` + 8 a job
(1/256 pixels a frame, at most `FOOT_MAX` = 0.91; the bandit walks 1),
straight at him on both axes with the walking collision (`box_blocked`); when
both ways are blocked he follows the wall for up to `FOOT_WALL` steps
(`foot_one`, `foot_wall`/`foot_axis`/`foot_slide`). A bandit on foot closer
than `FOOT_REACH` (10): BUSTED!. He gives up after 16 s (`n_cur` counts down
every 4 frames) or 256 pixels away, and goes with the police on BUSTED!. His
8 sprites (`guardSpr` in gfx_sprites.asm, cap, badge, arms out) live in the
program (`guard_spr`) and are copied to `$fb00` (sprites 236-243, `SP_GUARD`)
by `gen_shift_ba`.

Three lives (hearts in the HUD); then game over, name
entry if the score makes the top 5 (kept until the C64 is switched off), and
the title alternates between the picture and the table.

Targets are 8 banks and 8 card shops (`NBANKS` = 16, `cardLots` in
gfx_city.asm, targets 8-15: CARDS sign, a playing card, striped awning, loot
$200-$900; banks $1,000-$4,700). The first target is random (`vbl` xor `rng`
at game start), then target + 3 of 16. BUSTED! (`impound` in chase.asm): the
police take the car (`have_car` = 0, the car sprite goes) and the loot of the
last job (`loot`, taken off the score, the bag goes); the bandit goes on on
foot from where he was. Fire on foot next to a parked car (3 x 3 characters
around him, `try_steal`): he steals it. It comes off the map (`put_car`),
the car stands there facing north in the parked car's colour (`kind_col`:
cab yellow, white, black, black). During a chase police within 120 pixels
(`SEE_DIST`) saw it and keep chasing; otherwise all lose the trail
(`lose_cops`, as after a paint job) and ESCAPED! follows. Stolen cars are
kept in a list of 32 (`steal_col/row/kind`) and parked again at the next
game start (the oldest goes back at once when the list is full). Any old car
of his is left for good (it vanishes). Parked cars: at most one per block
along an avenue, on one side. The music runs at 7 frames a 16th
note; during a chase the chase tune "Red Light Runner" (E minor, 8 bars) plays at 6 (`m_song`,
`m_speed`; while driving only voice 3 is heard, since the siren and the
engine take voices 1 and 2, so voice 3 carries a riff: a bass line jumping
octaves into a melody, with the drums in between; on foot a lead joins on
voice 2; patterns that do not fit at MUSSTORE go into the program).
The title picture says "MADE IN 2026 BY
MORTEN" on the bottom sidewalk.

Two yellow cabs drive around near the player (new ones appear when they get
far away); they keep to the right of the road, the car bounces off them, and
a cab that is blocked honks and after a second turns around; driving away
from a cab you touch is always allowed (only moves towards it bounce). Cabs
honk on a nudge and now and then on their own. Parked cars along the curbs
and in the two parking lots are yellow cabs, white cars, black cars and black
ones with yellow stripes (`parkedCars` in gfx_city.asm, picked from the
position so the rest of the city stays the same; only the colours of the
city characters are possible). Flooring it from standstill
(burnout) and sliding at speed leave black tyre marks.

Keys: SPACE city map (fire or SPACE back), M music on/off, D raster time bar.
Sound: the tune on 3 voices; while driving voice 2 is the engine (pitch from
the speed), during a chase voice 1 is the siren; effects on voice 3 (pow,
crash, ching, door, two cab horns, gunshot, spray hiss, and a footstep every
8 frames while walking, only when no other effect is playing).

## Version

`version.asm` holds `VERSION` (semantic versioning: a new feature MINOR + 1,
a fix only PATCH + 1), drawn as "V1.4.0" in the top right of the title
picture (`gfx_intro.asm`). Bump it with every change merged into main and tag
that commit `v<version>`.

## Build and test

- `build.bat [pull [branch]] [run|send|nosend]` → `build\boogie.prg`, `build\boogiebandit.d64`
  (file `boogie`, lowercase: uppercase becomes shifted PETSCII). One file, loads
  at $0801, `LOAD"BOOGIE",8` + `RUN` on a real C64. Also
  `build\boogiebandit.t64` (tape image, written by `tools\make_t64.ps1`; the
  name inside is `BOOGIE` in capitals, as PETSCII).
- Every `build.bat` also sends `build\boogie.prg` to a Kung Fu Flash cartridge
  on USB, if one is found, with `..\tools\ef3utils\ef3usb.exe` (`EF3USB_EXE`),
  and the C64 starts it. The cartridge only takes it while its menu is on
  screen (a running game is not stopped): the send gives up after `KFF_WAIT`
  seconds (20) and the build still succeeds. `send` makes a missing cartridge
  or a failed send an error. **Claude builds with `build.bat nosend`** (test
  builds must not go to the owner's C64). The port is found by USB ID
  0483:5740 unless `KFF_PORT` is set (it was COM3).
- `powershell -ExecutionPolicy Bypass -File tools\vice.ps1 build\boogie.prg "wait 4; poke 1d 10; wait 0.3; poke 1d 00; wait 2; shot build\a.png; peek 17 1; quit"`
  drives VICE through the remote monitor. Commands: `wait`, `shot`, `poke`,
  `peek`, `mon`, `raw`, `quit`; `-Extra "-sounddev wav -soundarg build\x.wav"`
  records the sound. `tools\zoom.ps1 in.png out.png x y w h [scale]` enlarges
  part of a screenshot. Always look at the screenshots.
- Test hooks (zero page, check `build\boogie.sym` after changes):
  `joy_ovr` $1d (OR'ed into joystick 2: 1 up 2 down 4 left 8 right $10 fire),
  `key_ovr` $ba (keys: $20 SPACE, $10 M, $04 D; poke, then 00 again),
  `fps_val` $17 (frames shown in the last 50 raster frames, $32 = 50),
  `perf` $84 / `perf_max` $85 (main loop time in raster lines / 2 counted from
  the IRQ at line 250; 156 = a whole frame), `n_cross` $b8 / `n_hold` $b9
  (character crossings / the ones the scroll did not predict),
  `state` $21 (0 drive, 1 walk, 2 robbery, 3 message), `target` $4c,
  `score` $57 (BCD, lowest byte first), `lives` $91, `wanted` $92, `chase` $93,
  `job_time` $94 (BCD seconds), `n_type` $3a1 (5 slots: 1 police, 2 cab,
  3 officer, 4 police that lost the trail, 5 roadblock; then x low/high,
  y low/high, direction, 5 bytes each), `jobs` $d4 (poke 2 before a robbery
  for shooting and roadblocks), `officer` $d7, `bul_t` $da, `car_col` $e1,
  `have_car` $e8, `loot` $e9, `steal_pos` $f0, `m_speed` $f1, `m_song` $f6,
  `n_next`/`n_prev`/`n_rot` $3d3/$3d8/$3dd, `foot_col` $3e2 (`n_type` 6 = a guard on foot; `target`: 0-7 banks,
  8-15 card shops), `hot` $3e7, `carry_l`/`carry_h` $3e8/$3e9, `level` $3ea,
  `safe_in` $3eb, `sh_gline`/`lv_gline` $f7/$f8
  (the garage at lot (2,4): car x $0200, y $0244, heading 0, drive up into
  the booth; the friend's driveway: `poke 3e8 21; poke 3e7 00`, car x $002c,
  y $03c4 heading 0, wait 3 s, then `poke 1d 01` 0.6 s, release 0.3 s,
  `poke 1d 02` 0.2 s: it stops in the driveway),
  `car_xl`/`car_yl` $24/$27 (+1 high byte), `hdg`/`mang` $2a/$2b, `debug_bar` $1f.
  Teleport next to bank 0: `poke 24 00 01; poke 27 c4 00; poke 2a c0 c0`, then
  fire, `poke 1d 01` for 1.2 s walks into the door. Poke `wanted` to 2 during
  the robbery for a three-car chase.

## Files

| File | What |
|---|---|
| `boogie.asm` | main: memory map, init, raster IRQs, title, game loop, car physics, walking, robbery, scrolling, sprites, HUD, tables |
| `chase.asm` | police and cabs (road-grid driving), officers shooting, roadblocks, paint garages, arrests, escapes, job timer, lives, message bubbles, engine and siren |
| `screens.asm` | bitmap screens: text in the 4x7 font, title pages, high score table and name entry, the city map |
| `music.asm` | SID player (register shadow, patterns as text) + the tune "Getaway Groove" + sound effects on voice 3 |
| `gfx_lib.asm` | build-time helpers: random, 4x7 font, 3x5 HUD font, RLE packer |
| `gfx_city.asm` | build-time: multicolor charset, the city map, banks, paint garages (spray booth chars have class `CL_PAINT` = 8), comic bubble characters, map colours, skid-mark tables |
| `gfx_sprites.asm` | build-time: car (16 rotations), arrow dial (16), bandit (4 dirs x 2 steps, with/without bag), marker, HUD boxes, title text, police car (4), map dots |
| `gfx_intro.asm` | build-time: the title picture (multicolor bitmap; the green lady with the torch on the right, `ladyArt`, is drawn before the skyline so the buildings hide her feet) |
| `version.asm` | the version shown on the title picture |

Everything graphical is generated by KickAssembler script at build time; there
are no binary assets. The city is drawn from ASCII-art "stamps" (4 pixels per
character, `.` asphalt, `w` light grey, `b` black, `y` yellow) that are cut
into characters and de-duplicated.

## Memory map

- `$0200-$02ff` skid-mark ring buffer (128 map addresses), `$0300-$03ff` arrays
  (music, sprite shadows, police/cab slots).
- `$0400-$06ff` the 12 extra police car sprites (copied to `$f800` by
  `gen_shift_ba`, i.e. every time the city comes back from a bitmap screen),
  `$0700-$07ff` the chase tune (both copied there from the start-up data).
- `$0801-$7cxx` program + data (must stay below $8000; ~0.9 KB free). After it
  the packed charset and sprites (only needed at start-up, may reach past
  $8000: they are unpacked before the map is).
- `$8000-$bfff` the city map, 128 x 128 characters, unpacked at start-up.
- VIC bank 3: `$c000`/`$c400` screens A/B, `$c800` sprites 32-63 (HUD, bandit,
  marker, title text, police, map dots; HUD digits written at run time),
  `$d000` charset and `$d800` sprites 96-127 (car, arrow) under the I/O area,
  `$f800` police sprites 224-235 (after the B->A shift, which ends at $f771),
  `$fb00` the guard sprites 236-243,
  `$e000` bitmap for the title pages, game over and the city map (colours in
  screen A).
- The unrolled screen shift routines are generated at run time: A→B over the
  packed map (`map_rle`, free after unpacking; must stay ≥ 6001 bytes, an
  assert checks this), and the 2,554 bytes of tables after it (`sin_tab` to
  `steal_kind`: `tail_src` in the start-up data, assembled for `TAIL` =
  `map_rle` + 6001, parked at $e000 during start-up and copied there once
  the map is unpacked; `TAIL_PAGES`; about 120 bytes to spare before the title (it depends on the packed map;
  the comic bubble words were moved back into the program for that), asserts check it: new tables go in the program), B→A at `$e000`, generated again every time the city
  comes back from a bitmap screen (`gen_shift_ba`).
- KERNAL and BASIC are banked out (`$01=$35`), IRQ/NMI vectors at `$fffe/$fffa`.
- Zero page `$02-$bx` is the game's (allocated with `zalloc`).

## How a frame works

The raster IRQ at line 250 applies the frame the main loop prepared
(`frame_ready`): screen buffer (`$d018`), fine scroll, sprites 4-6 and copies
of the shadows for 0-3 and 7. It puts the HUD row at the top (sprites 0-3 and
7: fps, timer, hearts/stars, score), counts shown frames for the fps meter,
plays music and effects and sets a second IRQ at line 80 (`irq_split`), which
turns sprites 0-3 and 7 into police cars, cabs and the arrow (and sets their
x/y expansion, for the roadblock). So those can't be shown above line 88
(they are hidden there). Sprite 6 is the bank marker, or a police bullet
(`SP_DOT`) while one flies; the car's colour comes from `sh_col + 5`.

The main loop waits for the frame to be taken, then: input, state
(drive/walk/robbery/message), police and cabs, the job timer, camera (eases
towards the car with a look-ahead), `scroll_prepare`, sprites, HUD, engine and
siren. When the camera crosses a character boundary it shifts the shown screen
into the hidden one by one character in any of 8 directions (generated code,
~8,250 cycles in all) and draws the new edge from the map. The shift is done
in two halves on two frames: `predict` guesses from the camera's movement
that the next frame will cross and shifts the first half early; if a crossing
comes unpredicted, the camera waits one frame at the boundary while the first
half is shifted (`n_hold`). Skid marks drawn meanwhile go into both buffers.
Heavy frames (`scrolled`) skip the HUD redraw and the engine sound update.

Colour RAM is one value for the whole city (multicolor, yellow), so it never
has to scroll; the palette is `$d021` grey asphalt, `$d022` light grey,
`$d023` black (roofs, tyre marks), colour RAM yellow. The suburb (map rows
`SUB_ROW` = 107 to 127) has green grass instead of the light grey: a third
raster IRQ (`irq_green`, chained after `irq_split` when the suburb is on
screen) sets `$d022` to `LAWN_COL` on the last line of row 106 (no "w" pixels
there), and the IRQ at line 250 sets it grey again. The line is
`GREEN_BASE` (55) + 107 * 8 - camera y, prepared in `scroll_regs`
(`sh_gline`, 0 = not on screen) and taken with the frame (`lv_gline`); at
the very bottom of the map (line < 84) `irq_split` sets it at once. City
characters in the suburb rows lose their "w" pixels at build time
(`subVariant` in gfx_city.asm: road markings and the card shop's white turn
yellow, the rest grey); suburb art (`subStamp`: houses with hipped roofs,
trees, hedges, the friend's house and driveway) and lawns (`WALK`) keep it.
White parked cars are black there. Only 8 of 256 characters are left. Comic bubbles are drawn
into the shown screen with their own colour RAM while the camera stands still,
and the city is restored from the map afterwards.

Police and cabs drive on the centre lines of the road grid (avenue centres
x = 128 + 256 k, street centres y = 68 + 128 j; avenues are 6 characters
wide, streets 5 rows high: `AVX`, `STY`, `SH` in gfx_city.asm; change the
node checks in chase.asm with them) and decide at the crossings:
cabs at random, police towards the player (longer distance first) and they
turn around when the player is behind them.
Turning: police cars and cabs choose their way 16 pixels before a crossing
(`TURN_R`, `npc_plan`; they slow down there) and are shown on a quarter
circle from 16 pixels before to 16 after it, turning in 16 steps
(`npc_view`: `arc_a`/`arc_b`/`hstep`; cabs keep their lane with `lane16x/y`).
A U-turn turns on the spot in 8 steps (`n_rot`). Only the picture curves:
the real position (for collisions) stays on the centre lines, at most about
5 pixels away. Police use 16 sprites (4 at $c800, 12 at $f800: `cop_ptr`),
cabs the getaway car's 16.

Measured worst case (3 police cars, 2 cabs, skid marks, hard turning):
`perf_max` ≈ $8a = 138 of 156; plain driving ≈ $6b; 2 police cars, an
officer shooting and a roadblock ≈ $83.

## Conventions

- Work on a branch, test in VICE (screenshots), merge into `main` and push.
  Commit as `Morten Lundberg` with the Claude co-author line.
- Keep 50 fps: check `fps_val` and `perf_max` after changing the main loop.

## Ideas on the list

More banks and a second district; a minimap in the HUD
(the full map is on SPACE); saving the high scores to disk. A park or river
needs green/blue like the suburb: only as a horizontal band (a raster split
like `irq_green`), since colour RAM is one value for the whole city.
