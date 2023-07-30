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

    phx
    ; Restore X pointing to the player object
    lda 3, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Input Pointer
    plx

    ; Load Player Speed
    lda character_attr.speed, Y

    pha ; Store Speed

    @Move_Sprite:
        iny
        iny
        iny
        A16
        lda $00, Y
        tax

        ; Load Sprite Info
        A8
        lda sprite_desc.y, X
        sec
        sbc 1, S
        sta sprite_desc.y, X
        jsr Sprite_MarkDirty

        pla
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

    phx
    ; Restore X pointing to the player object
    lda 3, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Input Pointer
    plx

    ; Load Player Speed
    lda character_attr.speed, Y

    pha ; Store Speed

    @Move_Sprite:
        iny
        iny
        iny
        A16
        lda $00, Y
        tax

        ; Load Sprite Info
        A8
        lda sprite_desc.y, X
        clc
        adc 1, S
        sta sprite_desc.y, X
        jsr Sprite_MarkDirty

        pla
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

    phx
    ; Restore X pointing to the player object
    lda 3, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Input Pointer
    plx

    ; Load Player Speed
    lda character_attr.speed, Y

    pha ; Store Speed

    @Move_Sprite:
        iny
        iny
        iny
        A16
        lda $00, Y
        tax

        ; Load Sprite Info
        A8
        lda sprite_desc.x, X
        sec
        sbc 1, S
        sta sprite_desc.x, X
        jsr Sprite_MarkDirty

        pla
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

    phx
    ; Restore X pointing to the player object
    lda 3, S
    tax

    ; Now use X and Y index registers for oam object and char object pointers
    lda player.char_obj_ptr, X
    ina
    tay

    ; Load Input Pointer
    plx

    ; Store tag
    lda #Sprite_Plane@Tag@Forward
    pha

    ; Load Player Speed
    lda character_attr.speed, Y

    pha ; Store Speed
    
    lda inputstate.rbtn, X
    cmp #1
    bne @Move_Sprite

    @Turbo:
        pla
        sta WRMPYA

        pla ; Pull tag and update
        lda #Sprite_Plane@Tag@Forward_Afterburner
        pha

        A8
        lda character_attr.turbo_multi, Y
        sta WRMPYB

        nop
        nop
        nop
        nop

        lda RDMPYL
        clc
        adc RDMPYH
        A16
        pha



    @Move_Sprite:
        iny
        iny
        iny
        A16
        lda $00, Y
        tax

        ; Load Sprite Info
        A8
        lda sprite_desc.x, X
        clc
        adc 1, S
        sta sprite_desc.x, X
        jsr Sprite_MarkDirty

        pla
        pla
        A16

        txy
        jsr Sprite_SetTag
        
        ; Set the frame of the sprite to 0
        lda #0
        jsr Sprite_SetFrame

    jsr Renderer_TestMoveScreenRight

    @Done:
        plx
        rts

.ends