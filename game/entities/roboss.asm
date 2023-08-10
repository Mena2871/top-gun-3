.struct Roboss
    base instanceof Entity
    num_projectiles db  ; Number of projectiles to fire next frame
.endst
.enum $0000
    roboss instanceof Roboss
.ende

.section "RobossROM" bank 0 slot "ROM"

nop

.dstruct RobossBase instanceof Roboss values
    base.id:         .db "RBOS"
    base.type:       .dw ENTITY_TYPE_BOSS
    base.health:     .db 100
    base.max_health: .db 100
    base.width:          .db 32
    base.height:          .db 32
    num_projectiles: .db 0
.endst

Roboss_Frame:
    brk
    rts

.ends