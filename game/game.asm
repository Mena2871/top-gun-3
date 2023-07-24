.include "common/lib/string.i"

.include "engine/engine.asm"

.include "game/sprites.i"
.include "game/maps.i"
.include "game/fonts.i"
.include "game/strings.i"
.include "game/player.asm"
.include "game/characters/characters.asm"

.ACCU	16
.INDEX	16

.struct Game
    frame_counter dw            ; Frame counter (increments every frame)
    characters instanceof Characters
    player_1 instanceof Player
    player_2 instanceof Player
    game_clock_ptr dw
.endst

.ramsection "GameRAM" appendto "RAM"
    game instanceof Game        ; Pointer to the game struct
.ends

.section "Game" bank 0 slot "ROM"
nop ; This is here to prevent the compiler from optimizing the label away

;
; Main game loop
;
Game_Frame:
    pha
    phx
    phy

    .ifeq DEBUG_Game_Frame 1
    jsr Game_Frame@DebugStart
    .endif

    ldx game.game_clock_ptr.w
    jsr Timer_Triggered
    cpy #1
    bne @Done
    
    A16
    inc game.frame_counter.w        ; Increment frame counter

    ldx #game.player_1
    jsr Player_Frame

    ldx #game.player_2
    jsr Player_Frame
    bra @Done

    @Done:
    A16

    .ifeq DEBUG_Game_Frame 1
    jsr Game_Frame@DebugEnd
    .endif

    ply
    plx
    pla
    rts

;
; Initialize the game
;
Game_Init:
    pha
    phy                             ; Save Y register
    phx                             ; Save X register

    stz game.frame_counter.w        ; Zero frame counter
    jsr Engine_Init

    ; We do this after engine initialization because there
    ; are other hooks for that.
    .ifeq DEBUG_Game_Init 1
    jsr Game_Init@DebugStart
    .endif

    ; Initialize all font data
    jsr Game_FontInit

    ldx #game.characters
    jsr Characters_Init

    jsr TimerManager_Request
    sty game.game_clock_ptr.w
    tyx
    lda #8
    jsr Timer_Init

    ; Initialize the players
    ldy #game.characters.character_1
    ldx #game.player_1
    jsr Player_Init

    ldy #game.characters.character_2
    ldx #game.player_2
    jsr Player_Init

    .ifeq DEBUG_Game_Init 1
    jsr Game_Init@DebugEnd
    .endif

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
    ;jsr Renderer_TestHScroll

    rts


.ends