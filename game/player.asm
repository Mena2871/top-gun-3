.section "Player" BANK 0 SLOT "ROM"

nop

.struct Player
    input instanceof Input
    oam_obj_ptr dw ; Pointer to the requested OAM object
    enabled db
.endst

.enum $0000
    player instanceof Player
.ende

Player_Init:
    phy

    ; Init Input
    call(Input_Init, player.input)

    jsr Player_OAMRequest

    ply
    rts

Player_OAMRequest:
    pha
    phy
    call_ptr(OAMManager_Request, engine.oam_manager) ; Request 1 OAM object

    ; VRAM address 0 is a transparent tile. 1 is a grass tile in the test.
    A8
    lda #1
    sta oam_object.vram, Y
    A16

    ; Save the pointer for testing later
    tya
    sta player.oam_obj_ptr, X

    ply
    pla
    rts

Player_VBlank:
    pha

    call(Input_VBlank, player.input)
    jsr Player_Input
    call_ptr(OAMManager_VBlank, engine.oam_manager)

    pla
    rts

Player_Input:
    pha
    phx

    ; Load pointer to OAM object
    lda player.oam_obj_ptr, X
    jsr Player_UpBtn
    tax

    A8
    ; Load OAM object and add 1 to x position and y position
    inc oam_object.x, X
    stz oam_object.clean, X

    A16

    plx
    pla
    rts

Player_UpBtn:
    phy

    ldy player.input.inputstate.upbtn, X
    cpy #1
    bne @Done

    tax
    A8
    inc oam_object.y, X

    @Done:
        A16
        ply
        rts

.ends