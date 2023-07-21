What is an object?
==================
Objects are the primitive that associate sprites. Any small graphic that
can move independent of the background is an object. They can use the
palettes from 8-15 and are 4BPP that can be 8x8, 16x16, 32x32, 64x64.

Overview
========
The maximum number of objects that can be displayed on the screen is 128.
A frame can have two sizes of objects and each object can be one of the two
sizes. Each frame can have 8 color palettes and an object can use one of the
palettes. Each palette is 16 colors out of 32,768 colors.

During Initial Settings
=======================
- Set register <2101H> to set the object size, name select, and base address.
- Set D1 of register <2133H> to set the object V select.
- Set D4 of register <212CH> for "Through Main Obj" settings.

During Forced Blank
===================
- Set register <2115H> to set V-RAM address sequence mode. H/L increments.
- Set register <2116H> ~ <2119H> to set the V-RAM address and data.
- Transfer all the object character data to VRAM through the DMA registers.
- Set register <2121H>, <2122H> to set color palette address and data.

During V-BLANK
==============
- Set register <2102H> ~ <2104H> to set OAM address, priority, and data.
- Transfer object data to OAM via DMA.

OAM Addressing
===============
                             OBJECT 0
    | 15 | 14 | 13 | 12 | 11 | 10 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
    |----|----|----|----|----|----|---|---|---|---|---|---|---|---|---|---|
000 | ~~~~~Object V-Position~~~~~~~~~~~~~ | ~~~~~Object H-Position~~~~~~~ |
    | 7  | 6  | 5  | 4  | 3  | 2  | 1 | 0 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
001 | ~FLIP~  | ~PRIOR~ |    ~COLOR~  | ~~~~~~~~~~~~~~~NAME~~~~~~~~~~~~~~ |
    | V  | H  | 1  | 0  | 2  | 1  | 0 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
 .    ^         ^         ^             ^
      |         |         |              \ Character code number
      |         |         \ Designate palette for the character
      |          \Determine the display priority when objects overlap
       \ X-direction and Y-direction flip. (0 is normal, 1 is flip)

Repeats for 128 objects and then addresses 256 - 271 are for extra bits.

 .                          OBJECT 7...0
256 | 15 | 14 | 13 | 12 | 11 | 10 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
    |   OBJ7  |  OBJ6   |   OBJ5  |  OBJ4 | OBJ3  | OBJ2  | OBJ1  | OBJ0  |
    | S  | Z  | S  | Z  | S  | Z  | S | Z | S | Z | S | Z | S | Z | S | Z |
      ^    ^
      |    \ Base position of the Object on the H-direction
      \ Size large/small (0 is small)