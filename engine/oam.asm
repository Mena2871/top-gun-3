; What is an object?
; ==================
; Objects are the primitive that associate sprites. Any small graphic that
; can move independent of the background is an object. They can use the
; palettes from 8-15 and are 4BPP that can be 8x8, 16x16, 32x32, 64x64.
;
; Overview
; ========
; The maximum number of objects that can be displayed on the screen is 128.
; A frame can have two sizes of objects and each object can be one of the two
; sizes. Each frame can have 8 color palettes and an object can use one of the
; palettes. Each palette is 16 colors out of 32,768 colors.
;
; During Initial Settings
; =======================
; - Set register <2101H> to set the object size, name select, and base address.
; - Set D1 of register <2133H> to set the object V select.
; - Set D4 of register <212CH> for "Through Main Obj" settings.
;
; During Forced Blank
; ===================
; - Set register <2115H> to set V-RAM address sequence mode. H/L increments.
; - Set register <2116H> ~ <2119H> to set the V-RAM address and data.
; - Transfer all the object character data to VRAM through the DMA registers.
; - Set register <2121H>, <2122H> to set color palette address and data.
;
; During V-BLANK
; ==============
; - Set register <2102H> ~ <2104H> to set OAM address, priority, and data.
; - Transfer object data to OAM via DMA.
;
; OAM Addressing
; ===============
;                              OBJECT 0
;     | 15 | 14 | 13 | 12 | 11 | 10 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;     |----|----|----|----|----|----|---|---|---|---|---|---|---|---|---|---|
; 000 | ~~~~~Object V-Position~~~~~~~~~~~~~ | ~~~~~Object H-Position~~~~~~~ |
;     | 7  | 6  | 5  | 4  | 3  | 2  | 1 | 0 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
; 001 | ~FLIP~  | ~PRIOR~ |    ~COLOR~  | ~~~~~~~~~~~~~~~NAME~~~~~~~~~~~~~~ |
;     | V  | H  | 1  | 0  | 2  | 1  | 0 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;  .    ^         ^         ^             ^
;       |         |         |              \ Character code number
;       |         |         \ Designate palette for the character
;       |          \Determine the display priority when objects overlap
;        \ X-direction and Y-direction flip. (0 is normal, 1 is flip)
;
; Repeats for 128 objects and then addresses 256 - 271 are for extra bits.
;
;  .                          OBJECT 7...0
; 256 | 15 | 14 | 13 | 12 | 11 | 10 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;     |   OBJ7  |  OBJ6   |   OBJ5  |  OBJ4 | OBJ3  | OBJ2  | OBJ1  | OBJ0  |
;     | S  | Z  | S  | Z  | S  | Z  | S | Z | S | Z | S | Z | S | Z | S | Z |
;       ^    ^
;       |    \ Base position of the Object on the H-direction
;       \ Size large/small (0 is small)
;
.section "OAM" bank 0 slot "ROM"
nop

;
; OAM Object Properties
; This does take up more space, but it is easier to interpret
; when looking at RAM. Use this to create an OAM representation
; in memory and then assign it to the OAM.
;
.struct OAMObject
    index        db  ; This is the index of where the object should be in OAM
    visible      db  ; If 0, the the MSB for the h-position is set to 1 to make it invisible
    size         db  ; 0 = 8x8, 1 = 16x16, 2 = 32x32, 3 = 64x64
    bpp          db  ;
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

;
; OAM Object Properties initialization
; X index register should point to the object
; Initializes the object
;
OAMObject_Init:
    ; Zeroize the object
    stz oam_object.index, X
    stz oam_object.visible, X
    stz oam_object.size, X
    stz oam_object.x, X
    stz oam_object.y, X
    stz oam_object.vram, X
    stz oam_object.palette, X
    stz oam_object.priority, X
    stz oam_object.flip_h, X
    stz oam_object.flip_v, X
    rts

;
; Random OAM Object Properties initialization
; X index register should point to the object
; Y should be the index
;
OAMObject_RandomInit:
    ; Zeroize the object
    A8_XY16

    tya
    sta oam_object.index, X

    lda #random(0, 254)
    sta oam_object.x, X

    lda #random(0, 254)
    sta oam_object.y, X

    lda #1
    sta oam_object.visible, X

    lda #8
    sta oam_object.bpp, X

    lda #random(0, 3)
    sta oam_object.vram, X
    stz oam_object.size, X

    lda #random(0, 1)
    sta oam_object.flip_h, X

    lda #random(0, 1)
    sta oam_object.flip_v, X

    lda #random(0, 3)
    sta oam_object.priority, X

    ;lda #random(0, 7)
    stz oam_object.palette, X

    A16_XY16
    rts

;
; Write an OAMObject to OAM
; X index register should point to the object
;
OAMObject_Write:
    ; Prepare the bytes to write to OAM
    lda #0
    A8_XY16

    ; Prepare the OAM address
    phx
    lda oam_object.index, X
    tax
    ldy #0
    jsr OAM_Index
    plx

    ; Store the X position
    lda oam_object.x, X
    sta OAMDATA

    ; Store the Y position
    lda oam_object.y, X
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

    A16_XY16
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
    jsr OAM_Test

    stz OAMADDH         ; Set the OAMADDR to 0
    stz OAMADDL         ; Set the OAMADDR to 0
    stz OBSEL           ; Reinitialize object select
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
    rts
;
; Get the index of the OAM address for the object.
; X index register should be the object's id (0..127)
; Y index register should be word offset (0 or 1)
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
    A8_XY16
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

    A16_XY16
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
.ends