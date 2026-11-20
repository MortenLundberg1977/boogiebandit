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

The hero is Vinnie "Boogie" Marchetti (named on the high score page:
`STARRING VINNIE "BOOGIE" MARCHETTI`; the font has a `"` glyph, `@"..."` strings
in KickAssembler for it). Drive the red sedan through a scrolling 256 x 256 character city (built from blocks, see "The city") to the bank
the arrow (lower left) points at; a green marker bounces over its door. Fire
(when nearly stopped) gets out; walk into the door: a robbery (3 seconds in a bank, `BANK_FRAMES`; 4 in a card shop, `ROB_FRAMES`) with
comic bubbles (KAPOW!, BLAM!, ...), one every 0.6 s (`BUBBLE_FRAMES`), random word and colour.
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
0). The friend's house is in the suburb (block (1, 15) of the grid in
gfx_city.asm): a yellow roof (yellow on the city map) and a driveway down to
the street (characters of class `CL_SAFE` = 16). Stop in the driveway with
loot, or walk onto it (`safe_check` in chase.asm, run while driving and
walking, `gl_safe` in the main loop; `t5` not 0 on foot: the character under
Vinnie, no need to stop, and the getaway car does not matter; once each time
in): during a chase "LOSE THE
COPS!", in the getaway car "HOT CAR!", else first the friend's greeting, then
"SAFE! LEVEL UP!". The greeting (`greet` in chase.asm) is a white bubble over
his house, "AYY VINNIE! / HOW YOU DOIN'?", in a small blocky font with a grey
drop shadow (3 x 6 letters, `gfont` in gfx_city.asm, data `GREET_GLY`): for
the 2 seconds it is shown its 15 characters borrow city characters
`GREET_CH`.. that never appear in the suburb (found by the city builder;
`chars_greet` saves them in $0200, `chars_back` puts them back, both with
I/O banked out). The bubble is a blank word (`W_GREET`) with the two lines
written over its inside. Then the loot goes
to the score plus $1,000 x `level`, `level` + 1, the wanted stars go, the
police start gentle again (`jobs` = (level - 1) / 2, at most 6) and the job
timer is 2 s shorter a level (at least `JOB_MIN`). Several robberies per trip
are allowed (the police get tougher with each, as below).

The arrow (lower left) and the bouncing marker point to one of three goals
(`arrow_mode`, key A cycles it; the arrow's colour shows which, `arrow_cols`):
0 the next job (yellow), 1 the friend's driveway (light green, `FRIEND` =
16 in `door_xl/...`), 2 the nearest paint garage (light red, entries
`GARAGE0` = 17-19, nearest by |dx| + |dy|). `goal_idx` in chase.asm picks
the entry; the ring on the city map shows the same goal. It turns to the
friend's house by itself when the car becomes clean with loot on board
(stolen or painted, `clean_car`) and back to the next job after a delivery
and at game start.

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

Six paint garages (yellow PAINT sign, an open spray booth facing the street
below; small yellow marks on the city map): stop in the booth (any time, not
only in a chase) and after 1 second of spraying the car has a new colour
(once per visit: `paint_lock` until it leaves the booth; at random from
`paint_cols`, never the colour it has: `new_paint`), costs $300 (from the
carried loot when there is that much, else from the score) and is not
the getaway car any more (`clean_car`: `hot` = 0, so it may deliver at the
friend's house; with loot on board the arrow turns to the friend's house).
During a chase every police car loses the trail (`NT_LOST`: they drive on at
random and leave), so ESCAPED! (+$500). The job timer starts at 60
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
program packed (`guard_rle`) and are unpacked to `$fb00` (sprites 236-243, `SP_GUARD`)
by `gen_shift_ba`.

Three lives (hearts in the HUD); then game over, name
entry if the score makes the top 5 (kept until the C64 is switched off), and
the title alternates between the picture and the table. On the table page
five dancers (sprites 3-7, x- and y-expanded: the bandit, the guard, the
officer, the shop owner and a cab driver) dance in a line under it
(`dance_setup`/`dance_frame`/`dance_off` in boogie.asm, 4 frames `danceSpr`
in gfx_sprites.asm: arms up, point right, hands on hips, point left; a move
every 16 frames, neighbours mirrored, a bounce). The frames travel with the
city data to `DANCE_SRC` ($b800) and are copied to `DANCE_SPR` = $c400
(screen B, unused on the title pages) for the page; `$d025` is dark grey
there (black does not show on the black page), PRESS FIRE 10 lines lower.

Targets are 16 banks and 16 card shops (`NBANKS` = 32, placed by the city
builder in gfx_city.asm, 3 of each in the suburb; targets 16-31 are card
shops: CARDS sign, a playing card, striped awning, loot $200-$900; banks
$1,000-$4,700). The first target is random (`vbl` xor `rng` at game start),
then target + 3 of 32. BUSTED! (`impound` in chase.asm): the
police take the car (`have_car` = 0, the car sprite goes) and all the loot
carried; the bandit goes on on
foot from where he was. Fire on foot next to a parked car (3 x 3 characters
around him, `try_steal`): he steals it. It comes off the map (`put_car`
with `map_wr`: its block gets a private copy, see "The city"),
the car stands there facing north in the parked car's colour (`kind_col`:
cab: its block row's colour, white, black, black, grey 15). During a chase police within 120 pixels
(`SEE_DIST`) saw it and keep chasing; otherwise all lose the trail
(`lose_cops`, as after a paint job) and ESCAPED! follows. Stolen cars are
back at the next game start (the grid is reset), or earlier when their
private copy is needed for another theft (4 copies). Any old car
of his is left for good (it vanishes). Parked cars: on some blocks' avenues
and in the parking lots. The music runs at 7 frames a 16th
note; during a chase the chase tune "Red Light Runner" (E minor, 8 bars) plays at 6 (`m_song`,
`m_speed`; while driving only voice 3 is heard, since the siren and the
engine take voices 1 and 2, so voice 3 carries a riff: a bass line jumping
octaves into a melody, with the drums in between; on foot a lead joins on
voice 2; patterns that do not fit at MUSSTORE go into the program).
The title picture says "MADE IN 2026 BY
MORTEN" on the bottom sidewalk.

Two cabs drive around near the player (slot 4 a yellow cab, slot 3 =
`BUS_SLOT` the city bus, see below) (new ones appear when they get
far away); they keep to the right of the road, the car bounces off them, and
a cab that is blocked honks and after a second turns around; driving away
from a cab you touch is always allowed (only moves towards it bounce). Cabs
honk on a nudge and now and then on their own. Hitting a cab at `THROW_SPEED`
($0200, 2/3 of top speed) or faster throws Vinnie out (`throw_out` in chase.asm):
the car stops dead, he flies on in its direction at 1.5 x its speed, slowing
by 1/16 a frame (`fv`, `fax`/`fay`), tumbling (a quarter turn every 4 frames)
for `FLY_FRAMES` (32: about 52 pixels, three car lengths) or until a wall
stops him (`fly_step`, run by `do_walk` while `fly` is not 0); then he is on
foot and can get back in. Running head-on into a parked car that fast
(`dd_bounce` looks 4 frames ahead with `park_find`) throws him too: in flight
he passes over parked cars (`fly_over`: a parked car or open ground 3 pixels
ahead lets him through, a building stops him) and does not land on one
(`fs_slow` keeps him flying, without slowing, while his box is blocked).
Parked cars along the curbs
and in the parking lots are cabs (in the colour of their block row), white,
grey and black cars and black
ones with coloured stripes (`parkedCars` in gfx_city.asm, picked from the
position so the rest of the city stays the same; only the colours of the
city characters are possible). Flooring it from standstill
(burnout) and sliding at speed leave black tyre marks.

The city bus (2.11.0): the cab in slot 3 (`BUS_SLOT`; `spawn_cab` makes it
the bus, also when the slot comes back after an officer or a guard) drives
with the cab code at `BUS_SPEED` (1.1), shown as a long white bus with blue
stripes (`busArt` in gfx_sprites.asm, `BUS_COL`) in 4 directions (`bus_d`,
from the view heading, in `place_npcs`), stretched with sprite expansion (y
going north/south, x east/west; centred with `t4`/`t5` like the roadblock).
`npc_touch` gives it a 27-pixel box along its way. Bus stops: a sign
(`BUSSTOP`, the city's last character, its plate in the band colour) on the
sidewalk on both sides of every avenue at block row `BUS_ROW` (5) in every
city design (where the sidewalk is free; not in the suburb). The bus stops
when its centre is at y mod 128 = `BUS_Y` on an avenue (`ns_node` in
`npc_step`, x low = $80), north of the suburb, for `BUS_WAIT` (2 s, `bus_t`,
counted down in `no_move`). Test: slot 3's `n_xl`/`n_xh`/`n_yl`/`n_yh`/`n_dir`
are $3a9/$3ae/$3b3/$3b8/$3bd (check `build\boogie.sym`); poke $3a5 (slot 4's
`n_type`) 0 to take the yellow cab away. Pokes right after the game starts
can be lost (wait 4 s); pokes into the slots need the emulator stopped
between them: `raw > 3a9 80; raw > 3ae 02; ...; raw x` (vice.ps1's `poke`
lets the game run between commands).

Hijacking the bus (2.12.0): on foot, fire next to the bus while it stands
at a stop (`bus_t` not 0; within 18 across, 27 along it): `try_bus` (chase.asm,
tried before `try_steal`) puts his vehicle on the bus's centre line (its lane
may hold parked cars), facing its way, `is_bus` = 1, `car_col` = `BUS_COL`,
and goes on through `ts_take` (the end of `try_steal`: not the getaway car,
`steal_seen`); `spawn_cab` starts the next bus. His bus is drawn with the bus
sprites (direction from `car_frame`, expanded, in `place_sprites`), has the
car's box and physics with a top speed of `BUS_MAX` (2; `max_spd` in
`dd_acc`); `is_bus` is 0 again with any other car and at a new game. While
the bus waits at a stop and something touches it, it just waits (no horn,
no turning around; `nc_wait`).

Walking into vehicles (2.12.0): `man_try_x`/`man_try_y` use `man_box`:
`box_blocked`, then `veh_test` (carry: `tgt` is inside a vehicle: police
cars, the roadblock, cabs, the bus via `npc_delta`, 13 along / 10 across,
the bus and the roadblock 25 along; his own car or bus from `car_frame`). A
step is blocked only if it goes into a vehicle he is not already in (so he
can always get out of one; the crash flight starts inside his car).
`man_box` keeps `t3` (`npc_delta` uses it).

Keys: SPACE city map (fire or SPACE back), M music on/off, D raster time bar,
A what the arrow points to.

Walls: the car moves x and y separately against a square box (`bhw` 6). If
only one way is blocked and it is not the way the car mainly goes, it
scrapes along (speed - speed / 32 a frame); head on (or both blocked) it
bounces back at a quarter of its speed (`dd_bumped`).
Sound: the tune on 3 voices; while driving voice 2 is the engine (2.12.0,
`sound_frame`: a pulse wave; standing, a low lumpy idle, a chug every 8
frames from `idle_f`/`idle_pw`; moving, four gears of $c4 of speed each:
f = $0480 + 8 x the speed in the gear + $100 x the gear, so the revs climb
and drop at each shift; a burnout revs high), during a chase voice 1 is the siren; effects on voice 3 (pow,
crash, ching, door, two cab horns, gunshot, spray hiss, and a footstep every
8 frames while walking, only when no other effect is playing).

## Version

`version.asm` holds `VERSION` (semantic versioning: a new feature MINOR + 1,
a fix only PATCH + 1), drawn as "V2.1.0" in the top right of the title
picture (`gfx_intro.asm`). Bump it with every change merged into main and tag
that commit `v<version>` (tools/release.ps1 does it and publishes the release).

## The REU edition

Every build makes two programs from the same source: `build\boogie.prg`
(standard) and `build\boogie-reu.prg` (KickAssembler `-define REU`; code
inside `#if REU`). Game mechanics must stay identical: the REU edition only
adds presentation. Both are on the disk image (`boogie`, `boogie reu`); the
release has both .prg files. The REU edition's extras are assembled at $a000
(after the start-up data; a LOAD may fill RAM up to $cfff, never $d000, the
I/O area): at start (`start`, before anything is unpacked over them)
`reu_init` checks for an REU (a byte stashed and fetched back) and stashes
$a000-`extras_end` into REU address 0, and copies small entry points into
page 1 under the stack (`p1_src` -> `REU_TITLE` = $0100, `REU_NEWS` = $0103:
fetch the REU code into $c400 and jump to its badge or newspaper part;
`REU_TUNE`); with no REU all become an `rts`, so the program plays as the
standard one. The program itself only has five `jsr`s (start,
`show_picture`, `bust`, `music_play`, `do_rob`). The standard `boogie.prg` stays byte
for byte the same when REU code changes (compare the files).
Now in the REU (the load image from $a000 goes to REU 0; the `R_*` consts at
the top of boogie.asm):
- 0: the newspaper code (`news_ov`, assembled for `NEWS_OV` = $c400, screen B,
  free while a bitmap page is shown); the newspaper page: screen and colour
  RAM at `R_SCREEN`/`R_COLOUR` ($0400/$0800, 1024 each), the bitmap at
  `R_BITMAP` ($8000; packed in the program as `news_rle`, unpacked to $e000
  by `reu_init` and stashed from there); `gfx_news.asm` paints it at build time:
  THE DAILY BOOGIE, BUSTED!, a police lineup photo of Vinnie with his hands
  up next to an officer, columns of grey "text", EXTRA! in red; its own random
  numbers, so the city stays the same).
- The title picture gets a yellow-on-black "REU" badge in the top left
  (`show_picture` calls `REU_TITLE`: `nv_badge` fetches 40 bitmap bytes and 5
  screen and colour bytes, `R_BADGE`), only when an REU was found: it shows
  that the REU works.
- `bust` calls `REU_NEWS` (chase.asm): fetch the code to $c400 and run it: it
  fetches the page into $e000/$c000/$d800 (REU DMA; colour RAM is written
  through the I/O area), shows it on white paper until fire or SPACE
  (`key_map` is cleared, so SPACE does not open the city map too), and
  goes back to the streets through `sm_exit` (as from the city map). Then
  BUSTED! as usual.
- Three driving tunes (2.9.0): "Getaway Groove", "Hot Asphalt" (D minor) and
  "Midnight Meter" (G minor; `xord*`/`yord*` and patterns `x*`/`y*` in
  music.asm, REU build only). In the REU build the driving tune is one block
  in the program, `TUNE_BLK` (`TUNE_LEN` = 712 bytes: `ord_lo`/`ord_hi`,
  `pat_lo`/`pat_hi`, then the tune's order lists and patterns; built by
  `tuneSlots`/`tuneBlock`). A tune may use at most 21 patterns (slots) and
  no more bytes than "Getaway Groove" (build errors say so); patterns shared
  with it keep their numbers, and "R" is first in the block, at the same
  address in every tune, since the chase tune's voice 1 plays it. The chase
  pointers are the same in all blocks. REU: `R_TUNE1` in the gap after the
  newspaper code, `R_TUNE2` after the badge, `R_TUNE0` stashed from the
  program by `reu_init`. `music_play` calls `REU_TUNE` (page 1, in the IRQ)
  every frame: when `target` changed (a robbery, TOO SLOW!, a new game; once
  on the title too) it fetches one of the other two tunes at random (`vbl`
  bit 0, not the game's `rng`: `p1_cur` + 1 or + 2) over the block and
  restarts song 0, unless the chase tune plays (it then starts after the
  chase). Since the IRQ uses the REU, the other REU code does its DMA with
  `sei` (`p1_news`, `nv_get`). Page 1 code: $0100-$0174 (the stack was
  measured never to go below $01c0). Test: `p1_last`/`p1_cur` = $0173/$0174,
  `m_note` $30f (3 voices), poke `target` $4c for a new job.
- Card shop thoughts (2.10.0, `gfx_think.asm`): the first three bubbles of a
  card shop robbery (`bub_n` 0-2) are Vinnie's thoughts instead: a white cloud
  (16 x 4 characters, scalloped edges) 9 rows over the door with two lines in
  a 3 x 6 font with a drop shadow, and two circles trailing down to the door;
  4 sets of 3 thoughts (`thTexts`, picked by `vbl`; `^ < >` are spade, heart,
  diamond). `do_rob` calls `THINK_STUB` ($ff40, after the bitmap, up to the
  vectors; copied by `reu_init`, `clc`/`rts` without an REU) before
  `new_bubble`; carry set: a thought was shown, no comic bubble. The stub (for
  `target` >= 16 and `bub_n` < 4) swaps COPSTORE ($0400-$06ff) into `R_SWAP`,
  fetches the overlay (`th_ov`, assembled for `THINK_OV` = $0400, its RAM
  image with its variables at `R_THINK`) and runs it; the overlay stashes its
  image back, the stub fetches COPSTORE back. First thought: the overlay
  saves the hidden screen's first page (`R_HID`) and uses it as a table of
  the character codes on the shown screen (the camera stands still in a
  robbery), takes the first `TH_NB` (46) codes not on it (`TH_CODES` in MMBUF
  $0200, the text `TH_TXT` after them), stashes the whole charset to
  `R_CSAVE` and fetches the glyphs (`R_TGLY`) into those codes. DMA to the
  charset under the I/O area: the command is written with bit 4 clear and
  started by a write to $ff00 with `$01` = $34 (`th_dma`). At `bub_n` 3 the
  cloud and trail are cleared (`clear_bubble`, the trail as a 2-wide bubble at
  `th_ty`) and the charset comes back; then the comic bubbles as usual.
  `rng_next` is called once per thought, as `new_bubble` does, so the game's
  random numbers stay the same. The first thought costs about two frames
  (the screen scan); fps drops to 48 for that second.
- Program space is as tight as in the standard edition (the REU code in the
  program is a few bytes: put new extras into the REU part, fetched into
  screen B or the bitmap area when they are used).
- On the owner's Kung Fu Flash 2 the REU (1 MB, switched on in its settings, F5)
  is only active for programs started from the SD card with RETURN (or a
  mounted disk image), not for programs sent over USB: `build.bat reu` /
  `sendreu` builds run there as the standard edition (no badge). Confirmed
  2026-11-19: the badge shows when `boogie-reu.prg` is started from the SD card.
- Test: `tools\vice.ps1 build\boogie-reu.prg "..." -Extra "-reu -reusize 512"`
  (without `-reu` it must play as the standard edition). A real LOAD of the
  50 KB file: a d64 with only `boogie reu` and `-Extra "-drive8truedrive -reu
  -reusize 512"`.

## Build and test

- `build.bat [pull [branch]] [run|send|nosend|reu|sendreu]` (`reu`/`sendreu`:
  send the REU edition instead) → `build\boogie.prg`, `build\boogie-reu.prg`, `build\boogiebandit.d64`
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
  `key_ovr` $ba (keys: $20 SPACE, $10 M, $04 D, $02 A; poke, then 00 again),
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
  `n_next`/`n_prev`/`n_rot` $3d3/$3d8/$3dd, `foot_col` $3e2 (`n_type` 6 = a guard on foot; `target`: 0-15 banks,
  16-31 card shops), `hot` $3e7, `carry_l`/`carry_h` $3e8/$3e9, `level` $3ea,
  `safe_in` $3eb, `paint_lock` $3ec, `arrow_mode` $3ed, `priv_gi` $3ee (4),
  `sh_gline`/`lv_gline` $f7/$f8 (1: the suburb fills the screen)
  (check addresses in `build\boogie.sym` after changes; the door table
  `door_xl/xh/yl/yh` holds every target: 0-31 jobs, 32 the friend, 33-38 the
  paint garages). Places in the city as built now (they move when the city
  builder's random calls change; the build prints "A parked car" for theft
  tests): bank 0's door x $0300, y $0126 (`poke 4c 00` makes it the job; car `poke 24 00 03; poke 27 56 01;
  poke 2a c0 c0`, fire, `poke 1d 01` 1.2 s walks in); paint garage 0's
  booth: car x $0400, y $051c; the friend's driveway: `poke 3e8 21; poke 3e7
  00`, car x $00c4, y $07c4 heading 0, wait 3 s, `poke 1d 01` 0.6 s, release
  0.3 s, `poke 1d 02` 0.2 s: it stops in the driveway.
  `car_xl`/`car_yl` $24/$27 (+1 high byte), `hdg`/`mang` $2a/$2b, `debug_bar` $1f.
  Poke `wanted` to 2 during the robbery for a three-car chase.

## Files

| File | What |
|---|---|
| `boogie.asm` | main: memory map, init, raster IRQs, title, game loop, car physics, walking, robbery, scrolling, sprites, HUD, tables |
| `chase.asm` | police and cabs (road-grid driving), officers shooting, roadblocks, paint garages, arrests, escapes, job timer, lives, message bubbles, engine and siren |
| `screens.asm` | bitmap screens: text in the 4x7 font, title pages, high score table and name entry, the city map |
| `music.asm` | SID player (register shadow, patterns as text) + the tune "Getaway Groove" + sound effects on voice 3 |
| `gfx_lib.asm` | build-time helpers: random, 4x7 font, 3x5 HUD font, RLE packer |
| `gfx_city.asm` | build-time: multicolor charset, the city blocks and their grid, banks, paint garages (spray booth chars have class `CL_PAINT` = 8), comic bubble characters, map colours, skid-mark tables |
| `gfx_sprites.asm` | build-time: car (24 of its 32 headings), arrow dial (8 of 16), bandit (4 dirs x 2 steps, with/without bag), marker, HUD boxes, title text, police car (4), map dots |
| `gfx_intro.asm` | build-time: the title picture (multicolor bitmap; the green lady with the torch on the right, `ladyArt`, is drawn before the skyline so the buildings hide her feet) |
| `version.asm` | the version shown on the title picture |

Everything graphical is generated by KickAssembler script at build time; there
are no binary assets. The city is drawn from ASCII-art "stamps" (4 pixels per
character, `.` asphalt, `w` light grey, `b` black, `y` colour RAM) that are cut
into characters and de-duplicated.

## Memory map

- `$0200-$027f` the city map screen's row buffer (`MMBUF`), `$0280-$02ff` working
  bytes (`b2alloc`: map_at, draw_row/col, try_steal), `$0300-$03ff` arrays
  (music, sprite shadows, police/cab slots).
- `$0400-$06ff` the 12 extra police car sprites (copied to `$f800` by
  `gen_shift_ba`, i.e. every time the city comes back from a bitmap screen),
  `$0700-$07ff` the chase tune (both copied there from the start-up data).
- `$0801-$7fxx` program + data (must stay below $8000; about 33 bytes free since 2.13.0, 14 fewer in the REU edition: check "Program ends" in the build output; about 15 bytes of the `.align 64` padding before `wall_row` are left for small tables or routines, e.g. `last_life`, `abs_speed`; big tables only used once the game runs belong in the tail, see below). After it
  the packed charset and sprites (only needed at start-up, may reach past
  $8000: they are unpacked before the map is).
- `$8000-$bfff` the city (see "The city"): `BLOCKS` the 23 block designs
  (512 bytes each, unpacked at start-up), `PRIV` 4 private copies, `GRID`
  (9 x 17), the `map_at` tables `MT_CB`/`MT_CY`/`MT_RG`/`MT_RH`/`MT_RL`
  (256 bytes each, packed with the blocks), then the dancers (`DANCE_SRC`), `GRID_ORIG`, `MM_CODE` (the city map's character codes), the comic bubble glyphs (`WORD_GLYPHS`, `GL_TL`-`GL_BR`) and the greeting font (`GREET_GLY`): full up to $bff9.
- VIC bank 3: `$c000`/`$c400` screens A/B, `$c800` sprites 32-63 (HUD, bandit,
  marker, title text, police, map dots; HUD digits written at run time),
  `$d000` charset and `$d800` sprites 96-127 (car 96-119, arrow 120-127) under the I/O area,
  `$f780` the car's turned-around headings (`CARMIR` 222/223, after the B->A shift, which ends at $f771),
  `$f800` police sprites 224-235,
  `$fb00` the guard sprites 236-243 and the bus 244-247 (`SP_BUS`, N E S W, to `$fdff`; one packed block `guard_rle` in the tail, unpacked by `gen_shift_ba`), `$fe00` `REVT` and `$ff00` the arrow's turned-around picture (`ARRMIR` 252; both re-made after the bitmap pages, see "How a frame works"), `$ff40-$fff9` the REU edition's `THINK_STUB`,
  `$e000` bitmap for the title pages, game over and the city map (colours in
  screen A).
- The unrolled screen shift routines are generated at run time: A→B over the
  packed city blocks (`map_rle`, `MAP_AREA` = at least 6001 bytes + `TAIL_SIZE`,
  only needed at start-up), and after it the 1,857 bytes of (`TAIL_SIZE`, exact: no page padding since 2.13.0; it holds code too, e.g. `car_spr`, `mir_late`; parked cars are found by searching `park_chars` with `park_find`, no 256-byte table; `mul_speed` multiplies by shift and add, no square tables)
  tables (`sin_tab` to `kind_col`, `guard_rle` among them: `tail_src` in the start-up data,
  assembled for `TAIL` = `map_rle` + 6001, parked at $e000 during start-up
  and copied there once the blocks are unpacked; set `TAIL_SIZE` to what the
  assert says); B→A at `$e000`, generated again every time the city comes back from a
  bitmap screen (`gen_shift_ba`).
- KERNAL and BASIC are banked out (`$01=$35`), IRQ/NMI vectors at `$fffe/$fffa`.
- Zero page `$02-$bx` is the game's (allocated with `zalloc`).

## The city

The city is 256 x 256 characters (2,048 x 2,048 pixels), built from blocks
of 32 x 16 characters (gfx_city.asm, "the city: blocks"): a lot (26 x 11)
with its avenue on the right and its street below. Block (i, j) starts at
world column 32 i - 13, row 16 j - 5, so avenues and streets are where they
were in the old 128 x 128 map. The grid is 9 x 17 blocks (the outer ones
partly outside); `block(kind, car, sub)` draws a design (offices, banks, card
shops, a paint garage, parking lots, houses, a suburb park, the friend's
house, two offices with a closed road; 23 designs, at most 31 with the 4 private copies), the grid says
which design stands where (`grid`, targets and garages shuffled in by the
city builder). At run time `GRID` (from `GRID_ORIG`, reset every game) holds
the page of each block. `map_at` (column a, row x -> `(zp0),y`, x kept; the
two characters at each edge of the world are wall, `wall_row`/`wall_sub`)
does the lookup with the `MT_*` tables (about 70 cycles); `y + 1` stays in
the block up to y = 31. `map_fill` (40 characters into `tbuf`), `draw_row`
(straight from the block to the screen) and `draw_col` (8 rows a run) draw
the screen edges; `box_blocked` looks up at most 4 characters. Writing
(`map_wr`, only for stolen cars) first gives the block a private copy
(`PRIV`, 4 of them in turn, `priv_gi`/`priv_next`); the oldest goes back to
its design. Tyre marks are drawn on the screen only (the designs are
shared), so they go when they scroll away. The city map screen (SPACE)
shows every 4th column and every 2nd row (`mm_sample`).

Measured worst case after the change: plain driving `perf_max` ≈ $81, a
chase with 2 police cars, an officer and a roadblock ≈ $90 (of 156).

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

Colour RAM (the "y" pixels: windows, cabs, signs, stripes) is one value per
screen row, the colour of the block row shown there (`bandCols` in
gfx_city.asm, `band_tab` in the program: cyan, yellow, purple, green,
white; no red, that is the getaway car; the suburb yellow). Block rows
change colour between a street row and the next sidewalk, where no "y"
pixels are, so it never has to scroll sideways: when a picture with another
top row is shown, the IRQ at line 250 rewrites the screen rows whose colour
changed (`band_rows`, `lv_cy`, `rowc` = each row's value; `city_colours`
sets `lv_cy` = $ff to redo them all). The road's centre lines are light grey.
The palette is `$d021` grey asphalt, `$d022` light grey,
`$d023` black (roofs, tyre marks). The suburb (map rows
`SUB_ROW` = 203 to 255, block rows 13-16) has green grass instead of the light grey: a third
raster IRQ (`irq_green`, chained after `irq_split` when the suburb is on
screen) sets `$d022` to `LAWN_COL` on the last line of the row above (a street: no "w" pixels
there), and the IRQ at line 250 sets it grey again. The line is
`GREEN_BASE` (55) + 203 * 8 - camera y, prepared in `scroll_regs`
(`sh_gline`, 0 = not on screen, 1 = the whole screen: the IRQ at line 250
sets green then) and taken with the frame (`lv_gline`); at
a line < 84 `irq_split` sets it at once. City
characters in the suburb rows lose their "w" pixels at build time
(`subVariant` in gfx_city.asm: road markings and the card shop's white turn
yellow, the rest grey); suburb art (`subStamp`: houses with hipped roofs,
trees, hedges, the friend's house and driveway) and lawns (`WALK`) keep it.
White and grey parked cars are black there. No character is left (256; the last went to the bus stop sign). Comic bubbles are drawn
into the shown screen with their own colour RAM while the camera stands still,
and the city is restored from the map (and `rowc`) afterwards.

Police and cabs drive on the centre lines of the road grid (avenue centres
x = 128 + 256 k (k 0-7), street centres y = 68 + 128 j (j 0-15); avenues are 6 characters
wide, streets 5 rows high (the block layout in gfx_city.asm; change the
node checks in chase.asm with them) and decide at the crossings, skipping roads with a building 5 rows up or down or 8 columns
left or right of the crossing (`npc_choose`, `node_cell`, `blk_at`; roadblocks are not put
in one either). The city is not a pure grid: `NCLOSED` (14) office blocks have their avenue
piece (`dNoAv`: buildings to column 29) or street piece (`dNoSt`: a row of buildings in
rows 12-14) built over, at most one per crossing, so every crossing keeps two ways (the
police would loop forever with none); not in block row 12 (the grass split needs the street
above the suburb free of "w" pixels). The city builder saves and restores `seed` around
this, so everything built after it (the title picture) stays the same, and never closes
the block the car starts in (`START_X`/`START_Y`, in gfx_city.asm). Then:
cabs at random, police towards the player (longer distance first) and they
turn around when the player is behind them.
Turning: police cars and cabs choose their way 16 pixels before a crossing
(`TURN_R`, `npc_plan`; they slow down there) and are shown on a quarter
circle from 16 pixels before to 16 after it, turning in 16 steps
(`npc_view`: `arc_a`/`arc_b`/`hstep`; cabs keep their lane with `lane16x/y`).
A U-turn turns on the spot in 8 steps (`n_rot`). Only the picture curves:
the real position (for collisions) stays on the centre lines, at most about
5 pixels away. Police use 16 sprites (4 at $c800, 12 at $f800: `cop_ptr`),
cabs the getaway car's 16 even headings.

The getaway car is drawn in 32 headings of 11.25 degrees (since 2.13.0; the
physics still has `hdg` 0-255, `car_frame` stays 0-15 for skid marks,
getting out and the bus): `car_spr` (tail) picks the sprite from `hdg`. The
even headings are `SP_CAR` + 0-15, the odd ones 1-15 `SP_CAR` + 16-23, and
17-31 are 1-15 turned around by 180 degrees (a rotated sprite turned around
is the car pointing the other way), made at run time into `CARMIR` 222/223
($f780, alternating, so the sprite on screen is never rewritten). The arrow
keeps 0-7 (`SP_ARROW` = 120), 8-15 are those turned around into `ARRMIR` 252
($ff00). Turning around reads the source under the I/O area (3 instructions
with `$01=$34` and interrupts held per byte) and reverses the pixels with
`REVT` ($fe00, 256 bytes); it costs up to 35 `perf` units, so `mir_late`
runs it at the end of the main loop (after `frame_ready`), only when `perf`
< `MIR_LATE` (156 - 48), one job at a time (`mir_src`/`mir_dst`); until then
the car shows the heading before it, the arrow its last picture.
`gen_shift_ba` calls `mir_init` (rebuilds `REVT`, forgets `car_last`/`arr_last`)
because the bitmap screens overwrite all of it. Test hooks: `mir_dst`,
`car_last`, `arr_last` (tail, see `build\boogie.sym`). Measured with 2 cabs
and hard turning: `perf_max` $8c, main before it $85-$90.

Measured before the block city (3 police cars, 2 cabs, skid marks, hard turning):
`perf_max` ≈ $8a = 138 of 156; plain driving ≈ $6b; 2 police cars, an
officer shooting and a roadblock ≈ $83.

## Conventions

- Work on a branch, test in VICE (screenshots), merge into `main` and push.
  Commit as `Morten Lundberg` with the Claude co-author line.
- Keep 50 fps: check `fps_val` and `perf_max` after changing the main loop.
- Every version merged into main gets a GitHub release with the .d64, .t64
  and .prg (the README links to the latest): bump `version.asm`, push main,
  then `powershell -ExecutionPolicy Bypass -File tools/release.ps1` (builds,
  tags `v<version>` if needed, creates the release or replaces its files).

## Ideas on the list

More block designs (31 fit; characters are the limit: none left); a minimap in the HUD
(the full map is on SPACE); saving the high scores to disk. A park or river
needs green/blue like the suburb: only as a horizontal band (a raster split
like `irq_green`), since colour RAM is one value per screen row.
