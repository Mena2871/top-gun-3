.section "Character_Attr" BANK 0 SLOT "ROM"

.struct Character_Attr
    id            db ; Character_Attr ID
    speed         db ; Character Speed
    turbo_multi   db ; Character Speed multiplier
.endst

.enum $0000
    character_attr instanceof Character_Attr
.ende

.ends