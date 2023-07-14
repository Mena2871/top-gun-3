.include "game/characters/character_attr.asm"
.include "game/characters/character_1.asm"
.include "game/characters/character_2.asm"

.section "Characters" BANK 0 SLOT "ROM"

.struct Characters
    character_1 instanceof Character_1 ; Character 1
    character_2 instanceof Character_2 ; Character 2
.endst

.enum $0000
    characters instanceof Characters
.ende

Characters_Init:
    phy

    jsr Character_1_Init

    clc
    txa
    adc #characters.character_2
    tax

    jsr Character_2_Init

    ply
    rts

.ends