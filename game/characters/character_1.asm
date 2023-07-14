.section "Character_1" BANK 0 SLOT "ROM"

.struct Character_1
    id         db ; Character ID
    character_attr instanceof Character_Attr
.endst

.enum $0000
    character_1 instanceof Character_1
.ende

Character_1_Init:
    phy

    A8
    lda #1
    sta character_1.id, X

    lda #3
    sta character_1.character_attr.speed, X
    A16
    
    ply
    rts

.ends