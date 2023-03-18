.include "engine/drivers/input/interface.asm"

.section "Input" BANK 0 SLOT "ROM"

nop

.struct InputState
    index db
    start db
    select db
    upbtn db
.endst

.struct Input
    inputstate instanceof InputState
    enabled db
.endst

.enum $00
    input instanceof Input
.ende

Input_Init:
    stz input.inputstate.upbtn, X
    rts

Input_Frame:
    rts

Input_VBlank:
    pha
    jsr Input_UpButton
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

.ends