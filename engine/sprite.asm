; Where in VRAM we will store our spritesheets
.define SPRITE_CHAR_VRAM $6000
.define SPRITE_SIZE $2000
.define MAX_SPRITE_OBJECTS 4

;
; A Tile is a single SNES object that makes up a larger sprite.
; This is the fundamental unit of a sprite. It is either large or small.
;
; [Tile]
; |_Program RAM Address
; |_OAM Size
; |_Relative X Position
; |_Relative Y Position
;
.struct TileHeader
    magic          ds  3 ; Magic string "TIL"
    prog_ram_addr  db ; Address of tile data in program RAM
    oam_size       db ; Size of OAM entry (small or large)
    rx             db ; Relative X position of tile to the layer
    ry             db ; Relative Y position of tile to the layer
.endst
.enum $0000
    tile_hdr instanceof TileHeader
.ende

;
; A Layer is a collection of tiles that make up a single SNES object.
;
; [Layer]
; |_Layer ID
; |_Relative X Position
; |_Relative Y Position
; |_Number of Tiles
; |_[Tile Data]
;   |_Tile1
;   |_ ...   => VRAM Addresses
;   |_TileN
; 
.struct LayerHeader
    magic          ds  3 ; Magic string "LYR"
    layer_id       db ; Layer index mapping to a layer object (with metadata)
    rx             db ; Relative X position of layer to the sprite
    ry             db ; Relative Y position of layer to the sprite
    tile_count     db ; Number of tiles in this layer
    tile_offset    dw ; Start of tile data
    data           db ; Start of data
    ; [Tile Data]
.endst
.enum $0000
    layer_hdr instanceof LayerHeader
.ende

;
; A Frame is a collection of layers that make up a single SNES object.
; This metadata is used to inform where the layers are in program ROM.
;
;
.struct FrameLayerMetadataHeader
    magic          ds  3 ; Magic string "FLM"
    layer_id       db ; Layer index mapping to a layer object (with metadata)
    offset         dw ; Offset to the layer data
.endst
.enum $0000
    frame_layer_metadata_hdr instanceof FrameLayerMetadataHeader
.ende

;
; A Frame is a collection of layers that make up a single SNES object.
;
; [Frame]
; |_Layer1
; | |_Tile1
; | |_ ...   => VRAM Addresses
; | |_TileN
; |_ ...
; |_LayerN
;
.struct FrameHeader
    magic                 ds 3  ; Magic string "FRM"
    num_layers            db    ; Number of layers in this frame
    frame_layer_metadata_count  db    ; Number of layer metadata objects
    frame_layer_metadata_offset dw    ; Start of layer metadata
    layer_count           db    ; Number of layers in this frame
    layer_offset          dw    ; Start of layer data
    data                  db    ; Start of data
    ; [Frame Layer Metadata Data]
    ; [Layer Data]
.endst
.enum $0000
    frame_hdr instanceof FrameHeader
.ende

;
; A Tag is a collection of frames that make up a single SNES object.
; This metadata is used to inform where the frames are in program ROM.
;
.struct TagFrameMetadataHeader
    magic          ds  3 ; Magic string "TFM"
    offset         dw ; Offset to the frame data
.endst
.enum $0000
    tag_frame_metadata_hdr instanceof TagFrameMetadataHeader
.ende

;
; A Tag is a collection of frames that make up a single SNES object.
;
; [Tag]
; |_Frame1
; | |_Layer1
; | | |_Tile1
; | | |_ ...   => VRAM Addresses
; | | |_TileN
; | |_ ...
; | |_LayerN
; |_ ...
; |_FrameN
;
.struct TagHeader
    magic               ds 3 ; Magic string "TAG"
    direction             db ; Animation direction (forward, reverse, ping-pong)
    oam_count             db ; Number of OAMs needed to represent this tag
    frame_metadata_count  db ; Number of frame metadata objects
    frame_metadata_offset dw ; Start of frame metadata
    frame_count           db ; Number of frames in this tag
    frame_offset          dw ; Start of frame data
    data                  db ; Start of data
    ; [Frame Metadata Data]
    ; [Frame Header Data]
.endst
.enum $0000
    tag_hdr instanceof TagHeader
.ende

;
; A Tag is a collection of frames that make up a single SNES object.
; This metadata is used to inform where the tags are in program ROM.
;
.struct TagMetadataHeader
    magic          ds  3 ; Magic string "TMD"
    offset         dw ; Offset to the tag data
.endst
.enum $0000
    tag_metadata_hdr instanceof TagMetadataHeader
.ende


;
; A Sprite is a collection of tags that make up a single SNES object.
;
; [Sprite]
; |_Sheet Data
; |_Tag1
; | |_Frame1
; | | |_Layer1
; | | | |_Tile1
; | | | |_ ...   => VRAM Addresses
; | | | |_TileN
; | | |_ ...
; | | |_LayerN
; | |_ ...
; | |_FrameN
; |_ ...
; |_TagN
;
.struct SpriteHeader
    magic                   ds 3 ; Magic string "SPR"
    name                    ds 8 ; Name of the sprite
    pal_data_count          dw ; Number of 16-bit words in the pal sheet
    pal_data_offset         dw ; Start of paldata
    sheet_data_count        dw ; Number of 16-bit words in the sprite sheet
    sheet_data_offset       dw ; Start of sheet data
    tag_metadata_count      db ; Number of tag metadata objects
    tag_metadata_offset     dw ; Start of tag metadata
    tag_count               db ; Number of tags in this sprite
    tag_offset              dw ; Start of tag data
    data                    db ; Start of data
    ; [Palette Data]
    ; [Sheet Data]
    ; [Tag Metadata Data]
    ; [Tag Data]
.endst
.enum $0000
    sprite_hdr instanceof SpriteHeader
.ende

;
; Overarching sprite object that contains all the metadata and pointers
; to the sprite data.
;
.struct SpriteDescriptor
    allocated  db      ; 8-bit flag to indicate if the sprite is allocated
    dirty      db      ; 8-bit flag to indicate if the sprite needs to be rendered
    x          db      ; 8-bit X position of the sprite
    y          db      ; 8-bit Y position of the sprite
    bank       db      ; 8-bit bank number of the sprite
    ptr        dw      ; 16-bit pointer to the sprite data
    vram       dw      ; 16-bit pointer to the sprite data in VRAM
    tag        dw      ; 16-bit pointer to the active tag
    oams       ds  64  ; Array of 32 16-bit OAM pointers
    oam_count  dw      ; Number of active OAMs
    frame      dw      ; 16-bit pointer to the active frame
    frame_idx  dw      ; 16-bit index of the active frame
    tiles      ds  64  ; Array of 32 16-bit tile pointers
    tile_count dw      ; Number of tiles in the active frame
    cgram_index db     ; 8-bit index of the palette in CGRAM
.endst
.enum $0000
    sprite_desc instanceof SpriteDescriptor
.ende

;
; A SpriteManager is a collection of sprites that make up a single SNES object.
;
.struct SpriteManager
    sprites instanceof SpriteDescriptor MAX_SPRITE_OBJECTS 
    ; Queue of sprite objects that need to be updated
    sprite_queue instanceof Queue
    sprite_queue_memory  ds (2 * MAX_SPRITE_OBJECTS)

.endst

.ramsection "SpriteRAM" appendto "RAM"
    sprite_manager instanceof SpriteManager
.ends

.section "Sprite" bank 0 slot "ROM"

;
; Initialize the sprite manager
;
SpriteManager_Init:
    pha
    phx

    ; Prep the VRAM space for the sprites. The current design documents
    ; state that sprites will be loaded into VRAM starting at $6000.
    ; We'll give 2KB blocks to each Sprite object.
    A16

    ; Initialize the queue
    lda #sprite_manager.sprite_queue_memory       ; Set the base address of the queue  
    sta sprite_manager.sprite_queue.start_addr.w  ; Store it in the OAMManager struct

    ; Calculate the end address of the queue
    clc
    adc #(MAX_SPRITE_OBJECTS * 2)              ; Calculate the end address
    sta sprite_manager.sprite_queue.end_addr.w    ; Store it in the OAMManager struct

    ; Set the element size to 2 bytes
    lda #2                                   ; Set the element size in bytes
    sta sprite_manager.sprite_queue.element_size.w ; Store it in the OAMManager struct

    ; Initialize the queue
    ldx #sprite_manager.sprite_queue               ; Set the Queue "this" pointer
    jsr Queue_Init

    ldy #0

    ; Setup the memory for us to iterate through the sprite objects
    lda #sprite_manager.sprites
    tax

    clc
    lda #SPRITE_CHAR_VRAM

    @Loop:
        ; Check if the sprite descriptor is allocated
        stz sprite_desc.ptr
        stz sprite_desc.oam_count

        sta sprite_desc.vram, X
        adc #SPRITE_SIZE

        A8
        stz sprite_desc.allocated
        stz sprite_desc.bank

        A16
        ; Advance the pointer
        clc
        txa
        adc #_sizeof_SpriteDescriptor
        tax

        ; Did we reach the end of the sprite object space?
        iny
        cpy #MAX_SPRITE_OBJECTS
        beq @Done

        ; Continue to the next iteration
        bra @Loop

    @Done:
        plx
        pla
        rts

;
; This function will return a pointer to the next free Sprite object.
; And mark it allocated. If there are no free Sprite objects, then
; it will return 0x0000 into Y. Otherwise it will return the address.
;
SpriteManager_Request:
    pha
    phx

    ; Advance the pointer to the first Sprite object in the struct
    clc
    lda #sprite_manager.sprites
    tax

    ; Stupidly simple, just iterate through the OAM objects and
    ; return the first one that is not allocated
    ldy #0

    @FindNextFreeObject:
        ; Check if the sprite descriptor is allocated
        lda sprite_desc.allocated, X
        and #$00FF
        beq @MarkAllocated

        ; Advance the pointer
        clc
        txa
        adc #_sizeof_SpriteDescriptor
        tax

        ; Did we reach the end of the sprite object space?
        iny
        cpy #MAX_SPRITE_OBJECTS
        beq @OutOfSpace

        ; Continue to the next iteration
        bra @FindNextFreeObject

    ; If we got here, then we found a free object. Mark it allocated
    @MarkAllocated:
        lda #1
        sta sprite_desc.allocated, X
        stz sprite_desc.dirty, X

        ; Return the address of the sprite object
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
; This function will release a sprite object back to the SpriteManager.
; It will mark the sprite object as not allocated.
; Expects Y to be set to the address of the Sprite object to release
;
SpriteManager_Release:
    pha
    phx
    phy

    A8

    ; Mark the sprite object as not allocated. stz only works with X register.
    tyx
    stz sprite_desc.allocated, X

    A16

    ply
    plx
    pla

    rts

;
; Expects Y register to be the pointer to the sprite descriptor
; Expects X register to be the 16-bit sprite pointer
; Expects A register to be the 8-bit bank number
Sprite_Load:
    phb
    phx
    phy

    ; Save the bank number in the sprite descriptor
    A8
    sta sprite_desc.bank.w, Y ; Bank
    A16

    ; Store the high and low bits of the sprite pointer
    stx sprite_desc.ptr.w, Y ; High + Low

    ; Prepare the sprite VRAM
    lda sprite_desc.vram.w, Y
    sta VMADDL

    phx
    phy

    ; Prepare the sprite CGRAM
    ldx #cgram_sprite_manager
    jsr CGRAMManager_Request
    tya

    ; Bounce stack for Y index  
    ply
    plx

    ; Store the palette index in the map manager
    A8
    sta sprite_desc.cgram_index.w, Y
    A16

    ; Set the data bank register to the correct bank
    A8
    lda sprite_desc.bank.w, Y
    pha
    plb
    A16

    ; Call the sprite init routine
    ; Swap the registers to make X the primary struct and Y the descriptor
    jsr Sprite_Init

    ply
    plx
    plb
    rts

;
; Load sprite data at the X register offset
; Expects that X register points to the sprite struct
; Expects that Y register points to the sprite descriptor
;
Sprite_Init:
    phy
    phx
    A8

    @CheckSpriteMagicNumber:
        lda sprite_hdr.magic.w, X
        cmp #ASC('S')
        bcc @Error_BadMagic
        inx

        lda sprite_hdr.magic.w, X
        cmp #ASC('P')
        bcc @Error_BadMagic
        inx

        lda sprite_hdr.magic.w, X
        cmp #ASC('R')
        bcc @Error_BadMagic
        inx

    @MagicSuccess:
        ; Bounce the stack
        plx
        phx

        ; Load the sprite palette data and sheet data into VRAM
        jsr Sprite_LoadPalette
        jsr Sprite_LoadSheet

    @Error_BadMagic:
        nop

    A16
    plx
    ply
    rts

;
; Read all the palette data from the sprite into cgram
; Expects that X register points to the sprite struct
; Expects that Y register points to the sprite descriptor
;
Sprite_LoadPalette:
    A16
    phx
    phy

    phb
    phx
    phy
    DB0

    ; Store the palette index in the map manager
    A8
    lda sprite_desc.cgram_index, Y
    tay
    A16

    ; Convert the palette index to a CGRAM address
    ; Expects the Y register to be the palette index
    ; A is now the CGRAM address
    jsr CGRAM_Index

    ; Bounce the stack
    ply
    plx
    plb

    A8
    sta CGADD                   ; Set CGADD to requested bg cgram index
    A16

    ldy #$20

    ; Set the X register to point to the sprite hdr palette data
    txa
    clc
    adc sprite_hdr.pal_data_offset.w, X
    adc #sprite_hdr.data.w
    tax

    A8
    @CGRAMLoop:                 ; Loop through all X bytes of color data
        lda 0.w, X              ; Low byte color data
        sta CGDATA              ; Store data to CGRAM
        inx                     ; Increment data offset
        dey                     ; Decrement counter
        lda 0.w, X              ; High byte color data
        sta CGDATA              ; Store data to CGRAM
        inx                     ; Increment data offset
        dey                     ; Decrement counter
        bne @CGRAMLoop          ; Loop if not

    A16
    ply
    plx
    rts

;
; This routine will load the sprite sheet data into VRAM
;
Sprite_LoadSheet:
    A16
    phy
    phx

    ; Get the count of bytes in the sprite sheet
    lda sprite_hdr.sheet_data_count.w, X
    tay

    ; Get the offset to the sheet data
    clc
    txa
    adc sprite_hdr.sheet_data_offset.w, X
    tax

    A8

    ; Load the sprite sheet data into VRAM
    @VRAMLoop:                      ; Loop through all X bytes of sprite data
        lda sprite_hdr.data.w, X    ; Load bitplane 0/2
        sta VMDATAL                 ; Store data to VRAM
        inx                         ; Increment X register for the data
        lda sprite_hdr.data.w, X    ; Load bitplane 1/3
        sta VMDATAH                 ; Store data to VRAM
        inx                         ; Increment X register for the data
        dey                         ; Decrement loop counter
        bne @VRAMLoop               ; Loop if we haven't reached 0

    A16

    plx
    ply
    rts

;
; Set the active tag for the sprite
; Expects that the A register contains the tag index
; Expects that Y register points to the sprite struct
;
Sprite_SetTag:
    pha
    phx
    phy

    ; Setup the X register pointer to be the correct 16-bit address
    ; and then save the pointer for the tag for future lookups
    clc
    adc sprite_desc.ptr.w, Y
    adc #sprite_hdr.data
    sta sprite_desc.tag.w, Y
    tax

    ; Save the data bank register because we're going to bounce it
    phb

    ; Set the data bank register to the correct bank for the sprite
    lda #0

    A8

    lda sprite_desc.bank.w, Y
    pha
    plb

    ; Determine how many OAMs we need to allocate and store it in the temp
    lda tag_hdr.oam_count.w, X

    A16

    ; Pop the data bank register so we can operate back on WRAM
    plb

    ; If the number of OAMs active are greater than what we need, then
    ; we need to release the OAMs that we don't need.
    cmp sprite_desc.oam_count, Y
    beq @Done
    bcs @AllocateOAMs
    bra @ReleaseOAMs

    ; If we got here, then we need to allocate 1 or more OAMs
    @AllocateOAMs:
        ; The accumulator contains the number of OAMs we need to allocate
        pha

        ; Calculate the number of OAMs we need to allocate
        sec
        sbc sprite_desc.oam_count, Y
        pha

        ; Offset the X register to point to the first OAM we need to allocate
        ; OAMManager will use Y register, so swap our index to X
        tya
        clc
        adc sprite_desc.oam_count, Y
        adc sprite_desc.oam_count, Y
        tax

        ; Counter for the number of OAMs we need to allocate
        pla

        ; Request all the OAMs that we need
        @RequestOAM:
            jsr OAMManager_Request

            ; Store pointers for base OAM object movement (X)
            pha
            lda 5, S
            adc #sprite_desc.x
            sta oam_object.bx, Y

            ; Store pointers for base OAM object movement (Y)
            lda 5, S
            adc #sprite_desc.y
            sta oam_object.by, Y
            pla

            ; Store the OAM pointer into the sprite descriptor
            sty sprite_desc.oams, X
            inx
            inx

            ; Decrement the number of OAMs we need to allocate
            dea
            bne @RequestOAM

        pla
        ply
        sta sprite_desc.oam_count, Y
        phy
        bra @Done

    ; If we got here, then we need to release 1 or more OAMs because we
    ; already have more than we need for this tag
    @ReleaseOAMs:
        ; The accumulator contains the number of OAMs we need to allocate
        pha
        
        ; Offset the X register to point to the first OAM we need to free
        ; OAMManager will use Y register, so swap our index to X
        tya
        clc
        adc sprite_desc.oam_count, Y
        adc sprite_desc.oam_count, Y
        sec
        sbc #2
        tax

        ; Calculate the number of OAMs we need to free
        sec
        lda sprite_desc.oam_count, Y
        sbc 1, S

        pha

        ; Free all the OAMs that we don't need
        @ReleaseOAM:
            lda sprite_desc.oams, X
            tay
            jsr OAMManager_Release

            ; Zero out the OAM pointer in the sprite descriptor
            stz sprite_desc.oams, X
            dex
            dex

            ; Decrement the number of OAMs we need to allocate
            lda 1, S
            dea
            sta 1, S
            bne @ReleaseOAM

        ; Update the number of OAMs active in the sprite descriptor
        pla
        pla
        ply
        sta sprite_desc.oam_count, Y
        phy
        bra @Done

    @Done:
        ply
        plx
        pla
        rts


;
; Set the active frame for the sprite
; Expects that the A register contains the frame index
; Expects that Y register points to the sprite struct
;
Sprite_SetFrame:
    phx
    pha
    phy

    ; Save the data bank register because we're going to bounce it
    phb

    ; Setup the X register pointer to be the correct 16-bit address for the tag
    lda sprite_desc.tag.w, Y
    tax

    ; Set the data bank register to the correct bank for the sprite
    A8
    lda sprite_desc.bank.w, Y
    pha
    plb
    A16

    ; Use the frame index as a counter
    clc

    ; Create the counter
    lda 4, S
    tay

    ; Setup the offset
    txa
    adc tag_hdr.frame_metadata_offset.w, X
    adc #tag_hdr.data.w

    cpy #0
    beq @SetFramePointer

    ; Get the offset to the frame metadata
    clc
    @ComputeFrameOffset:
        adc #_sizeof_TagFrameMetadataHeader
        dey
        bne @ComputeFrameOffset

    ; The accumulator now points to the frame metadata, so now we can retrieve
    ; the frame offset relative to the tag header data.
    @SetFramePointer:
        ; Load the frame offset from the metadata header and compute the offset
        clc
        phx
        tax
        lda tag_frame_metadata_hdr.offset.w, X
        adc 1, S
        plx

        ; Add the tag header frame data offset to get the true offset
        adc tag_hdr.frame_offset.w, X
        adc #tag_hdr.data

        ; Restore the data bank register
        plb

        ; Restore the Y register and save the frame pointer
        ply
        sta sprite_desc.frame.w, Y

        ; Set the frame index
        pla
        sta sprite_desc.frame_idx.w, Y

        ; Preserve order of the stack to make it easier to debug
        pha
        phy

    ; We will need this pointer later, so we'll save it
    @SetTilePointer:
    tya
    clc
    adc #sprite_desc.tiles
    pha

    @SetOAMPointer:
    tya
    clc
    adc #sprite_desc.oams
    pha

    @PrepBank:
    ; Iterate through each layer in the frame and load the tiles
    ; Save the data bank register because we're going to bounce it
    phb

    ; Setup the X register pointer to be the correct 16-bit address for the tag
    lda sprite_desc.frame.w, Y
    tax

    ; Set the data bank register to the correct bank for the sprite
    A8
    lda sprite_desc.bank.w, Y
    pha
    plb
    A16

    ; Create a temporary counter we will decrement
    lda frame_hdr.frame_layer_metadata_count.w, X
    pha

    @LoadLayers:
        ; Compute the layer offset for easy access later
        txa
        clc
        adc frame_hdr.layer_offset.w, X
        adc #frame_hdr.data
        pha

        ; Iterate through each layer in the frame and load the tiles
        txa
        clc
        adc frame_hdr.frame_layer_metadata_offset.w, X
        adc #frame_hdr.data
        tax

        @@LoadLayer:
            ; Load the offset for the actual layer data
            clc
            phx
            lda frame_layer_metadata_hdr.offset.w, X
            adc 3, S
            tax

            ; Create our inner temp variable for looping
            lda layer_hdr.tile_count.w, X
            pha

            ; Compute the new X register for the tile data
            txa
            clc
            adc layer_hdr.tile_offset.w, X
            adc #layer_hdr.data
            tax

            ; Load all the tiles for the layer
            @@@LoadTiles:
                ; Use the tile data and current sprite VRAM pointer to load the tile
                phd
                phx

                ; Load the OAM object pointer
                lda 14, S ; EB
                tax
                lda $0, X

                ; Set the D register to the OAM object base
                pha
                tay
                pld

                ; Restore X register for DB writes
                plx

                ; Initialize the OAM object with the relative offsets and size
                lda #0

                A8
                lda tile_hdr.oam_size.w, X
                sta oam_object.size

                lda tile_hdr.rx.w, X
                sta oam_object.x

                lda tile_hdr.ry.w, X
                sta oam_object.y

                lda tile_hdr.prog_ram_addr.w, X
                sta oam_object.vram
                A16

                ; Restore D register to go back to previous stack state
                pld

                ; Ensure the tile is dirty and rendered next frame
                phx
                tyx
                jsr OAM_MarkDirty

                ; Increment the tile pointer
                pla ; (x register, just skipping a txa)
                clc
                adc #_sizeof_TileHeader
                tax

                ; Advance the OAM pointer
                lda 10, S ; EF
                ina
                ina
                sta 10, S

                ; Advance the tile pointer
                lda 12, S
                ina
                ina
                sta 12, S

                ; Decrement the inner loop counter
                lda 1, S
                dea
                sta 1, S
                bne @@@LoadTiles
            
            pla ; Tile count temporary variable

            ; Advance the layer data pointer for next loop
            pla ; Pull the X register into the accumulator and add offsets
            clc
            adc #_sizeof_FrameLayerMetadataHeader
            tax

            ; Decrement the outer loop counter (layer count)
            lda 3, S
            dea
            sta 3, S
            bne @@LoadLayer

        plx
        pla

    plb ; Restore the data bank register
    pla ; Layer count temporary variable
    pla ; Tile offset temporary variable

    ply
    pla
    plx
    rts

;
; Expects X to be the pointer Sprite object
; Will mark the object as dirty and push it onto the queue
;
Sprite_MarkDirty:
    pha
    phx
    phy

    ; if (oam_object.dirty)
    ;     return
    A8
    lda sprite_desc.dirty, X
    cmp #1
    beq @Done
    A16

    ; Queue_Push(&Y) (this = X)
    phx
    ldx #sprite_manager.sprite_queue
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
    sta sprite_desc.dirty, X
    A16

    @Done:
        A16
        ply
        plx
        pla
        rts

;
; This routine will load an individual tile into VRAM based on the TileHeader
; metadata information.
;
SpriteManager_Frame:
    pha
    phx
    phy

    @Next:
        ldx #sprite_manager.sprite_queue
        jsr Queue_Pop

        ; if (sprite_queue.error == QUEUE_ERROR_EMPTY)
        lda queue.error.w, X
        cmp #QUEUE_ERROR_EMPTY
        beq @Done

        ; Transfer Y to X for pointer math
        lda $0, Y
        tax

        ; If we got here, then we found a dirty object. Mark all the OAM
        ; objects associated with it as dirty.
        @@MarkDirty:
            phx

            ; Get the number of OAMs active
            lda sprite_desc.oam_count, X
            tay

            ; Get the pointer to the OAMs
            txa
            clc
            adc #sprite_desc.oams
            tax

            ; Iterate through each OAM and mark it dirty
            @@@MarkOAMs:
                ; Mark the OAM as dirty
                phx
                lda $0, X
                tax
                jsr OAM_MarkDirty
                plx

                ; Advance the OAM pointer
                inx
                inx

                ; Decrement the loop counter
                dey
                bne @@@MarkOAMs

            plx
            A8
            stz sprite_desc.dirty, X
            A16

        bra @Next

    @Done:
        ply
        plx
        pla
    rts


.ends