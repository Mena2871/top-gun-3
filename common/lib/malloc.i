
.ACCU	16
.INDEX	16

.struct Malloc
    size dw ; Size of the current malloc
    next dw ; Pointer to the next free memory
.endst

.section "Malloc" BANK 0 SLOT "ROM"
;
;  @example
;      jsr Malloc_Init
;
Malloc_Init:
    lda #(malloc.size + _sizeof_Malloc)
    sta malloc.next
    stz malloc.size
    rts

;  @example
;      lda #50 ; 50 bytes
;      jsr Malloc_Bytes
;      ; X now holds your pointer
;
Malloc_Bytes:
    ; Push return value
    ldx malloc.next

    pha             ; Store the desired malloc size to malloc.size as a placeholder

    ; Advance the next pointer
    lda malloc.next ; Put the start address into the accumulator
    clc             ; Clear carry flag
    adc 1, S        ; Add the malloc size to the accumulator to advance the pointer
    ina             ; Increment the accumulator to account for the size of the malloc
    tay             ; Put the end address into the Y register
    sta malloc.next ; Store the new pointer

    ; Zero memory
    lda 1, S
    tay
    lda #$0000
    jsr Memset

    pla
    rts

;
; Memset an address range with a value
; Arguments:
;  X: Start address
;  Y: Num bytes
;  A: Value to write
;
Memset:
    phx             ; Save the start address of the memory
    phy             ; Save the end address of the memory
    pha             ; Save the value to write

    A8
    @Loop:
        sta $0, X
        inx
        dey
        bne @Loop
    A16

    pla
    ply
    plx
    rts

.ends