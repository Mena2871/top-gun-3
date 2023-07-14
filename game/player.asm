.section "Player" BANK 0 SLOT "ROM"

nop

.struct Player
    id               db ; Player ID
    oam_obj_ptr      dw ; Pointer to the requested OAM object
    input_obj_ptr    dw ; Pointer to the requested Input Object
    char_obj_ptr     dw ; Pointer to the character Object
.endst

.enum $0000
    player instanceof Player
.ende

Player_Init:
    phy

    sty player.char_obj_ptr, x
    
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
    lda player.char_obj_ptr, X
    pha

    ; Check buttons
    jsr Player_UpBtn
    jsr Player_DnBtn
    jsr Player_LftBtn
    jsr Player_RhtBtn

    pla
    pla
    pla
    pla
    rts

Player_UpBtn:
    ; Load Input State Pointer
    lda 5, s
    tax

    ; Load Button State
    lda #0
    A8
    lda inputstate.upbtn, X
    A16
    tay
    cpy #1
    bne @Done
    lda 3, s
    adc 1
    tax

    ; Load Speed Attr
    lda #0
    A8
    lda character_attr.speed, X
    tay
    A16
    lda 7, s
    tax
    A8

    ; Load OAM Y location
    lda oam_object.y, X
    clc
    phy

    ; Subtract Speed Value from current Value
    sbc 1, S
    sta oam_object.y, X
    ply
    A16

    ; Update OAM
    jsr OAM_MarkDirty
    @Done:
        rts

Player_DnBtn:
    ; Load Input State Pointer
    lda 5, s
    tax

    ; Load Button State
    lda #0
    A8
    lda inputstate.dnbtn, X
    A16
    tay
    cpy #1
    bne @Done
    lda 3, s
    adc 1
    tax

    ; Load Speed Attr
    lda #0
    A8
    lda character_attr.speed, X
    tay
    A16
    lda 7, s
    tax
    A8

    ; Load OAM Y location
    lda oam_object.y, X
    clc
    phy

    ; Add Speed Value from current Value
    adc 1, S
    sta oam_object.y, X
    ply
    A16

    ; Update OAM
    jsr OAM_MarkDirty
    @Done:
        rts

Player_LftBtn:
    ; Load Input State Pointer
    lda 5, s
    tax

    ; Load Button State
    lda #0
    A8
    lda inputstate.lftbtn, X
    A16
    tay
    cpy #1
    bne @Done
    lda 3, s
    adc 1
    tax

    ; Load Speed Attr
    lda #0
    A8
    lda character_attr.speed, X
    tay
    A16
    lda 7, s
    tax
    A8

    ; Load OAM X location
    lda oam_object.x, X
    clc
    phy

    ; Subtract Speed Value from current Value
    sbc 1, S
    sta oam_object.x, X
    ply
    A16
    jsr Renderer_TestMoveScreenLeft 
    jsr OAM_MarkDirty
    @Done:
        rts

Player_RhtBtn:
    ; Load Input State Pointer
    lda 5, s
    tax

    ; Load Button State
    lda #0
    A8
    lda inputstate.rhtbtn, X
    A16
    tay
    cpy #1
    bne @Done
    lda 3, s
    adc 1
    tax

    ; Load Speed Attr
    lda #0
    A8
    lda character_attr.speed, X
    tay
    A16
    lda 7, s
    tax
    A8

    ; Load OAM X location
    lda oam_object.x, X
    clc
    phy

    ; Add Speed Value from current Value
    adc 1, S
    sta oam_object.x, X
    ply
    A16
    jsr Renderer_TestMoveScreenRight
    jsr OAM_MarkDirty
    @Done:
        rts

.ends