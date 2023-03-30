.include "engine/drivers/input/interface.asm"

.ACCU   16
.INDEX  16

.define UPBTN   $0800
.define DNBTN   $0400
.define LFTBTN  $0200
.define RHTBTN  $0100

.section "Input" BANK 0 SLOT "ROM"

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
    enabled db
.endst

.enum $00
    input instanceof Input
.ende

Input_Init:
    A8
    stz input.inputstate.dnbtn, X
    stz input.inputstate.upbtn, X
    stz input.inputstate.rhtbtn, X
    stz input.inputstate.lftbtn, X
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

    jsr Input_DnButton
    jsr Input_UpButton
    jsr Input_LftButton
    jsr Input_RhtButton
    pla
    rts

Input_DnButton:
    pha
    @CheckDnButton:
        lda JOY1L                          ; check whether the Dn button was pressed this frame...
        bit #DNBTN
        beq @CheckDnButtonDone 
        A8
        lda #1
        sta input.inputstate.dnbtn, X
        bra @Done

    @CheckDnButtonDone:
        A8
        lda #0
        sta input.inputstate.dnbtn, X
        bra @Done

    @Done:
        A16
        pla
        rts

Input_UpButton:
    pha
    @CheckUpButton:
        lda JOY1L                          ; check whether the up button was pressed this frame...
        bit #UPBTN
        beq @CheckUpButtonDone 
        A8
        lda #1
        sta input.inputstate.upbtn, X
        bra @Done

    @CheckUpButtonDone:
        A8
        lda #0
        sta input.inputstate.upbtn, X
        bra @Done

    @Done:
        A16
        pla
        rts

Input_LftButton:
    pha
    @CheckLftButton:
        lda JOY1L                          ; check whether the lft button was pressed this frame...
        bit #LFTBTN
        beq @CheckLftButtonDone 
        A8
        lda #1
        sta input.inputstate.lftbtn, X
        bra @Done

    @CheckLftButtonDone:
        A8
        lda #0
        sta input.inputstate.lftbtn, X
        bra @Done

    @Done:
        A16
        pla
        rts

Input_RhtButton:
    pha
    @CheckRhtButton:
        lda JOY1L                          ; check whether the rht button was pressed this frame...
        bit #RHTBTN
        beq @CheckRhtButtonDone 
        A8
        lda #1
        sta input.inputstate.rhtbtn, X
        bra @Done

    @CheckRhtButtonDone:
        A8
        lda #0
        sta input.inputstate.rhtbtn, X
        bra @Done

    @Done:
        A16
        pla
        rts
.ends