.struct BGScreen
    h_offset dw
    v_offset dw
    mosaic_enabled db
.endst

.struct Renderer
    bg_screen instanceof BGScreen 2
.endst

.ramsection "RendererRAM" appendto "RAM"
    renderer instanceof Renderer
.ends

.enum $0000
    bg_screen instanceof BGScreen
.ende

.section "Renderer" bank 0 slot "ROM"

;
; Initialize the renderer.
;
Renderer_Init:
    pha
    phx
    phy

    ; Memset should take care of these initializations, but we do it here
    ; anyways if we ever need to re-initialize the renderer.
    ldx #renderer.bg_screen.w
    ldy #0
    @BGScreen_Init:
        stz bg_screen.h_offset, X
        stz bg_screen.v_offset, X
        clc
        txa
        adc #_sizeof_BGScreen
        tax
        iny
        cpy #2
        bne @BGScreen_Init

    ply
    plx
    pla
    rts

Renderer_Frame:
    rts

Renderer_VBlank:
    pha

    jsr Renderer_TestMoveScreenRight

    @UpdateBGOffsets:
        .16bit
        A8
        lda renderer.bg_screen.1.h_offset.w
        sta BG1HOFS
        lda renderer.bg_screen.1.h_offset.w + 1
        sta BG1HOFS
        lda renderer.bg_screen.1.v_offset.w
        sta BG1VOFS
        lda renderer.bg_screen.1.v_offset.w + 1
        sta BG1VOFS

        lda renderer.bg_screen.2.h_offset.w
        sta BG2HOFS
        lda renderer.bg_screen.2.h_offset.w + 1
        sta BG2HOFS
        lda renderer.bg_screen.2.v_offset.w
        sta BG2VOFS
        lda renderer.bg_screen.2.v_offset.w + 1
        sta BG2VOFS

        A16
        .8bit

    pla
    rts

Renderer_EnableMosiac:
    pha
    A8
    lda #%00010011
    sta MOSAIC
    A16
    pla
    rts

Renderer_DisableMosiac:
    pha
    A8
    lda #%00000000
    sta MOSAIC
    A16
    pla
    rts

Renderer_TestHScroll:
    pha

    inc renderer.bg_screen.1.h_offset.w
    inc renderer.bg_screen.1.h_offset.w
    inc renderer.bg_screen.1.h_offset.w
    inc renderer.bg_screen.2.h_offset.w

    pla
    rts

Renderer_TestMoveScreenLeft:
    pha
    lda renderer.bg_screen.1.h_offset.w
    sbc #5
    sta renderer.bg_screen.1.h_offset.w
    lda renderer.bg_screen.2.h_offset.w
    sbc #2
    sta renderer.bg_screen.2.h_offset.w
    pla
    rts

Renderer_TestMoveScreenRight:
    pha
    lda #8
    adc renderer.bg_screen.1.h_offset.w
    sta renderer.bg_screen.1.h_offset.w
    lda #2
    adc renderer.bg_screen.2.h_offset.w
    sta renderer.bg_screen.2.h_offset.w
    pla
    rts

.ends