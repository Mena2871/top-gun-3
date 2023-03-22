.include "game/sprites.i"
.include "game/maps.i"
.include "game/fonts.i"
.include "game/strings.i"
.include "engine/engine.asm"

.ACCU	16
.INDEX	16

.section "Game" bank 0 slot "ROM"

nop ; This is here to prevent the compiler from optimizing the label away

.struct Game
    frame_counter dw            ; Frame counter (increments every frame)
    engine instanceof Engine    ; Pointer to the engine struct
    test_ui_ptr dw              ; Pointer to the requested test UI component
.endst

; Intentionally offset at $0000 since we will use the X register to
; point to the game struct when allocated
.enum $0000
    game instanceof Game        ; Pointer to the game struct
.ende

;
; Main game loop
; Arguments:
; - X: Pointer to Game struct
;
Game_Frame:
    pha
    phx
    phy

    inc game.frame_counter, X       ; Increment frame counter
    call(Engine_Frame, game.engine) ; Equivalent to this->engine.frame()

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

    stz game.frame_counter, X       ; Zero frame counter
    call(Engine_Init, game.engine)  ; Equivalent to this->engine.init()

    ; Load a demo map
    lda #Map_Demo@Bank
    ldy #Map_Demo@Data
    call(MapManager_Load, game.engine.map_manager)

    ; Initialize all font data
    jsr Game_FontInit

    ; Render one frame to initialize the screen
    jsr Game_VBlank

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

    ; Setup pointer for font manager
    txa
    adc #game.engine.font_manager
    tax

    ; Load Font 8x8 into Slot 0
    lda #Font_8x8@Bank
    ldy #Font_8x8@Data
    jsr FontManager_Load

    ;Save pointer to font VRAM info
    txa
    adc #font_manager.fonts.1
    pha

    ; Request a FontSurface
    jsr FontManager_RequestSurface

    ; Save pointer to test ui component
    phx
    lda 3, S
    tax
    tya
    sta game.test_ui_ptr, X
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

    ; Provide bank of text to draw
    A8
    lda #Text_TopGun3@Bank
    sta font_surface.data_bank, X

    ; Mark surface dirty
    stz font_surface.clean, X

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
    call(Engine_VBlank, game.engine) ; Equivalent to this->engine.vblank()
    rts

.ends