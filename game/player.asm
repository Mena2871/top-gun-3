.section "Player" BANK 0 SLOT "ROM"

nop

.struct Player
    id               db ; Player ID
    oam_obj_ptr      dw ; Pointer to the requested OAM object
    input_obj_ptr    dw ; Pointer to the requested Input Object
.endst

.enum $0000
    player instanceof Player
.ende

Player_Init:
    phy

    A8
    lda #1
    sta player.id, X
    A16

    jsr Player_InputRequest
    jsr Player_OAMRequest

    ply
    rts

Player_InputRequest:
    jsr InputManager_Request
    sty player.input_obj_ptr, X

    rts

Player_OAMRequest:
    pha
    phy

    jsr OAMManager_Request

    ; VRAM address 0 is a transparent tile. 1 is a grass tile in the test.

    A8
    lda #10
    sta oam_object.vram, Y
    lda #3
    sta oam_object.priority, Y
    A16

    phx
    tyx
    jsr OAM_MarkDirty
    plx

    tya
    sta player.oam_obj_ptr, X

    ply
    pla
    rts

Player_Frame:
    jsr Player_Input
    rts

Player_Input:
    pha

    ; Load pointer to OAM object
    lda player.oam_obj_ptr, X
    pha
    lda player.input_obj_ptr, X
    pha

    jsr Player_UpBtn
    jsr Player_DnBtn
    jsr Player_LftBtn
    jsr Player_RhtBtn

    pla
    pla
    pla
    rts

Player_UpBtn:
    lda 3, s
    tax
    ldy inputstate.upbtn, X
    cpy #1
    bne @Done
    lda 5, s
    tax
    A8
    dec oam_object.y, X
    A16
    jsr OAM_MarkDirty
    @Done:
        rts

Player_DnBtn:
    lda 3, s
    tax
    ldy inputstate.dnbtn, X
    cpy #1
    bne @Done
    lda 5, s
    tax
    A8
    inc oam_object.y, X
    A16
    jsr OAM_MarkDirty
    @Done:
        rts

Player_LftBtn:
    lda 3, s
    tax
    ldy inputstate.lftbtn, X
    cpy #1
    bne @Done
    lda 5, s
    tax
    A8
    dec oam_object.x, X
    A16
    jsr Renderer_TestMoveScreenLeft 
    jsr OAM_MarkDirty
    @Done:
        rts

Player_RhtBtn:
    lda 3, s
    tax
    ldy inputstate.rhtbtn, X
    cpy #1
    bne @Done
    lda 5, s
    tax
    A8
    inc oam_object.x, X
    A16
    jsr Renderer_TestMoveScreenRight
    jsr OAM_MarkDirty
    @Done:
        rts

.ends