
.define CGRAM_ALLOCATED 0x1
.define CGRAM_PALETTES 8

.ramsection "CGRAMManagerRAM" appendto "RAM"
    cgram_bg_manager ds CGRAM_PALETTES
    cgram_sprite_manager ds CGRAM_PALETTES
.ends

.section "CGRAM" bank 0 slot "ROM"

;
; Initializes both the background and sprite CGRAM managers
;
CGRAMManager_Init:
    pha
    phx

    lda #0

    A8
    ldx #0
    @LoopBG:
        asl
        sta cgram_bg_manager.w, X
        inx
        txa
        cpx #CGRAM_PALETTES
        bne @LoopBG

    lda #CGRAM_PALETTES
    ldx #0
    @LoopSprite:
        asl
        sta cgram_sprite_manager.w, X
        inx
        txa
        cpx #CGRAM_PALETTES
        bne @LoopSprite

    A16

    plx
    pla
    rts

;
; Request a new CGRAM index for either a background or sprite element
; Expects X to be the index of the CGRAMManager to use
; Returns Y as the index of the CGRAM entry
;
CGRAMManager_Request:
    pha
    phx

    ; Stupidly simple, just iterate through the cgram entries and
    ; return the first one that is not allocated
    ldy #0
    lda #0

    A8

    @FindNextFreeObject:
        ; Check if the sprite descriptor is allocated
        lda 0, X
        and #CGRAM_ALLOCATED
        beq @MarkAllocated

        ; Advance the pointer
        inx

        ; Did we reach the end of the sprite object space?
        iny
        cpy #CGRAM_PALETTES
        beq @OutOfSpace

        ; Continue to the next iteration
        bra @FindNextFreeObject

    ; If we got here, then we found a free object. Mark it allocated
    @MarkAllocated:
        lda 0, X
        eor #CGRAM_ALLOCATED
        sta 0, X
        tay
        bra @Done

    ; If we got here, then we did not find a free object
    @OutOfSpace:
        ldy #0

    ; Common exit point. We do not restore Y because we want to return it.
    @Done:
        A16
        plx
        pla
        rts

;
; Converts a CGRAM index to a palette index
; Expects Y to be the CGRAM index
; Puts result into the accumulator
;
CGRAM_Index:
    phy

    lda #0

    A8
    tya
    and #$FE ; Mask off the allocated bit
    asl ; Left shift 3x to convert to palette index
    asl
    asl
    A16

    ply
    rts

.ends