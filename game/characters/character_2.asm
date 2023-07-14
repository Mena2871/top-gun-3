.section "Character_2" BANK 0 SLOT "ROM"

.struct Character_2
    id         db ; Character ID
    character_attr instanceof Character_Attr
.endst

.enum $0000
    character_2 instanceof Character_2
.ende

Character_2_Init:
    phy

    A8
    lda #2
    sta character_2.id, X

    lda #1
    sta character_2.character_attr.speed, X
    A16

    ply
    rts

.ends