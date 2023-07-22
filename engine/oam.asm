
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
    dirty        db  ; This flag is true if the object has been modified
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

    ; Queue of OAM objects that need to be updated
    oam_queue instanceof Queue
    oam_queue_memory  ds (2 * MAX_OAM_OBJECTS)

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
    lda #255
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
; Write an OAMObject to OAM
; X index register should point to the object
;
OAMObject_Write:
    jsr OAMObject_WriteLowTable
    jsr OAMObject_WriteHighTable
    rts

OAMObject_WriteHighTable:
    pha
    phx
    phy

    ; Set the OAM address for the high table
    A8
    lda #1
    sta OAMADDH

    lda oam_object.high_table, X
    lsr
    sta OAMADDL

    ; Read the current value of the high table (includes other OAM data)
    ; If the low bit is set, then we need to read twice since it is a 16-bit word
    lda oam_object.high_table, X
    and #$1
    beq @ReadOnce
    lda OAMDATAREAD
    @ReadOnce:
        lda OAMDATAREAD

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
        A16
        lda oam_object.x, X
        cmp #$FF
        A8
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
        lsr
        sta OAMADDL

        ; Similar to before, figure out if we are doing a read/write or write
        lda oam_object.high_table, X
        and #$1
        beq @WriteData

        @ReadThenWrite:
            lda OAMDATAREAD

        @WriteData:
            ; Write data
            pla
            sta OAMDATA
        pla

    A16
    ply
    plx
    pla
    rts

OAMObject_WriteLowTable:
    pha
    phy

    ; Prepare the bytes to write to OAM
    ; Prepare the OAM address
    phx
    lda oam_object.index, X
    and #$00FF
    tax

    ldy #0
    jsr OAM_Index
    plx

    A8

    ; Store the X position
    lda #0
    ldy oam_object.bx, X
    cpy #0
    beq @SetXPos
    lda $0, Y
    @SetXPos:
        adc oam_object.x, X
        sta OAMDATA

    ; Store the Y position
    lda #0
    ldy oam_object.by, X
    cpy #0
    beq @SetYPos
    lda $0, Y
    @SetYPos:
        adc oam_object.y, X
        sta OAMDATA

    ; Store the VRAM address
    lda oam_object.vram, X
    sta OAMDATA

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

    ; Write to OAM
    sta OAMDATA

    ; Pop the stack
    pla ; Priority
    pla ; Flip H 
    pla ; Flip V

    A16
    ply
    pla
    rts

OAM_Test:
    ldx #0
    jsr OAM_GetColor
    lda #$3
    jsr OAM_SetColor

    ldx #1
    jsr OAM_GetColor
    ldx #2
    jsr OAM_GetColor

    rts
;
; Reinitialize all objects in the OAM
;
OAM_Init:
    pha
    phx
    phy

    jsr OAM_Test

    A8

    stz OAMADDH         ; Set the OAMADDR to 0
    stz OAMADDL         ; Set the OAMADDR to 0

    ; Setup the default object selection of OAM address pages.
    lda #OAM_DEFAULT_OBJSEL
    sta OBSEL

    ; Clear out the standard 4 bytes for each object
    ; This will clear OAM address data 000 - 255 for D15 - D0
    ldx #128            ; 128 objects
    @LoopRegion1:
        stz OAMDATA     ; Clear X
        stz OAMDATA     ; Clear Y
        stz OAMDATA     ; Clear tile name
        stz OAMDATA     ; Clear last bit of name, color, obj, flip
        dex
        bne @LoopRegion1
    ; Clear out the size and extra X bit for each object
    ; This will clear OAM address data 256 - 271 for D15 - D0
    ldx #(128 / 8)       ; 128 objects for the SX bits (8 objects per word)
    @LoopRegion2:
        stz OAMDATA     ; Clear SZ bits for OBJ 0 ... 7
        stz OAMDATA
        dex
        bne @LoopRegion2
    stz OAMADDH         ; Set the OAMADDR to 0
    stz OAMADDL         ; Set the OAMADDR to 0

    A16
    ply
    plx
    pla
    rts
;
; Get the index of the OAM address for the object.
; X index register should be the object's id (0..127)
; Accumulator is set to the OAM address.
;
OAM_Index:
    phy
    phx
    txa             ; Object offset (not word offset)
    clc             ; Don't care about any existing carry
    asl             ; Multiply object id by 2 (now word offset for the base object address)
    clc             ; Don't care about the carry
    adc 3, S        ; Add the extra word offset
    clc
    stz OAMADDH     ; Keep the most significant bit at 0
    sta OAMADDL     ; Set the OAMADDR to the object's word address
    plx
    ply
    rts
;
; Get the 3-bit value of the palette an object is using.
;
; X index register should be the object's id (0..127)
; Accumulator will have the palette value
;
OAM_GetColor:
    phy
    ldy #1          ; Get the word offset for the color palette data
    jsr OAM_Index
    lda OAMDATAREAD ; Ignore the first byte of the word
    lda OAMDATAREAD ; This has the byte we care about
    ror             ; Shift the palette bits to the right
    ror             ; Shift the palette bits to the right
    and #$3         ; Mask the palette bits
    ply
    rts

;
; Set the 3-bit value of the palette an object is using.
;
; X index register should be the object's id (0..127)
; Accumulator should have the palette value
;
OAM_SetColor:
    ; Left shift two bits
    A8
    phy
    asl
    asl

    ; Mask off any other bits
    and #$C

    ; Save the result
    pha

    ldy #1          ; Get the word offset for the color palette data
    jsr OAM_Index
    pha             ; Save accumulator which has the OAM address

    ; Read the OAM data so we can write it back (remember it is 16-bit word)
    lda OAMDATAREAD ; We need to read the first byte of the word and write it back
    pha
    lda OAMDATAREAD ; This has the byte we care about
    pha

    ; Reset the OAM address
    lda 3, S        ; Get the OAM index address
    stz OAMADDH     ; Keep the most significant bit at 0
    sta OAMADDL     ; Set the OAMADDR to the object's word address

    ; Write back the first byte
    lda 2, S
    sta OAMDATA

    ; Get the second byte (which has color data)
    pla

    ; Mask away only the color bits
    and #$F3

    ; And or them in with the prepared accumulator
    ora 3, S

    ; Write back the result
    sta OAMDATA

    pla ; Old value of the first byte
    pla ; OAM index offset
    pla ; Manipulated accumulator passed in
    ply ; Restore Y passed into function

    A16
    rts

;
; Get the Name (000H - 1FFH) of the object
; X index register should be the object's id (0..127)
; Accumulator will have the palette value
;
OAM_GetName:
    phy
    ldy #1          ; Get the word offset for the name data
    jsr OAM_Index
    lda OAMDATAREAD ; The first two bytes have the data we care about
    xba             ; Flip the byte and re-read the next byte and swap back
    lda OAMDATAREAD ; Read second byte
    xba             ; Flip the byte back
    and #$2         ; Mask off the all the fields we don't care about
    ply
    rts
;
; Get the Object's size (big or small)
; X index register should be the object's id (0..127)
; Accumulator will have Object's size state.
;
OAM_GetSize:
    rts
;
; Get the object is flipped horizontally
; X index register should be the object's id (0..127)
; Accumulator will have Object's horizontal state.
;
OAM_GetFlipHorizontal:
    phy
    ldy #1          ; Get the word offset for the horizontal
    jsr OAM_Index
    lda OAMDATAREAD ; Ignore the first byte of the word
    lda OAMDATAREAD ; This has the byte we care about
    bit #$40        ; Test the horizontal bit
    beq @NoFlip     ; If it's not set, then we're not flipped
    lda #$1
    ply
    rts
    @NoFlip:
        lda #$0
        ply
        rts
    rts
;
; Get the object is flipped vertically
; X index register should be the object's id (0..127)
; Accumulator will have Object's vertical state.
;
OAM_GetFlipVertical:
    phy
    ldy #1          ; Get the word offset for the vertical
    jsr OAM_Index
    lda OAMDATAREAD ; Ignore the first byte of the word
    lda OAMDATAREAD ; This has the byte we care about
    bit #$80        ; Test the vertical bit
    beq @NoFlip     ; If it's not set, then we're not flipped
    lda #$1
    ply
    rts
    @NoFlip:
        lda #$0
        ply
        rts
;
; Get the object priority.
; X index register should be the object's id (0..127)
; Accumulator will have Object's priority.
;
OAM_GetPriority:
    phy
    ldy #1          ; Get the word offset for the priority
    jsr OAM_Index
    lda OAMDATAREAD ; Ignore the first byte of the word
    lda OAMDATAREAD ; This has the byte we care about
    and #$30        ; Mask off non-priority bits
    lsr             ; Shift priority into the right place
    lsr
    lsr
    ply
    rts
;
; Get the object position.
; X index register should be the object's id (0..127)
; Accumulator will have Object's X position.
;
OAM_GetX:
    phy
    ldy #0          ; Horizontal position is in word 0
    jsr OAM_Index
    lda OAMDATAREAD ; This has the byte we care about
    ply
    rts
;
; Get the object position.
; X index register should be the object's id (0..127)
; Accumulator will have Object's Y position.
;
OAM_GetY:
    phy
    ldy #0          ; vertical position is in word 0
    jsr OAM_Index
    lda OAMDATAREAD ; Ignore horizontal position
    lda OAMDATAREAD ; This has the byte we care about
    ply
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

    ; Initialize the OAM space
    jsr OAM_Init

    ; Initialize the queue
    lda #oam_manager.oam_queue_memory       ; Set the base address of the queue  
    sta oam_manager.oam_queue.start_addr.w  ; Store it in the OAMManager struct

    ; Calculate the end address of the queue
    clc
    adc #(MAX_OAM_OBJECTS * 2)              ; Calculate the end address
    sta oam_manager.oam_queue.end_addr.w    ; Store it in the OAMManager struct

    ; Set the element size to 2 bytes
    lda #2                                   ; Set the element size in bytes
    sta oam_manager.oam_queue.element_size.w ; Store it in the OAMManager struct

    ; Initialize the queue
    ldx #oam_manager.oam_queue               ; Set the Queue "this" pointer
    jsr Queue_Init

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

        ; Compute word offset into the OAM high table (2 bits per object)
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

        jsr OAMObject_Write

        pla
        clc
        adc #_sizeof_OAMObject   ; Advance the pointer
        tax                     ; Make it the new X register
        iny                     ; Advance counter
        cpy #MAX_OAM_OBJECTS    ; Iterate until we filled out the objects
        bne @Loop 

    plx
    ply
    pla

    rts

;
; Expects X to be the pointer OAM object
; Will mark the object as dirty and push it onto the queue
;
OAM_MarkDirty:
    pha
    phx
    phy

    ; if (oam_object.dirty)
    ;     return
    A8
    lda oam_object.dirty, X
    cmp #1
    beq @Done
    A16

    ; Queue_Push(&Y) (this = X)
    phx
    ldx #oam_manager.oam_queue
    jsr Queue_Push

    ; if (oam_queue.error == QUEUE_ERROR_FULL)
    ;    return
    lda queue.error.w, X
    cmp #QUEUE_ERROR_FULL
    bne @SavePointer
    plx
    bra @Done

    ; else update the Y pointer to point to the OAM object
    @SavePointer:
    plx
    txa
    sta $0, Y

    A8
    lda #1
    sta oam_object.dirty, X
    A16

    @Done:
        A16
        ply
        plx
        pla
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
        clc
        txa
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

;
; Render the OAM objects that are allocated
; Expects X to be set to the address of the OAMManager
;
OAMManager_VBlank:
    pha
    phx
    phy

    @Next:
        ldx #oam_manager.oam_queue
        jsr Queue_Pop

        ; if (oam_queue.error == QUEUE_ERROR_EMPTY)
        lda queue.error.w, X
        cmp #QUEUE_ERROR_EMPTY
        beq @Done

        ; Transfer Y to X for pointer math
        lda $0, Y
        tax

        ; If we got here, then we found a dirty object. Render it.
        jsr OAMObject_Write
        A8
        stz oam_object.dirty, X
        A16
        bra @Next

    @Done:
        ply
        plx
        pla
    rts
.ends