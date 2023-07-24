; Tilemaps are 2KB blocks of VRAM
.define BG1_TILEMAP_VRAM $1000
.define BG2_TILEMAP_VRAM $1400
.define BG3_TILEMAP_VRAM $1800

; Remember, these are 16-bit words
.define BG1_CHAR_VRAM    $3000
.define BG2_CHAR_VRAM    $3000
.define BG3_CHAR_VRAM    $5000
.define BG4_CHAR_VRAM    $5000

; 5 bits are used to address the 64K of VRAM.
.define BG_SIZE_32_32 0
.define BG_SIZE_64_32 1
.define BG_SIZE_32_64 2
.define BG_SIZE_64_64 3

; Per the documentation BGxSC is aaaaaaxy where 'a' is the VRAM address >> 10
.function BG_SC(vram, size) (((vram >> 10) << 2)) | (size & $3)

; Per the document BGxNBA is aaaabbbb where a and b are the VRAM address >> 12
.function BG_NBA(vram) vram >> 12
.function BG_12NBA(bg1, bg2) (BG_NBA(bg2) << 4) | BG_NBA(bg1)
.function BG_34NBA(bg3, bg4) (BG_NBA(bg4) << 4) | BG_NBA(bg3)

.struct BGInfo
    next_char_vram dw ; Next available character VRAM address
.endst

.struct BGManager
    bg_info instanceof BGInfo 4
.endst

.ramsection "BGRAM" appendto "RAM"
    bg_manager instanceof BGManager
.ends

.section "BG" bank 0 slot "ROM"

nop

;
; Expects X to be a pointer to BGManager
;
BGManager_Init:
    pha

    ; BG1 is 8x8 characters at 32x32 tiles at 4BPP
    lda #BG1_CHAR_VRAM
    sta bg_manager.bg_info.1.next_char_vram.w

    ; BG2 is 8x8 characters at 32x32 tiles at 4BPP
    lda #BG2_CHAR_VRAM
    sta bg_manager.bg_info.2.next_char_vram.w

    ; BG3 is 8x8 characters at 32x32 tiles at 2BPP
    lda #BG3_CHAR_VRAM
    sta bg_manager.bg_info.3.next_char_vram.w

    A8

    ; Enable Mode 1 with 8x8 characters for all sizes
    ; BG3 is set to high priority
    ; Size is 8x8 characters for all BG modes.
    ;     abcdefff
    lda #%00111001
    sta BGMODE

    ; 8x8 characters at 32x32 tiles at 4BPP
    lda #BG_SC(BG1_TILEMAP_VRAM, BG_SIZE_32_32)
    sta BG1SC

    ; 8x8 characters at 32x32 tiles at 4BPP
    lda #BG_SC(BG2_TILEMAP_VRAM, BG_SIZE_32_32)
    sta BG2SC

    ; 8x8 charcters at 32x32 tiles at 2BPP
    lda #BG_SC(BG3_TILEMAP_VRAM, BG_SIZE_32_32)
    sta BG3SC

    ; VRAM addresses for BG1 and BG2
    lda #BG_12NBA(BG1_CHAR_VRAM, BG2_CHAR_VRAM)
    sta BG12NBA

    ; VRAM addresses for BG3 and BG4
    lda #BG_34NBA(BG3_CHAR_VRAM, BG4_CHAR_VRAM)
    sta BG34NBA

    A16

    pla
    rts

;
; Set VRAM address for a BG1 tilemap.
; Expects X to be a pointer to BGManager
; Expects Y to be the number of 16-bit words
;
BGManager_BG1Next:
    phb
    pha
    phy

    DB0

    lda bg_manager.bg_info.1.next_char_vram.w
    sta VMADDL
    adc 1, S
    sta bg_manager.bg_info.1.next_char_vram.w

    ply
    pla
    plb
    rts

;
; Set VRAM address for a BG3 tilemap.
; Expects X to be a pointer to BGManager
; Expects Y to be the number of 16-bit words
;
BGManager_BG3Next:
    phb
    pha
    phy

    DB0

    lda bg_manager.bg_info.3.next_char_vram.w
    sta VMADDL
    adc 1, S
    sta bg_manager.bg_info.3.next_char_vram.w

    ply
    pla
    plb
    rts

.ends