.include "common/lib/string.i"

.include "engine/engine.asm"

.include "game/sprites.i"
.include "game/maps.i"
.include "game/fonts.i"
.include "game/strings.i"
.include "game/player.asm"

.ACCU	16
.INDEX	16

.struct Game
    frame_counter dw            ; Frame counter (increments every frame)
    player instanceof Player
    game_clock_ptr dw
    test_ui_ptr dw              ; Pointer to the requested test UI component
    dynamic_text_buffer ds 8    ; Buffer for dynamic text
.endst

.ramsection "GameRAM" appendto "RAM"
    game instanceof Game        ; Pointer to the game struct
.ends

.section "Game" bank 0 slot "ROM"
nop ; This is here to prevent the compiler from optimizing the label away

;
; Main game loop
; Arguments:
; - X: Pointer to Game struct
;
Game_Frame:
    pha
    phx
    phy

    ldx game.game_clock_ptr.w
    jsr Timer_Triggered
    cpy #1
    bne @Done

    inc game.frame_counter.w        ; Increment frame counter

    ldx #game.player
    jsr Player_Frame
    bra @Done

    @ClockUITest:
        ldx game.test_ui_ptr.w

        A8
        lda #1
        sta font_surface.locked, X

        ; Mark the font surface locked and convert the clock counter
        A16
        lda timer_manager.clock.s.w
        and #$00FF
        ;ldx game.game_clock_ptr.w
        ;lda timer.elapsed_ms, X
        ;stz timer.elapsed_ms, X
        ldx #game.dynamic_text_buffer
        jsr String_FromInt

        ; Unlock the font surface and mark it dirty
        A8
        ldx game.test_ui_ptr.w
        lda #1
        sta font_surface.dirty, X
        stz font_surface.locked, X

    @Done:
    A16
    ply
    plx
    pla
    rts

;
; Initialize the game
; Arguments:
; - X: Pointer to Game struct
;
Game_Init:
    pha                             ; Save A register
    phy                             ; Save Y register
    phx                             ; Save X register (this pointer)

    stz game.frame_counter.w        ; Zero frame counter
    jsr Engine_Init

    ldx #game.dynamic_text_buffer
    ldy #_sizeof_Game.dynamic_text_buffer
    lda #0
    jsr Memset

    ; Load a demo map
    lda #Map_Demo@Bank
    ldy #Map_Demo@Data
    jsr MapManager_Load

    ; Initialize all font data
    jsr Game_FontInit

    jsr TimerManager_Request
    sty game.game_clock_ptr.w
    tyx
    lda #8
    jsr Timer_Init

    ; Initialize the player
    ldx #game.player
    jsr Player_Init

    plx
    ply
    pla
    rts

;
; Initialize all font data
;
Game_FontInit:
    pha
    phx
    phy

    ; Load Font 8x8 into Slot 0
    lda #Font_8x8@Bank
    ldy #Font_8x8@Data
    jsr FontManager_Load

    ;Save pointer to font VRAM info
    lda #font_manager.fonts.1
    pha

    ; Request a FontSurface
    jsr FontManager_RequestSurface

    ; Save pointer to test ui component
    phx
    lda 3, S
    tax
    tya
    sta game.test_ui_ptr.w
    plx

    ; Store pointer to font VRAM info
    pla
    tyx
    sta font_surface.font_ptr, X

    ; Enable the font surface (this will cause it to be drawn)
    lda #1
    sta font_surface.enabled, X

    ; Provide pointer to text to draw
    lda #Text_TopGun3@Data
    sta font_surface.data_ptr, X

    lda #Tile8x8(128, 128)
    sta font_surface.tile_index, X

    ; Provide bank of text to draw
    A8
    lda #Text_TopGun3@Bank
    sta font_surface.data_bank, X

    lda #9
    sta font_surface.data_len, X

    ; Set 50ms timer to 1
    lda #1
    sta font_surface.time, X
    sta font_surface.remaining_time, X

    ; Mark surface dirty and unlock it
    lda #1
    sta font_surface.dirty, X
    stz font_surface.locked, X

    A16
    ply
    plx
    pla

    rts

;
; VBlank handler
; Arguments:
; - X: Pointer to Game struct
;
Game_VBlank:
    jsr Engine_VBlank

    ldx #game.player
    jsr Player_VBlank

    rts

; Game_CheckPlayerStart:
;     ; call inputclass to check which players have start\
;     bne @Done

;     @Done:

;     rts

.ends