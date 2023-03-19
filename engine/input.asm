.include "engine/drivers/input/interface.asm"

.section "Input" BANK 0 SLOT "ROM"

nop

.struct InputState
    index  db
    start  db
    select db
    upbtn  db
    dnbtn  db
    lftbtn db
    rhtbtn db
.endst

.struct Input
    inputstate instanceof InputState
    ; enabled db
.endst

.enum $00
    input instanceof Input
.ende

Input_Init:
    stz input.inputstate.upbtn, X
    stz input.inputstate.dnbtn, X
    stz input.inputstate.rhtbtn, X
    stz input.inputstate.lftbtn, X
    rts

Input_Frame:
    rts

Input_VBlank:
    pha
    jsr Input_UpButton
    jsr Input_DnButton
    jsr Input_LftButton
    jsr Input_RhtButton
    pla
    rts

Input_DnButton:
    pha
    @CheckDnButton:
        lda JOY1L                          ; check whether the Dn button was pressed this frame...
        cmp #DNBTN
        bne @CheckDnButtonDone 
        lda #1
        sta input.inputstate.dnbtn, X
        bra @Done

    @CheckDnButtonDone:
        lda #0
        sta input.inputstate.dnbtn, X
        bra @Done

    @Done:
        pla
        rts

Input_UpButton:
    pha
    @CheckUpButton:
        lda JOY1L                          ; check whether the up button was pressed this frame...
        cmp #UPBTN
        bne @CheckUpButtonDone 
        lda #1
        sta input.inputstate.upbtn, X
        bra @Done

    @CheckUpButtonDone:
        lda #0
        sta input.inputstate.upbtn, X
        bra @Done

    @Done:
        pla
        rts

Input_LftButton:
    pha
    @CheckLftButton:
        lda JOY1L                          ; check whether the lft button was pressed this frame...
        cmp #LFTBTN
        bne @CheckLftButtonDone 
        lda #1
        sta input.inputstate.lftbtn, X
        bra @Done

    @CheckLftButtonDone:
        lda #0
        sta input.inputstate.lftbtn, X
        bra @Done

    @Done:
        pla
        rts

Input_RhtButton:
    pha
    @CheckRhtButton:
        lda JOY1L                          ; check whether the rht button was pressed this frame...
        cmp #RHTBTN
        bne @CheckRhtButtonDone 
        lda #1
        sta input.inputstate.rhtbtn, X
        bra @Done

    @CheckRhtButtonDone:
        lda #0
        sta input.inputstate.rhtbtn, X
        bra @Done

    @Done:
        pla
        rts
.ends