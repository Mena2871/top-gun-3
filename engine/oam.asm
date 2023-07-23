
;
; This module is responsible for managing the OAM object requests. It is meant
; to be used in conjunction with Sprites that need a number of OAM objects to
; represent its sprite. Sprites are expected to call OAMManager_Request() to
; be provided a pointer to an OAM object in RAM. When the Sprite is not needed
; it should call OAMManager_Release() to release the OAM object back to the
; OAMManager.
;
.define MAX_OAM_OBJECTS 128

; OAM page 0 can be aligned at $0000, $2000, $4000, or $6000 word
; OAM page 1 can be aligned at page 0 + $1000, $2000, $3000, or $4000 word
.define OAM_PAGE0_ADDR $6000          ; BBB = 011 ($6000)
.define OAM_PAGE1_ADDR $7000          ; PP  = 00  ($6000 + $1000)
;.define OAM_DEFAULT_OBJSEL %00000011  ; 8x8/16x16 Page 0 @ $6000, Page 1 @ $7000

;  (intentionally aligned with BG1 for testing)
; Remember these are 16-bit word addresses
.define OAM_DEFAULT_OBJSEL %00100011  ; 8x8/16x16 Page 0 @ $6000, Page 1 @ $7000

.struct OAMTable
    low ds 512
    high ds 32
.endst
;
; OAM Object Properties
; This does take up more space, but it is easier to interpret
; when looking at RAM. Use this to create an OAM representation
; in memory and then assign it to the OAM.
;
.struct OAMObject
    index        db  ; This is the 0..127 index of the object
    low_table    db  ; This is the low-table word into the OAM table (128 words)
    high_table   db  ; This is the high-table word into the OAM table (16 words)
    bitmask_size db  ; This is the bitmask for the size of the object
    bitmask_xpos db  ; This is the bitmask for the x position of the object
    allocated    db  ; This flag is true if the object is current bound
    visible      db  ; If 0, the the MSB for the h-position is set to 1 to make it invisible
    size         db  ; 0 = 8x8, 1 = 16x16, 2 = 32x32, 3 = 64x64
    bpp          db  ;
    bx           dw  ; This is the pointer to the base x position of the sprite
    by           dw  ; This is the pointer to the base y position of the sprite
    x            db  ; This is the horizontal position of the sprite
    y            db  ; This is the vertical position of the sprite
    vram         db  ;
    palette      db  ; Color palette to use (0-7)
    priority     db  ; 0 = highest, 3 = lowest
    flip_h       db  ; 0 = normal, 1 = flip
    flip_v       db  ; 0 = normal, 1 = flip
.endst

.enum $0000
    oam_object instanceof OAMObject
.ende

.struct OAMManager
    oam_objects instanceof OAMObject MAX_OAM_OBJECTS ; Represents OAM space
    oam_table instanceof OAMTable
.endst

.ramsection "OAMRAM" appendto "RAM"
    oam_manager instanceof OAMManager
.ends

.section "OAM" BANK 0 SLOT "ROM"

nop

;
; This is stupid, but I don't want to go compute this during the OAM
; write time, so just use a static lookup table
;
OAM_SizeTable:
    .repeat 128
        .db $02, $08, $20, $80
    .endr

OAM_XPosTable:
    .repeat 128
        .db $01, $04, $10, $40
    .endr

;
; OAM Object Properties initialization
; X index register should point to the object
; Initializes the object
;
OAMObject_Init:
    ; Zeroize the object
    A8
    stz oam_object.low_table, X
    stz oam_object.high_table, X
    stz oam_object.bitmask_size, X
    stz oam_object.bitmask_xpos, X
    stz oam_object.allocated, X
    stz oam_object.visible, X
    stz oam_object.size, X
    lda #0
    sta oam_object.x, X
    stz oam_object.y, X
    stz oam_object.vram, X
    stz oam_object.palette, X
    lda #2
    sta oam_object.priority, X
    stz oam_object.flip_h, X
    stz oam_object.flip_v, X
    A16

    ; Pointers to the base x and y position controlling the location of the OAM
    stz oam_object.bx, X
    stz oam_object.by, X

    rts

;
; Iterate through each OAM object and set it to be unused, additionally
; set its index to its position in the array
; Expects X to be set to the address of the OAMManager
;
OAMManager_Init:
    pha
    phy
    phx

    A8
    lda #OAM_DEFAULT_OBJSEL
    sta OBSEL
    A16

    ; Advance the pointer to the first OAM object in the struct
    clc
    lda #oam_manager.oam_objects
    tax

    ; This will be the counter for number of objects
    ldy #0

    @Loop:
        pha
        jsr OAMObject_Init      ; Initialize the current OAM object (X register points to it)

        A8
        tya
        sta oam_object.index, X ; Set the index of the object to its position in the array

        ; Compute word offset into the OAM low table (16 bits per object)
        asl
        sta oam_object.low_table, X

        ; Compute byte offset into the OAM high table (2 bits per object)
        tya
        lsr
        lsr
        sta oam_object.high_table, X

        ; Compute bitmask for the size of the object
        lda OAM_SizeTable, Y
        sta oam_object.bitmask_size, X

        ; Compute bitmask for the x position of the object
        lda OAM_XPosTable, Y
        sta oam_object.bitmask_xpos, X
        A16

        jsr OAM_MarkDirty

        pla
        clc
        adc #_sizeof_OAMObject   ; Advance the pointer
        tax                     ; Make it the new X register
        iny                     ; Advance counter
        cpy #MAX_OAM_OBJECTS    ; Iterate until we filled out the objects
        bne @Loop

    jsr OAMManager_DMA

    plx
    ply
    pla

    rts

OAM_ComputeHighTable:
    pha
    phx
    phy

    ; Set the OAM address for the high table
    lda #0
    A8
    lda oam_object.high_table, X
    tay
    lda oam_manager.oam_table.high.w, Y

    pha

    ; if (oam_object.size == 1)

    @CheckSizeBit:
        lda oam_object.size, X
        cmp #1
        beq @SetSizeBit

    @ClearSizeBit:
        ; ~bitmask_size | OAMDATAREAD
        lda oam_object.bitmask_size, X
        eor #$FF
        and 1, S
        sta 1, S
        bra @CheckXPosBit

    @SetSizeBit:
        lda oam_object.bitmask_size, X
        ora 1, S
        sta 1, S
        bra @CheckXPosBit

    @CheckXPosBit:
        ; if (oam_object.x >= 255)
        lda oam_object.visible, X
        cmp #0
        bne @ClearXPosBit

    @SetXPosBit:
        lda oam_object.bitmask_xpos, X
        ora 1, S
        sta 1, S
        bra @Done

    @ClearXPosBit:
        lda oam_object.bitmask_xpos, X
        eor #$FF
        and 1, S
        sta 1, S
        bra @Done

    @Done:
        pha
        lda oam_object.high_table, X
        tay
        pla
        sta oam_manager.oam_table.high.w, Y

    pla

    A16
    ply
    plx
    pla
    rts

OAM_ComputeLowTable:
    pha
    phx
    phy

    lda #0
    A8
    lda oam_object.low_table, X
    clc
    adc oam_object.low_table, X
    tay

    ; Store the X position
    phy
    lda #0
    ldy oam_object.bx, X
    cpy #0
    beq @SetXPos
    lda $0, Y
    @SetXPos:
        ply
        clc
        adc oam_object.x, X
        sta oam_manager.oam_table.low.w, Y
        iny

    ; Store the Y position
    phy
    lda #0
    ldy oam_object.by, X
    cpy #0
    beq @SetYPos
    lda $0, Y
    @SetYPos:
        ply
        clc
        adc oam_object.y, X
        sta oam_manager.oam_table.low.w, Y
        iny

    ; Store the VRAM address
    lda oam_object.vram, X
    sta oam_manager.oam_table.low.w, Y
    iny

    ; Put the flip into the right place
    ; Rotate the the bits to position 7
    lda oam_object.flip_v, X
    ror ; Rotate puts into carry
    ror ; And then put in position 7
    pha

    ; Put the flip into the right place
    ; Rotate the the bits to position 6
    lda oam_object.flip_h, X
    ror ; Rotate puts into carry
    ror ; And then put into position 6
    ror ;

    pha

    ; Put priority into bits 5, 4
    lda oam_object.priority, X
    rol ; Put next to the color bits
    rol
    rol
    rol
    pha

    ; Put palette into bits 3, 2, 1
    lda oam_object.palette, X
    rol

    ; Or in the priority bits
    eor 1, S

    ; Or in the flip bits
    eor 2, S ; Flip H
    eor 3, S ; Flip V

    sta oam_manager.oam_table.low.w, Y

    ; Pop the stack
    pla ; Priority
    pla ; Flip H

    pla ; Flip V

    A16
    ply
    plx
    pla
    rts

;
; Expects X to be the pointer OAM object
; Will mark the object as dirty and push it onto the queue
;
OAM_MarkDirty:
    jsr OAM_ComputeLowTable
    jsr OAM_ComputeHighTable
    rts

;
; This function will return a pointer to the next free OAM object.
; And mark it allocated. If there are no free OAM objects, then
; it will return 0x0000 into Y. Otherwise it will return the address.
;
OAMManager_Request:
    pha
    phx

    ; Advance the pointer to the first OAM object in the struct
    clc
    lda #oam_manager.oam_objects
    tax

    ; Stupidly simple, just iterate through the OAM objects and
    ; return the first one that is not allocated
    ldy #0

    @FindNextFreeObject:
        ; Check if the object is allocated
        lda oam_object.allocated, X
        and #$00FF
        beq @MarkAllocated

        ; Advance the pointer
        txa
        clc
        adc #_sizeof_OAMObject
        tax

        ; Did we reach the end of the OAM object space?
        iny
        cpy #MAX_OAM_OBJECTS
        beq @OutOfSpace

        ; Continue to the next iteration
        bra @FindNextFreeObject

    ; If we got here, then we found a free object. Mark ita llocated
    @MarkAllocated:
        A8
        lda #1
        sta oam_object.allocated, X
        A16

        ; Return the address of the OAM object
        txy
        bra @Done

    ; If we got here, then we did not find a free object
    @OutOfSpace:
        ldy #0

    ; Common exit point. We do not restore Y because we want to return it.
    @Done:
        plx
        pla

    rts

;
; This function will release an OAM object back to the OAMManager.
; It will mark the OAM object as not allocated.
; Expects Y to be set to the address of the OAM object to release
;
OAMManager_Release:
    pha
    phx
    phy

    A8

    ; Mark the OAM object as not allocated. stz only works with X register.
    tyx
    jsr OAMObject_Init
    stz oam_object.allocated, X

    A16

    ply
    plx
    pla

    rts

OAMManager_DMA:
    phx

    A8

    ; create frame pointer
    phd                     ; push Direct Register to stack
    tsc                     ; transfer Stack to... (via Accumulator)
    tcd                     ; ...Direct Register.

    stz OAMADDH     ; Keep the most significant bit at 0
    stz OAMADDL     ; Set the OAMADDR to the object's word address

    ; set up DMA channel 0 to transfer data to OAMRAM
    lda #%00000010          ; set DMA channel 0
    sta DMAP0
    lda #$04                ; set destination to OAMDATA
    sta BBAD0

    ldx #oam_manager.oam_table ; get address of OAMRAM mirror
    stx A1T0L               ; set low and high byte of address

    stz A1B0               ; set bank to zero, since the mirror is in WRAM
    ldx #(512 + 32)
    stx DAS0L

    lda #$01                ; start DMA transfer

    sta MDMAEN

    ; OAMRAM update is done, restore frame and stack pointer
    pld                     ; restore caller's frame pointer

    A16
    plx                     ; restore old stack pointer
    rts

;
; Render the OAM objects that are allocated
; Expects X to be set to the address of the OAMManager
;
OAMManager_VBlank:
    jsr OAMManager_DMA
    rts
.ends