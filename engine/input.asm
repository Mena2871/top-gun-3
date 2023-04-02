.include "engine/drivers/input/interface.asm"

.ACCU   16
.INDEX  16

.section "Input" BANK 0 SLOT "ROM"

.struct InputState
    rbtn   db
    lbtn   db
    xbtn   db
    abtn   db
    rhtbtn db
    lftbtn db   
    dnbtn  db
    upbtn  db
    start  db
    select db
    ybtn   db
    bbtn   db
.endst

.struct Input
    inputstate instanceof InputState
    enabled db
.endst

.enum $00
    input instanceof Input
.ende

Input_Init:
    A8
    stz input.inputstate.bbtn, X
    stz input.inputstate.ybtn, X
    stz input.inputstate.select, X
    stz input.inputstate.start, X
    stz input.inputstate.upbtn, X
    stz input.inputstate.dnbtn, X
    stz input.inputstate.lftbtn, X
    stz input.inputstate.rhtbtn, X
    stz input.inputstate.abtn, X
    stz input.inputstate.xbtn, X
    stz input.inputstate.lbtn, X
    stz input.inputstate.rbtn, X
    A16
    rts

Input_Frame:
    rts

Input_VBlank:
    pha

    ; Wait until the HVBJOY shows that the controllers are ready to be read
    @WaitForJoyReady:
        lda HVBJOY
        and #1
        bne @WaitForJoyReady

    jsr Input_Buttons
    pla
    rts

Input_Buttons:
    pha
    lda JOY1L
    ; Skip controller id    
    lsr A
    lsr A
    lsr A
    lsr A

    ldy #12
    pha
    txa
    adc #input.inputstate
    tax
    pla
    clc
    @Loop:
        stz input.inputstate, X ; 5 cycles
        lsr A                   ; 2 cycles
        rol input.inputstate, X ; 7 cycles
        inx
        dey
        bne @Loop

    ldy #0
    bra @Done

    @Done:
        pla
        rts

.ends