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
    jsr Player_SetBadgeLocation
    jsr EntityManager_Frame
    rts

Player_SetBadgeLocation:
    ; Calculate relative offsets for the player name tags
    phx

    lda player.char_obj_ptr, X
    tax

    ; Get the main sprite position and then add x += 20, y += 24
    phx
    lda character_1.sprite_ptr, X 

    ; Create temporary variables for the sprite offsets
    tax
    A8
    lda sprite_desc.x, X
    pha
    lda sprite_desc.y, X
    pha
    A16

    lda 3, S
    tax

    lda character_1.name_ptr, X
    tax

    A8
    clc
    lda #20
    adc 2, S
    sta sprite_desc.x, X

    clc
    lda #24
    adc 1, S
    sta sprite_desc.y, X
    A16

    jsr Sprite_MarkDirty

    A8
    pla ; Restore y
    pla ; Restore X
    plx ; Restore Sprite Pointer
    plx ; Restore Player Pointer
    A16

    rts

Player_Input:
    pha

    ; Check buttons
    jsr Player_UpBtn
    jsr Player_DnBtn
    jsr Player_LftBtn
    jsr Player_RhtBtn
    jsr Player_ABtn

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
        A16
        lda $05, y
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
        A16
        lda $05, y
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
        A16
        lda $05, y
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
        A16
        lda $05, y
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

Player_ABtn:
    phx

    ; Load Input State Pointer
    lda player.input_obj_ptr, X
    tax

    ; Check if Up Button is pressed
    lda inputstate.abtn, X
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

    lda $05, y
    tax

    A8
    lda sprite_desc.x, X
    pha

    lda sprite_desc.y, X
    pha

    A16
    jsr EntityManager_Request
    lda #ENTITY_TYPE_PLANE
    sta entity.type, Y

    jsr Entity_Load

    A8
    pla
    sta entity.y, Y

    pla
    sta entity.x, Y

    lda #1
    sta entity.enabled, Y

    lda #1
    sta entity.allocated, Y

    A16
    plx

    @Done:
        plx
        rts
.ends