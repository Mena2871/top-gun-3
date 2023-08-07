# TOP-GUN-3

Like you flew into a dream, but had to eject into a nightmare.

![Requiem for a Tuesday](https://i.imgur.com/I1rDN5b.gif)

# Build

This project heavily uses [wla-dx](https://wla-dx.readthedocs.io/)

```
$ ./build.sh
```

# Design

No one on this team has ever looked at 65816 or SPC-700, but we're going
to hack away like it is 1991 and soar into the heavens of assembly.

## Folder Layout

```
common/
    lib/
        malloc.i        barebones malloc implementation
        math.i          math routines (mul, div)
        point.i         vector math
        queue.i         generic queue implementation
        stack.i         generic stack implementation
        string.i        string manipulation methods
    alias.i             common aliases for registers
    macros.i            common macros used across the code base
    memorymap.i         layout for the ROM and RAM
    pool.asm            generic memory pool implementation

debug/
    debug_game.asm      exercise map, sprites, fonts, and timers
    debug_pool.asm      tests specifically around pool management
    debug.asm           all the debug flags you can enable

docs/
    oam-module.md       description of OAM space
    vram-layout.md      sketch of how to expect VRAM to be setup

engine/
    snes/
        interface.asm   SNES bootup and initialization code
    spc700/
        interface.asm   SPC-700 specific bootup code
    bg.asm              Background layer management
    cgram.asm           Color palette management
    engine.asm          Core engine module for starting everything
    font.asm            Font loading and manipulation
    input.asm           Controller input handling
    map.asm             Map loading and tilemap definitions
    oam.asm             OAM space management and DMA controls
    renderer.asm        Screen-space distortions
    sound.asm           Sound management (incomplete)
    sprite.asm          Sprite loading and VRAM char management
    timer.asm           Multi-resolution (and precision) timers

game/
    characters/
        character_1.asm     Character 1 (plane) definitions
        character_2.asm     Character 2 (plane) definitions
        character_attr.asm  Generic character attributes
        characters.asm      List of characters
    entities/
        entity.asm          Entity management
    fonts.i                 List of all fonts used in the game
    game.asm                Top-level module for starting the game
    main.asm                ROM entrypoints and interrupts
    maps.i                  All available maps
    player.asm              Associates characters and inputs
    sprites.i               List of all the sprites in the game
    strings.i               List of all fixed strings in game

resources/
    char/
        16x16/              16x16 test characters
    fonts/
        8x8-font.bin        2 bitplane 8x8 font
        8x8-font.pal        Font colormap
        8x8-font.aseprite   Aseprite layers for the 8x8 font
    maps/
        Skyscraper.bin      Skyscraper map as exported by tools
        Skyscraper.tmx      Skyscraper Tiled
        Skyscraper.pal      Skyscraper colors as exported by tools
        Synthscraper.bin    Synthscraper map as exported by tools
        Synthscraper.tmx    Synthscraper Tiled
        Synthscraper.pal    Synthscraper colors exported by tools
    sprites/
        8x8/                8x8 test sprite
        16x16/              16x16 test sprite
        boss/               Boss sprite
        names/              Name badges under player
        plane/              Plane sprite

tools/
    aseprite2bin.py         Convert Asesprite to engine format
    tiled2bin.py            Convert Tiled to engine format

build.sh                    Build this baby
build.bat                   Build this baby, but with Windows
```