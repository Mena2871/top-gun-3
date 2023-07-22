.ACCU   16
.INDEX  16
.16bit

;
; Background tile data
;
.struct Tile
    id          dw ; 10-bit ID of the tile
    index       dw ; 8x8 32-width index
.endst

;
; Represents a background layer in the map
;
.struct Background
    id          dw    ; 8-bit ID of the background layer (1..4)
    num_tiles   dw    ; Number of tiles in the background
    data        db    ; Where all the tile data starts
.endst

;
; Expects a packed tileset in the following format:
;
.struct SpriteSheet
    magic       ds 3  ; "SPR"
    bpp         db ; Bits per pixel
    size        dw ; Total number of bytes in this sheet
    width       db ; Width in pixels per tile
    height      db ; Height in pixels per tile
    num_rows    db ; Number of rows in the tileset
    num_cols    db ; Number of columns in the tileset
    data        db ; Where the tile data starts
.endst

;
; Palette data is stored in the following format:
;
.struct Palette
    magic       ds 3  ; "PAL"
    num_colors  db ; Number of colors in the palette
    size        dw ; Total number of bytes in this palette
    data        db ; Where the palette data starts
.endst

;
; Map data is stored in the following format:
;
.struct Map
    magic               ds 3    ; "TMX"
    version             db      ; Version of the map format
    name                ds 16   ; Name of the map
    num_backgrounds     db      ; Number of objects in the map
    num_objects         db      ; Number of objects in the map
    tile_width          db      ; Width of a tile in pixels
    tile_height         db      ; Height of a tile in pixels
    height              db      ; Height in tiles of tile_height
    width               db      ; Width in tiles of tile_width
    ; These are all relative to the start of the map struct
    background_offset   dw      ; Where all the tile data starts
    sprite_offset       dw      ; Where all the map data starts
    palette_offset      dw      ; Where all the palette data starts
    object_offset       dw      ; Where all the objects in the map go
.endst

;
; Map manager object
; Used to manage loading and manipulating the current map
; 
.struct MapManager
    cgram_index    db   ; 8-bit index of the palette in cgram
    map_bank       db   ; 8-bit bank number of the map
    map_ptr        dw   ; 16-bit pointer to the map struct
.endst

; Intentionally offset at $0000 since we will use the X register to
; point to the map struct when allocated
.enum $0000
    map instanceof Map
.ende
.enum $0000
    sprite_sheet instanceof SpriteSheet
.ende
.enum $0000
    palette instanceof Palette
.ende
.enum $0000
    tile instanceof Tile
.ende
.enum $0000
    bg_layer instanceof Background
.ende

.ramsection "MapRAM" appendto "RAM"
    map_manager instanceof MapManager
.ends

.section "Map" bank 0 slot "ROM"

nop

;
; Initialize the map manager
; Expects X register to be the pointer to the map manager
;
MapManager_Init:
    pha

    A8
    stz map_manager.map_bank ; Bank

    A16
    stz map_manager.map_ptr.w ; High

    pla
    rts

;
; Expects X register to be the pointer to the map manager
; Expects Y register to be the 16-bit map pointer
; Expects A register to be the 8-bit bank number
MapManager_Load:
    phb
    A8
    sta map_manager.map_bank ; Bank

    ; Store the high and low bits of the map pointer
    A16
    phy ; Save the Y register so we can put it into the accumulator later
    tya ; Transfer the 16-bit pointer to the accumulator
    sta map_manager.map_ptr.w ; High + Low

    ; Set the data bank register to the correct bank
    A8
    lda map_manager.map_bank
    pha
    plb

    ; Set the X register to point to the map struct in the correct bank
    A16
    pla ; This will put the 16-bit map pointer into the accumulator
    tax ; Transfer the accumulator to the X register for indexing

    ; Call the map init routine
    jsr Map_Init

    plb
    rts

;
; Load map data at the X register offset
; Expects that X register points to the map struct
;
Map_Init:
    phy
    phx
    A8

    @CheckMapMagicNumber:
        txy
        lda map.magic, Y
        cmp #ASC('T')
        bcc @Error_BadMagic
        iny

        lda map.magic, Y
        cmp #ASC('M')
        bcc @Error_BadMagic
        iny

        lda map.magic, Y
        cmp #ASC('X')
        bcc @Error_BadMagic
        iny

    @CheckSpriteMagicNumber:
        A16
        clc
        lda map.sprite_offset, X
        adc 1, S
        tay
        A8

        lda sprite_sheet.magic, Y
        cmp #ASC('S')
        bcc @Error_BadMagic
        iny

        lda sprite_sheet.magic, Y
        cmp #ASC('P')
        bcc @Error_BadMagic
        iny

        lda sprite_sheet.magic, Y
        cmp #ASC('R')
        bcc @Error_BadMagic
        iny

    @CheckPaletteMagicNumber:
        A16
        clc
        lda map.palette_offset, X
        adc 1, S
        tay
        A8

        lda palette.magic, Y
        cmp #ASC('P')
        bcc @Error_BadMagic
        iny

        lda palette.magic, Y
        cmp #ASC('A')
        bcc @Error_BadMagic
        iny

        lda palette.magic, Y
        cmp #ASC('L')
        bcc @Error_BadMagic
        iny

    @MagicSuccess:
        A16
        lda 3, S
        tay
        jsr Map_Load

    @Error_BadMagic:
        nop

    A16
    plx
    ply
    rts

;
; This routine is called after the magic number has been checked
; Arguments:
;  X = Pointer to the map struct
;  Y = Pointer to the engine object
;
; It will load:
; (1) The tile data from the map into vram
; (2) The palette data into cgram
;
Map_Load:
    A16
    phy
    phx

    ; Prepare the X register to point to the sprite data
    clc
    lda map.sprite_offset, X
    adc 1, S
    tax
    jsr Map_LoadSprites

    ; Bounce the stack X register for getting objects again
    lda 1, S
    tax

    ; Prepare the X register to point to the palette data
    ; Keep the Y register as the engine pointer
    clc
    lda map.palette_offset, X
    adc 1, S
    tax
    jsr Map_LoadPalettes

    ; Bounce the stack X register for getting objects again
    lda 1, S
    tax

    ; There is far more setup for loading tiles, so pass
    ; the Map object to it
    jsr Map_LoadBackgrounds

    ; Restore the stack
    plx
    ply
    rts

;
; Loads the sprites from the map into vram
; Expects that X register points to the sprite sheet object
; Expects that Y register points to the engine object
; Does not need to preserve any register.
;
Map_LoadSprites
    ; This will manipulate the X register, so we need to save it
    phy
    phx

    ; Transfer the size of the sprite sheet into the X register
    ; as a counter for reading data
    lda sprite_sheet.size, X
    tay

    ; Start loading the sprite sheet data into VRAM
    ; Expects Y register to be the number of words to allocate
    jsr BGManager_BG1Next

    ; Restore X register
    lda 1, S
    tax

    A8

    @VRAMLoop:                      ; Loop through all X bytes of sprite data
        lda sprite_sheet.data.w, X    ; Load bitplane 0/2
        sta VMDATAL                 ; Store data to VRAM
        inx                         ; Increment X register for the data
        dey                         ; Decrement loop counter
        lda sprite_sheet.data.w, X    ; Load bitplane 1/3
        sta VMDATAH                 ; Store data to VRAM
        inx                         ; Increment X register for the data
        dey                         ; Decrement loop counter
        bne @VRAMLoop               ; Loop if we haven't reached 0

    ; Set the background registers
    A16
    ply
    plx
    rts

;
; Read all the palette data from the map into cgram
; Expects that X register points to the palette object
; Expects that Y register points to the engine object
; Does not need to preserve any register.
;
Map_LoadPalettes:
    A16
    phx
    phy

    ; Request a palette from the CGRAM manager
    ldx #cgram_bg_manager
    jsr CGRAMManager_Request
    tya

    ; Store the palette index in the map manager
    A8
    sta map_manager.cgram_index
    A16

    ; Convert the palette index to a CGRAM address
    ; Expects the Y register to be the palette index
    jsr CGRAM_Index

    ; Bounce the stack
    ply
    plx
    phx
    phy

    ; Transfer the size of the palette into the X register
    ; as a counter for reading data
    ;lda palette.size, X

    A8
    sta CGADD                   ; Set CGADD to requested bg cgram index
    ldy #$20
    @BGCGRAMLoop:               ; Loop through all X bytes of color data
        lda palette.data, X     ; Low byte color data
        sta CGDATA              ; Store data to CGRAM
        inx                     ; Increment data offset
        dey                     ; Decrement counter
        lda palette.data, X     ; High byte color data
        sta CGDATA              ; Store data to CGRAM
        inx                     ; Increment data offset
        dey                     ; Decrement counter
        bne @BGCGRAMLoop        ; Loop if not

    A16
    ply
    plx
    rts

;
; Read all backgrounds from the map into vram
;
Map_LoadBackgrounds:
    phy
    phx
    pha

    ; Put the number of tiles on the stack
    lda map.num_backgrounds, X
    and #$FF
    tay

    ; Now, we need to load the tilemap data into VRAM
    clc
    lda map.background_offset, X
    adc 1, S
    tax

    @Loop:
        cpy #$00
        beq @Done

        lda bg_layer.id, X
        cmp #$01
        beq @BG1
        bra @BG2

        @BG1:
            lda #BG1_TILEMAP_VRAM
            bra @LoadTiles

        @BG2:
            lda #BG2_TILEMAP_VRAM
            bra @LoadTiles

        @LoadTiles:
            jsr Map_LoadTiles
            dey
            bra @Loop

    @Done:
        pla
        plx
        ply
        rts

;
; Read all the tiles data from the map into bgmap
; Expects that A register points to the background tilemap VRAM
; Expects that X register points to the background layer object
; Does not need to preserve any register.
;
Map_LoadTiles:
    phy
    pha

    ; 8-bit background mode for all modes
    A8
    lda #$80
    sta VMAIN

    A16
    ; Put the number of tiles on the stack
    lda bg_layer.num_tiles, X
    tay

    ; First get the bgtile offset (which is end of background)
    clc
    txa
    adc #bg_layer.data
    tax

    @LoadTile:
        ; Set the tilemap address
        clc
        lda tile.index.w, X
        adc 1, S
        sta VMADDL

        ; Save tile reference
        lda tile.id.w, X
        A8
        sta VMDATAL
        xba
        sta VMDATAH
        A16

        ; Advance the pointer
        txa
        adc #(_sizeof_Tile)
        tax

        ; Decrement the counter and update stack value
        dey
        bne @LoadTile

    ; Restore the stack
    pla
    ply

    rts

.8bit
.ends