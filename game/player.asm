.section "Player" BANK 0 SLOT "ROM"

nop

.struct Player
    input instanceof Input
    oam_objects instanceof OAMObject 3 
    enabled db
.endst

.enum $0000
    player instanceof Player
.ende

Player_Init:
    ; Init Input
    call(Input_Init, player.input)

    ; Init the Player Sprite
    ldy #$08
    call(OAMObject_RandomInit, player.oam_objects.1)
    call(OAMObject_Write, player.oam_objects.1)

    ldy #$09
    call(OAMObject_RandomInit, player.oam_objects.2)
    call(OAMObject_Write, player.oam_objects.2)
    
    rts

Player_VBlank:
    A8_XY16
    lda player.oam_objects.1.x, X
    ina
    ina
    sta player.oam_objects.1.x, X
    
    lda player.oam_objects.1.y, X
    ina
    ina
    ina
    sta player.oam_objects.1.y, X

    lda player.oam_objects.2.x, X
    ina
    ina
    sta player.oam_objects.2.x, X
    
    lda player.oam_objects.2.y, X
    ina
    ina
    ina
    sta player.oam_objects.2.y, X
    A16_XY16

    call(OAMObject_Write, player.oam_objects.1)  
    call(OAMObject_Write, player.oam_objects.2) 

    rts

.ends