.ACCU  16
.INDEX 16

.include "engine/drivers/snes/interface.asm"
.include "engine/bg.asm"
.include "engine/input.asm"
.include "engine/map.asm"
.include "engine/oam.asm"
.include "engine/sprite.asm"
.include "engine/timer.asm"
.include "engine/cgram.asm"
.include "engine/renderer.asm"

.struct Engine
    frame_counter dw
.endst

.ramsection "EngineRAM" appendto "RAM"
    engine instanceof Engine
.ends

.section "Engine" BANK 0 SLOT "ROM"

Engine_Init:
    phy
    phx

    stz engine.frame_counter.w

    jsr SNES_Init
    jsr OAMManager_Init
    jsr BGManager_Init
    jsr CGRAMManager_Init
    jsr TimerManager_Init
    jsr MapManager_Init
    jsr SpriteManager_Init
    jsr FontManager_Init
    jsr InputManager_Init
    jsr Renderer_Init

    ;        S4321
    lda #%00010111
    sta TM

    plx
    ply
    rts

Engine_Frame:
    jsr TimerManager_Frame
    jsr FontManager_Frame
    jsr SpriteManager_Frame
    rts

Engine_VBlank:
    jsr Renderer_VBlank
    jsr TimerManager_VBlank
    jsr OAMManager_VBlank
    jsr FontManager_VBlank
    jsr Input_VBlank
    rts

.ends