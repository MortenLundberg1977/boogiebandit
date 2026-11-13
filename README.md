# Boogie Bandit

*New York, 1977. The disco never stops, and neither do you.*

A top-down getaway game for the Commodore 64 (PAL), written in 6502 assembly
for KickAssembler. Drive a 70s sedan through a smooth-scrolling city, park at
the bank the arrow points to, hop out, pull the job (KAPOW! ZOWIE! KACHING!),
and get back to the car. Runs at 50 frames a second, shown top left.

![Title](screenshots/1_title_b.png) ![Robbery](screenshots/5_robbery_1.png)

## Controls (joystick in port 2)

| | |
|---|---|
| Up / down | accelerate / brake and reverse |
| Left / right | steer (on foot: walk) |
| Fire | get out of the car (nearly stopped), get back in (next to it) |
| M | music on / off |
| D | raster time bar in the border (CPU time of each frame) |

Floor it from a standstill or slide through a corner and you leave rubber on
the road.

## Building

Needs Java, `KickAss.jar` in the parent folder (or `KICKASS_JAR` set) and
VICE (`x64sc`, `c1541` on `PATH`).

```
build.bat run
```

builds `build\boogie.prg` and `build\boogiebandit.d64` and starts VICE. On a
real C64: `LOAD"BOOGIE",8` then `RUN`.

All graphics, the title picture, the fonts and the music are generated at
build time from the sources; there are no binary assets.
