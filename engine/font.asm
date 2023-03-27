;
; Font management routines for an 8x8 2BPP font
;

.ACCU   16
.INDEX  16

.define MAX_FONTS 2
.define MAX_FONT_SURFACES 8

.macro incfont args _bank, _name, _width, _height
    Font_{_name}:
        .define Font_{_name}@Bank _bank
        @bin: .incbin resources/fonts/{_name}-font.bin
        @pal: .incbin resources/fonts/{_name}-font.pal
        .dstruct @Data instanceof FontHeader values
            name:    .db _name
            bpp:     .db 2
            width:   .db _width
            height:  .db _height
            bin_ptr: .dw @bin
            pal_ptr: .dw @pal
            words:   .dw (((_width * _height) / 2) >> 2)
        .endst
.endm

.struct FontHeader
    name    ds 8    ; Name of the font
    bpp     db      ; Bits per pixel
    width   dw      ; Width of each character in pixels
    height  dw      ; Height of each character in pixels
    bin_ptr dw      ; Pointer to the font data
    pal_ptr dw      ; Pointer to the palette to use
    words   dw      ; Number of words to load to VRAM
.endst

.struct Font
    font_header_bank db  ; 8-bit bank number of the font header
    font_header_ptr  dw  ; 16-bit pointer to the font header
    bg_vram          dw  ; VRAM bg mode
    char_vram_addr   dw  ; VRAM address to load the font to
.endst

.struct FontSurface
    font_ptr        dw      ; Pointer to the font VRAM info
    allocated       db      ; If 1, this is allocated
    enabled         db      ; If 1, this is enabled
    dirty           db      ; If 1, this is dirty and needs to be redrawn
    tile_index      dw      ; 8x8 Tile index to draw at
    time            db      ; Number of 50ms ticks between each character draw
    remaining_time  db      ; Remaining time before drawing the next character
    curr_idx        db      ; If time > 0, then this is the character index to draw
    mode            db      ; If 0, draw the string, if 1 use as indices
    color           db      ; Color to draw with
    data_bank       db      ; 8-bit bank number of the string or indices
    data_ptr        dw      ; Pointer to the string or indices
.endst

.struct FontManager
    fonts instanceof Font MAX_FONTS
    font_surfaces instanceof FontSurface MAX_FONT_SURFACES
    timer_ptr      dw   ; Pointer to the timer to use
    surface_queue instanceof Queue
    surface_queue_memory ds (2 * MAX_FONT_SURFACES)
.endst

.enum $0000
    font instanceof Font
.ende
.enum $0000
    font_header instanceof FontHeader
.ende
.enum $0000
    font_surface instanceof FontSurface
.ende

.ramsection "FontManagerRAM" appendto "RAM"
    font_manager instanceof FontManager
.ends

.section "Font" bank 0 slot "ROM"
;
; Default initialization of a font draw info
; Expects X to point to the font draw info object
;
FontSurface_Init:
    stz font_surface.allocated, X
    stz font_surface.enabled, X
    stz font_surface.dirty, X
    stz font_surface.time, X
    stz font_surface.remaining_time, X
    stz font_surface.curr_idx, X
    stz font_surface.mode, X
    stz font_surface.color, X
    rts

FontManager_Init:
    lda #50
    jsr TimerManager_Request
    tya
    sta font_manager.timer_ptr.w
    ldx (font_manager.timer_ptr.w)
    jsr Timer_Init

    ; Initialize the queue
    lda #font_manager.surface_queue_memory       ; Set the base address of the queue  
    sta font_manager.surface_queue.start_addr.w  ; Store it in the Font Manager struct

    ; Calculate the end address of the queue
    clc
    adc #(MAX_FONT_SURFACES * 2)                   ; Calculate the end address
    sta font_manager.surface_queue.end_addr.w      ; Store it in the OAMManager struct

    ; Set the element size to 2 bytes
    lda #2                                        ; Set the element size in bytes
    sta font_manager.surface_queue.element_size.w ; Store it in the OAMManager struct

    ; Initialize the queue
    ldx #font_manager.surface_queue               ; Set the Queue "this" pointer
    jsr Queue_Init

    rts

;
; Expects X register to be the pointer to the font manager
; Expects Y register to be the 16-bit font pointer
; Expects A register to be the 8-bit bank number
;
FontManager_Load:
    phb
    pha
    phx
    phy

    ; Preserve the font bank number
    A8
    sta font_manager.fonts.1.font_header_bank.w

    ; Preserve the font pointer
    A16
    tya
    sta font_manager.fonts.1.font_header_ptr.w

    ; Set the font header pointer
    A8
    pha
    plb
    A16

    ; Store in Y the number of words to load
    phx
    tyx
    ldy font_header.words.w, X
    plx

    ; Use the 2BPP plane 3rd background for the font
    lda #3
    sta font_manager.fonts.1.bg_vram.w

    ; Get the background manager pointer and get the next VRAM address
    ; and store it in the current font VRAM info
    phx
    lda bg_manager.bg_info.3.next_char_vram.w

    ; Prepare BGManager to advance the VRAM address for BG3 
    ; X points to the BGManager object currently
    ; Y currently points to the number of words to load
    jsr BGManager_BG3Next

    ; Pop the stack. Store the VRAM address in the font VRAM info
    plx
    sta font_manager.fonts.1.char_vram_addr.w

    ; Font is now ready to write to VRAM
    lda font_manager.fonts.1.font_header_ptr.w
    tax

    ; X now points to the font object
    ; VRAM is ready to be written to
    ; Y will be our counter for decrementing
    lda font_header.words.w, X
    tay

    ; Make X point to the bin object for the font
    lda font_header.bin_ptr.w, X
    tax

    A8
    @VRAMLoop:
        lda $0.w, X         ; Load bitplane 0
        sta VMDATAL         ; Store data to VRAM
        inx                 ; Increment X register for the data
        lda $0.w, X         ; Load bitplane 1
        sta VMDATAH         ; Store data to VRAM
        inx                 ; Increment X register for the data
        dey                 ; Decrement Y register for the counter
        bne @VRAMLoop       ; If Y is not 0, loop

    A16
    ply
    plx
    pla

    sta font_manager.fonts.1.font_header_ptr.w

    plb
    rts

FontManager_RequestSurface:
    pha
    phx

    ; Save the font info for the allocated object
    lda #font_manager.fonts
    pha

    ; We will be advancing this pointer
    lda #font_manager.font_surfaces
    tax

    ldy #MAX_FONT_SURFACES
    @Loop:
        A8
        lda font_surface.allocated, X
        cmp #0
        beq @Found

        ; Next font surface
        A16
        txa
        clc
        adc #_sizeof_FontSurface
        tax

        ; Check if we're done
        dey
        cpy #0
        bne @Loop

    ; No font surfaces available
    ldy #0
    bra @Done

    ; Found a surface
    @Found:
        jsr FontSurface_Init

        A16
        lda 1, S
        sta font_surface.font_ptr, X

        A8
        lda #1
        sta font_surface.allocated, X
        txy

    @Done:
        A16
        pla
        plx
        pla
        rts

;
; X register points to the font surface
;
FontManager_Draw:
    phb
    pha
    phx
    phy

    lda font_surface.tile_index, X
    pha

    lda font_surface.data_ptr, X
    pha

    A8
    lda font_surface.data_bank, X
    pha
    plb
    A16

    pla

    tax
    ldy #0
    @Loop:
        clc

        A16
        tya
        adc #BG3_TILEMAP_VRAM ; Start at the tilemap VRAM address
        adc 1, S              ; Add the tile index
        sta VMADDL

        A8
        lda $0.w, X
        cmp #0
        beq @Done

        ; Offset by the ASCII table (32 = space)
        sec
        sbc #32

        sta VMDATAL
        stz VMDATAH

        iny
        inx
        bra @Loop

    @Done:

    A16
    pla
    ply
    plx
    pla
    plb
    rts

FontManager_Frame:
    pha
    phx
    phy

    ldy #MAX_FONT_SURFACES

    clc
    lda #font_manager.font_surfaces
    tax

    @Loop:
        A8

        ; Check if the font draw info is dirty
        @CheckDirty:
            lda font_surface.dirty, X
            cmp #1
            bne @Continue

        ; Check if the font draw info is allocated
        @CheckAllocated:
            lda font_surface.allocated, X
            cmp #1
            bne @Continue

        ; Check if the font draw info is enabled
        @CheckEnabled:
            lda font_surface.enabled, X
            cmp #1
            bne @Continue

        ; Check if the font draw info has a timer
        @CheckHasTimer:
            lda font_surface.time, X
            cmp #0
            beq @Draw
            bra @CheckTimerExpired

        @CheckTimerExpired:
            lda font_surface.remaining_time, X
            cmp #0
            beq @Draw
            bra @Continue

        @Draw:
            A16
            phx         ; Save X pointing to the font draw info
            phy         ; Save Y counter for looping

            ldx #font_manager.surface_queue
            jsr Queue_Push

            ; if (oam_queue.error == QUEUE_ERROR_FULL)
            ;   continue
            lda queue.error.w, X
            cmp #QUEUE_ERROR_FULL
            bne @SavePointer
            ply
            plx
            bra @Continue

        @SavePointer:
            lda 3, S    ; Retrieve the pointer to the FontSurface object
            sta $0, Y   ; Save the pointer to the FontSurface object
            ply
            plx
            A8
            stz font_surface.dirty, X
            
        @Continue:
            A16
            clc

            ; Increment the pointer to the next FontSurface
            txa
            adc #_sizeof_FontSurface
            tax

            ; Decrement the counter
            A16
            dey
            cpy #0

            ; If the counter is not 0, loop
            bne @Loop

    A16
    ply
    plx
    pla
    rts

;
; Pops all the font surfaces off the queue and draws them
;
FontManager_VBlank:
    pha
    phx
    phy

    @Next:
        ldx #font_manager.surface_queue
        jsr Queue_Pop

        ; if (oam_queue.error == QUEUE_ERROR_EMPTY
        ;   return
        lda queue.error.w, X
        cmp #QUEUE_ERROR_EMPTY
        beq @Done

        lda $0, Y
        tax

        jsr FontManager_Draw
        bra @Next

    @Done:
        ply
        plx
        pla
        rts

.ends