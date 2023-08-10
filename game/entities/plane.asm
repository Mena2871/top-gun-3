.define WEAPON_TYPE_MACHINE_GUN 0
.define SPEED_TYPE_NORMAL 1

.struct Plane
    base instanceof Entity
    weapon        db  ; Which weapon the character has
    speed         db  ; Which Speed
    turbo_multi   db  ; Speed multiplier
.endst
.enum $0000
    plane instanceof Plane
.ende

.section "PlaneROM" bank 0 slot "ROM"

nop

.dstruct PlaneBase instanceof Plane values
    base.id:            .db "PLAN"
    base.type:          .dw ENTITY_TYPE_PLANE
    base.health:        .db 100
    base.max_health:    .db 100
    base.width:             .db 64
    base.height:             .db 32
    weapon:             .db WEAPON_TYPE_MACHINE_GUN
    speed:              .db SPEED_TYPE_NORMAL
    turbo_multi:        .db 1
.endst

;
; Y is the plane pointer
;
Plane_Init:
    pha
    phx
    phy

    ; Polymorphism, bitches
    jsr Entity_Init

    ply
    plx
    pla
    rts

Plane_Frame:
    phy
    A8

    lda plane.base.x, Y
    cmp #0
    bne @Move
    jsr EntityManager_Release
    bra @Done

    @Move:  
        ina
        sta plane.base.x, Y

        A16
        jsr Entity_MarkDirty


    @Done:
        ply
        rts

.ends