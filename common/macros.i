; Processor flags for 65816 native mode
; =========================
; Bits: 7   6   5   4   3   2   1   0
; 
;                                |e├─── Emulation: 0 = Native Mode
;    |n| |v| |m| |x| |d| |i| |z| |c|
;    └┼───┼───┼───┼───┼───┼───┼───┼┘
;     │   │   │   │   │   │   │   └──────── Carry: 1 = Carry set
;     │   │   │   │   │   │   └───────────── Zero: 1 = Result is zero
;     │   │   │   │   │   └────────── IRQ Disable: 1 = Disabled
;     │   │   │   │   └───────────── Decimal Mode: 1 = Decimal, 0 = Hexadecimal
;     │   │   │   └──────── Index Register Select: 1 = 8-bit, 0 = 16-bit
;     │   │   └─────────────── Accumulator Select: 1 = 8-bit, 0 = 16-bit
;     │   └───────────────────────────── Overflow: 1 = Overflow set
;     └───────────────────────────────── Negative: 1 = Negative set

;
; Enable 65816 mode and put into 16-bit addressing
; 1. Put the CPU into 65816 mode (native 16-bit)
;     1.1. Clear the carry (clc)
;     1.2. Set E=0 (xce)
;
.macro Enable65816
    clc
    xce
    A8_XY16
.endm

;
; Set Binary Mode
; ----D---
;
 .macro EnableBinaryMode
    rep #%00001000
.endm

;
; Set 16-bit Accumulator and XY Index Registers
; --MX----
;
; This is done by resetting the processor state for the
; accumulator and index register select flags. When the
; flags are set to 1, then we are resetting the value back
; to 0, which puts the state into 16-bit for Accumulator and XY
;
.macro A16_XY16
    rep     #%00110000
    .ACCU   16
    .INDEX  16
.endm

;
; Set 8-bit Accumulator and 16-bit XY registers
; ---X----
;
.macro A8_XY16
    rep    #%00010000
    sep    #%00100000
    .ACCU  8
    .INDEX 16
.endm

;
; Zero a range of registers
; Arguments:
; - START: The starting register
; - END: The ending register
; - NAME: The name of the register for debugging labels
;
.macro ZeroRegisters ARGS START, END, NAME
    ldx #(END - START)           ; Compute loop count
    @ZeroRegister_{NAME}:        ; Loop label to zero a specific register
        stz START, X             ; Zero the register 
        dex                      ; Decrement the counter
        bpl @ZeroRegister_{NAME} ; Branch if positive
.endm

;
; Zero a specific register
; Arguments:
;  - REGISTER: The register to zero
;  - COUNT: The number of times to zero the register
;  - NAME: The name of the register for debugging labels
;
.macro ZeroRegister ARGS REGISTER, COUNT, NAME
    ldx #(COUNT)                 ; Loop COUNT times
    @ZeroRegister_{NAME}:        ; Loop label to zero a specific register
        stz REGISTER             ; Zero the register
        dex                      ; Decrement the counter
        bpl @ZeroRegister_{NAME} ; Branch if positive
.endm

;
; Load a sprite into the OAM
; Arguments:
;  - X: The horizontal position of the sprite
;  - Y: The vertical position of the sprite
;  - NAME: The name (index) of the sprite
;  - FLIP: The flip and palette attributes
;  - DEBUG_NAME: The name of the sprite for debugging labels
;
.macro LoadSprite ARGS X, Y, NAME, FLIP, DEBUG_NAME
@LoadSprite{DEBUG_NAME}:
    ; horizontal position of second sprite
    lda #(256/2 + X)    ; 256/2 = 128 + X
    sta OAMDATA         ; Store the value in the OAMDATA register

    ; vertical position of second sprite
    lda #(224/2 + Y)    ; 224/2 = 112 + Y
    sta OAMDATA         ; Store the value in the OAMDATA register

    ; name of second sprite
    lda #(NAME)         ; Set the sprite index
    sta OAMDATA         ; Store the value in the OAMDATA register

    ; no flip, prio 0, palette 0
    lda #(FLIP)         ; Set the sprite attributes
    sta OAMDATA         ; Store the value in the OAMDATA register
.endm

;
; Allocate memory for an object
; Arguments:
;  - OBJECT: The object to allocate memory for
; 
.macro Allocate ARGS OBJECT
    pea _sizeof_{OBJECT} ; Push the size of the object onto the stack
    jsr Malloc_Bytes     ; Request memory for the object
    pla
.endm

;
; Call a function with a "this" pointer
; Arguments:
;  - FUNCTION: The function to call
;  - OFFSET: The offset of the "this" pointer
;
.macro call ARGS FUNCTION, OFFSET
    phx             ; Save and restore the X register
    pha             ; Preserve the accumulator
    txa             ; Load the "this" pointer
    clc             ; Ensure carry bit is clear
    adc #(OFFSET)   ; Add the "this" pointer offset
    tax             ; Copy the accumulator to the X register
    pla             ; Restore the accumulator
    jsr FUNCTION    ; Call the function
    plx             ; Restore the old X register
.endm

;
; Call a function with a "this" pointer through the pointer
; Arguments:
;  - FUNCTION: The function to call
;  - OFFSET: The offset of the "this" pointer
;
.macro call_ptr ARGS FUNCTION, OFFSET
    phx             ; Preserve the X register
    pha             ; Preserve the accumulator
    txa             ; Load the "this" pointer
    clc             ; Ensure carry bit is clear
    adc #(OFFSET)   ; Add the "this" pointer offset
    tax             ; Copy the accumulator to the X register
    lda $0, X       ; Get the pointer at the address
    tax             ; Now the pointer is in the X register
    pla
    jsr FUNCTION    ; Call the function
    plx
.endm



;
; Memset a block of memory
; Arguments:
;  - ADDRESS: The address of the memory to memset
;  - VALUE: The value to memset
;  - COUNT: The number of bytes to memset
;  - NAME: The name of the memory for debugging labels
;
.macro Memset ARGS ADDRESS, VALUE, COUNT, NAME
    ldx #(COUNT)                 ; Loop COUNT times
    @Memset_{NAME}:              ; Loop label to memset a specific address
        lda #(VALUE)             ; Set the value to memset
        sta ADDRESS, X           ; Store the value in the memory
        dex                      ; Decrement the counter
        bpl @Memset_{NAME}       ; Branch if positive
.endm