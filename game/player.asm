.section "Player" BANK 0 SLOT "ROM"

nop

.struct Player
    id               db ; Player ID
    oam_obj_ptr      dw ; Pointer to the requested OAM object
    input_obj_ptr    dw ;
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

    ; Init Input
    ; call(Input_Init, player.input)
    jsr Player_OAMRequest

    ply
    rts

Player_OAMRequest:
    pha
    phy

    jsr OAMManager_Request
    jsr InputManager_Request
    ; VRAM address 0 is a transparent tile. 1 is a grass tile in the test.
    A8
    lda #1
    sta oam_object.vram, Y
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

Player_VBlank:
    pha

    ; call(Input_VBlank, player.input)

    pla
    rts

Player_Input:
    pha
    phx

    ; Load pointer to OAM object
    lda player.oam_obj_ptr, X
    ; jsr Player_UpBtn
    ; jsr Player_DnBtn
    ; jsr Player_LftBtn
    ; jsr Player_RhtBtn
    tax

    plx
    pla
    rts

; Player_UpBtn:
;     phx
;     phy

;     ldy player.input.inputstate.upbtn, X
;     cpy #1
;     bne @Done

;     tax
;     A8
;     dec oam_object.y, X
;     A16
;     jsr OAM_MarkDirty
;     @Done:
;         ply
;         plx
;         rts

; Player_DnBtn:
;     phx
;     phy

;     ldy player.input.inputstate.dnbtn, X
;     cpy #1
;     bne @Done

;     tax
;     A8
;     inc oam_object.y, X
;     A16

;     jsr OAM_MarkDirty
;     @Done:
;         ply
;         plx
;         rts

; Player_LftBtn:
;     phx
;     phy

;     ldy player.input.inputstate.lftbtn, X
;     cpy #1
;     bne @Done

;     tax
;     A8
;     dec oam_object.x, X
;     A16
;     jsr OAM_MarkDirty
;     @Done:
;         ply
;         plx
;         rts

; Player_RhtBtn:
;     phx
;     phy

;     ldy player.input.inputstate.rhtbtn, X
;     cpy #1
;     bne @Done

;     tax
;     A8
;     inc oam_object.x, X
;     A16
;     jsr OAM_MarkDirty
;     @Done:
;         ply
;         plx
;         rts

.ends