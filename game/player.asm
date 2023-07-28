.struct Player
    id               db ; Player ID
    oam_obj_ptr      dw ; Pointer to the requested OAM object
    input_obj_ptr    dw ; Pointer to the requested Input Object
    char_obj_ptr     dw ; Pointer to the character Object
.endst

.enum $0000
    player instanceof Player
.ende

.section "Player" BANK 0 SLOT "ROM"
nop

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

    ; Check buttons
    jsr Player_UpBtn
    jsr Player_DnBtn
    jsr Player_LftBtn
    jsr Player_RhtBtn

    pla
    rts

Player_UpBtn:
    phx

    ; Load Input State Pointer
    lda player.input_obj_ptr, X
    tax

    ; Check if Up Button is pressed
    lda inputstate.upbtn, X
    and #1
    beq @Done

    ; Restore X pointing to the player object
    lda 1, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Sprite Pointer
    lda $00, Y
    tax
    A8
    sec
    lda sprite_desc.y, X

    ; Modify Sprite Location
    iny
    iny
    sbc character_attr.speed, Y
    sta sprite_desc.y, X
    jsr Sprite_MarkDirty

    A16

    @Done:
        plx
        rts

Player_DnBtn:
    phx

    ; Load Input State Pointer
    lda player.input_obj_ptr, X
    tax

    ; Check if Down Button is pressed
    lda inputstate.dnbtn, X
    and #1
    beq @Done

    ; Restore X pointing to the player object
    lda 1, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Sprite Pointer
    lda $00, Y
    tax
    A8
    clc
    lda sprite_desc.y, X

    ; Modify Sprite Location
    iny
    iny
    adc character_attr.speed, Y
    sta sprite_desc.y, X
    jsr Sprite_MarkDirty

    A16

    @Done:
        plx
        rts

Player_LftBtn:
    phx

    ; Load Input State Pointer
    lda player.input_obj_ptr, X
    tax

    ; Check if Left Button is pressed
    lda inputstate.lftbtn, X
    and #1
    beq @Done

    ; Restore X pointing to the player object
    lda 1, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Sprite Pointer
    lda $00, Y
    tax
    A8
    sec
    lda sprite_desc.x, X

    ; Modify Sprite Location
    iny
    iny
    sbc character_attr.speed, Y
    sta sprite_desc.x, X
    jsr Sprite_MarkDirty

    A16
    jsr Renderer_TestMoveScreenLeft

    @Done:
        plx
        rts

Player_RhtBtn:
    phx

    ; Load Input State Pointer
    lda player.input_obj_ptr, X
    tax

    ; Check if Right Button is pressed
    lda inputstate.rhtbtn, X
    and #1
    beq @Done

    ; Restore X pointing to the player object
    lda 1, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Sprite Pointer
    lda $00, Y
    tax
    A8
    clc
    lda sprite_desc.x, X

    ; Modify Sprite Location
    iny
    iny
    adc character_attr.speed, Y
    sta sprite_desc.x, X
    jsr Sprite_MarkDirty

    A16
    jsr Renderer_TestMoveScreenRight

    @Done:
        plx
        rts

.ends