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
.endst

.enum $00
    input instanceof Input
.ende

Input_Init:
    rts

Input_Frame:
    rts

; X is "this" pointer
Input_VBlank:
    pha

    lda JOY1L
    lda JOY1H

    lda #$FF


    pla
    rts

.ends