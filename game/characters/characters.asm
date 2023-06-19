.include "game/characters/character_attr.asm"
.include "game/characters/character_1.asm"
.include "game/characters/character_2.asm"

.section "Characters" BANK 0 SLOT "ROM"

nop

.struct Characters
    character_1 instanceof Character_1 ; Character 1
    character_2 instanceof Character_2 ; Character 2
.endst

.enum $0000
    characters instanceof Characters
.ende

Characters_Init:
    phy

    A8

    ; ldx #characters.character_1
    jsr Character_1_Init

    ; ldx #characters.character_2
    jsr Character_2_Init

    A16

    ply
    rts

.ends